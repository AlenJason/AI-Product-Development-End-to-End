import { Logger } from '@nestjs/common';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { GeminiTimeoutError, type GeminiService } from './gemini.service.js';
import { PlanService } from './plan.service.js';
import { WARNINGS } from './plan-warnings.js';

const SAMPLE_CONTENT: unknown = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
);
const INVALID_CONTENT = { days: [] };
const SECRET = 'BENH-NEN-BI-MAT-123';

function profile(overrides: Partial<CreatePlanDto> = {}, restrictions: Partial<RestrictionsDto> = {}): CreatePlanDto {
  return Object.assign(new CreatePlanDto(), {
    age: 22,
    gender: Gender.FEMALE,
    height_cm: 168,
    weight_kg: 62,
    activity_level: ActivityLevel.LIGHT,
    goal: Goal.CUT,
    ...overrides,
    restrictions: Object.assign(new RestrictionsDto(), restrictions),
  });
}

const geminiOff = { isConfigured: false } as unknown as GeminiService;

// Gemini giả: mỗi phần tử là kết quả của một lần gọi — Error thì ném ra, còn lại thì trả về.
function geminiAnswering(...answers: unknown[]) {
  const generatePlanContent = vi.fn();
  for (const answer of answers) {
    if (answer instanceof Error) generatePlanContent.mockRejectedValueOnce(answer);
    else generatePlanContent.mockResolvedValueOnce(answer);
  }
  const gemini = { isConfigured: true, generatePlanContent } as unknown as GeminiService;
  return { gemini, generatePlanContent };
}

describe('PlanService.generatePlan without a Gemini key', () => {
  it('returns the 3-day sample plan with the computed daily target and no warnings', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(plan.days).toHaveLength(3);
    expect(plan.grocery_list.length).toBeGreaterThan(0);
    expect(plan.daily_target.target_calories).toBe(1624);
    expect(plan.warnings).toEqual([]);
  });

  it('warns that the sample is not filtered and adds the medical disclaimer', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(
      profile({}, { allergies: 'Hải sản', health_conditions: 'Tiểu đường' }),
    );
    expect(plan.warnings).toContain(WARNINGS.sampleNotFiltered);
    expect(plan.warnings).toContain(WARNINGS.healthConditions);
  });

  it('explains when the target was raised to BMR', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(
      profile({ height_cm: 150, weight_kg: 45, activity_level: ActivityLevel.SEDENTARY }),
    );
    expect(plan.daily_target.target_calories).toBe(1117);
    expect(plan.warnings).toContain(WARNINGS.bmrFloor(1117));
  });
});

describe('PlanService.generatePlan with Gemini configured', () => {
  afterEach(() => vi.restoreAllMocks());

  it('uses Gemini output that follows the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Hải sản' }));
    expect(plan.source).toBe('gemini');
    expect(generatePlanContent).toHaveBeenCalledTimes(1);
    expect(plan.warnings).not.toContain(WARNINGS.sampleNotFiltered);
  });

  it('retries once when the first answer breaks the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(INVALID_CONTENT, SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('gemini');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
  });

  it('falls back to the sample after two answers that break the contract', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(INVALID_CONTENT, INVALID_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Hải sản' }));
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
    expect(plan.warnings).toContain(WARNINGS.sampleNotFiltered);
  });

  it('does not retry after a timeout', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(new GeminiTimeoutError(15_000), SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(1);
  });

  it('falls back to the sample when the API key is rejected', async () => {
    const keyRejected = Object.assign(new Error('API key not valid'), { name: 'ApiError', status: 400 });
    const { gemini, generatePlanContent } = geminiAnswering(keyRejected, keyRejected);
    const plan = await new PlanService(gemini).generatePlan(profile());
    expect(plan.source).toBe('sample');
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
  });

  it('never writes the user health text to the log (#12)', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const error = vi.spyOn(Logger.prototype, 'error').mockImplementation(() => undefined);
    const { gemini } = geminiAnswering(INVALID_CONTENT, new Error('boom'));

    await new PlanService(gemini).generatePlan(profile({}, { allergies: SECRET, health_conditions: SECRET }));

    const logged = [...warn.mock.calls, ...error.mock.calls].flat().map(String).join('\n');
    expect(warn).toHaveBeenCalled();
    expect(logged).not.toContain(SECRET);
  });
});
