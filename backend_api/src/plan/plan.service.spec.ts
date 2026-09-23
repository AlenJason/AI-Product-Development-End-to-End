import { CreatePlanDto } from './dto/create-plan.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import type { GeminiService } from './gemini.service.js';
import { PlanService } from './plan.service.js';
import { WARNINGS } from './plan-warnings.js';

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
