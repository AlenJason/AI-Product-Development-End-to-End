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
    expect(plan.warnings).toContain(WARNINGS.sampleKeywordFiltered);
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
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Đậu phộng' }));
    expect(plan.source).toBe('gemini');
    expect(generatePlanContent).toHaveBeenCalledTimes(1);
    expect(plan.warnings).not.toContain(WARNINGS.sampleKeywordFiltered);
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
    expect(plan.warnings).toContain(WARNINGS.sampleKeywordFiltered);
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

describe('PlanService — calorie totals and restrictions (v2.5.0)', () => {
  afterEach(() => vi.restoreAllMocks());

  const mealNames = (plan: { days: { meals: { name: string; ingredients: { name: string }[] }[] }[] }) =>
    plan.days.flatMap((day) => day.meals.flatMap((meal) => [meal.name, ...meal.ingredients.map((i) => i.name)])).join('|');

  it('scales the sample to a high target instead of serving ~1550 kcal', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(
      profile({ age: 30, gender: Gender.MALE, height_cm: 175, weight_kg: 70, activity_level: ActivityLevel.ACTIVE, goal: Goal.BULK }),
    );
    expect(plan.daily_target).toMatchObject({ bmr: 1649, target_calories: 2806 });
    for (const day of plan.days) {
      const total = day.meals.reduce((sum, meal) => sum + meal.calories, 0);
      expect(total).toBeGreaterThanOrEqual(2803);
      expect(total).toBeLessThanOrEqual(2809);
    }
  });

  it('removes recognised allergens and injury-unsafe exercises from the sample', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(profile({}, { allergies: 'hai san', injuries: 'Đau đầu gối' }));
    expect(mealNames(plan)).not.toMatch(/tôm|cá |cá$|mắm|cua/i);
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain('jumping');
    expect(tags).not.toContain('kneeling');
    expect(plan.warnings).toContain(WARNINGS.sampleKeywordFiltered);
    expect(plan.warnings).not.toContain(WARNINGS.restrictionsIncomplete);
  });

  it('warns without echoing the text when part of the restrictions is not recognised', async () => {
    const plan = await new PlanService(geminiOff).generatePlan(profile({}, { allergies: `Hải sản, ${SECRET}` }));
    expect(plan.warnings).toContain(WARNINGS.restrictionsIncomplete);
    expect(JSON.stringify(plan)).not.toContain(SECRET);
  });

  it('rejects Gemini output containing a recognised allergen, without logging which one (#12)', async () => {
    const warn = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);
    const { gemini, generatePlanContent } = geminiAnswering(SAMPLE_CONTENT, SAMPLE_CONTENT);
    const plan = await new PlanService(gemini).generatePlan(profile({}, { allergies: 'Hải sản' }));
    expect(generatePlanContent).toHaveBeenCalledTimes(2);
    expect(plan.source).toBe('sample');
    const logged = warn.mock.calls.flat().map(String).join('\n');
    expect(logged).toContain('có nguyên liệu người dùng cần tránh');
    expect(logged).not.toMatch(/mắm|hải sản/i);
  });

  it('passes the feedback note to Gemini for a follow-up plan (FR-5.3)', async () => {
    const { gemini, generatePlanContent } = geminiAnswering(SAMPLE_CONTENT);
    await new PlanService(gemini).generatePlan(profile(), { feedbackNote: 'buổi tập rất mệt' });
    expect(generatePlanContent).toHaveBeenCalledWith(expect.anything(), expect.anything(), 'buổi tập rất mệt');
  });
});
