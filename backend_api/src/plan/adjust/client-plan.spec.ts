import { BadRequestException, ConflictException } from '@nestjs/common';
import { makeProfile, samplePlan } from '../../../test/plan-fixtures.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { Goal } from '../enums/goal.enum.js';
import { WARNINGS } from '../plan-warnings.js';
import { readClientPlan, rebuildPlan } from './client-plan.js';

describe('readClientPlan', () => {
  let plan: MealPlanResponseDto;

  beforeAll(async () => {
    plan = await samplePlan();
  });

  it('accepts a plan exactly as the server returned it', () => {
    const context = readClientPlan(makeProfile(), plan);
    expect(context.target.target_calories).toBe(1624);
  });

  it('answers 409 when the profile no longer matches the plan target (#13)', () => {
    expect(() => readClientPlan(makeProfile({ goal: Goal.BULK }), plan)).toThrow(ConflictException);
  });

  it('never trusts the bmr sent by the client', () => {
    const forged = structuredClone(plan);
    forged.daily_target.bmr = 900;
    expect(() => readClientPlan(makeProfile(), forged)).toThrow(ConflictException);
  });

  it.each<[string, (p: MealPlanResponseDto) => void]>([
    ['meal ids out of position', (p) => ([p.days[0].meals[0].meal_id, p.days[0].meals[1].meal_id] = ['m1_2', 'm1_1'])],
    ['meals out of order', (p) => p.days[1].meals.reverse()],
    ['a wrong exercise id', (p) => (p.days[2].workout.exercises[0].exercise_id = 'e1_1')],
    ['a wrong day number', (p) => (p.days[1].day_number = 3)],
    ['impossible calories', (p) => (p.days[0].meals[0].calories = 5000)],
    ['a repeated dish', (p) => (p.days[2].meals[2].name = p.days[0].meals[2].name)],
  ])('answers 400 to %s (#2, #16)', (_label, tamper) => {
    const tampered = structuredClone(plan);
    tamper(tampered);
    expect(() => readClientPlan(makeProfile(), tampered)).toThrow(BadRequestException);
  });
});

describe('rebuildPlan', () => {
  it('keeps plan_id and source, recomputes grocery list and warnings from the profile', async () => {
    const plan = await samplePlan();
    const forged = { ...structuredClone(plan), warnings: ['cảnh báo giả'], grocery_list: [] };
    const profile = makeProfile({}, { allergies: 'hải sản', health_conditions: 'tiểu đường' });
    const rebuilt = rebuildPlan(readClientPlan(profile, forged), forged.days);

    expect(rebuilt.plan_id).toBe(plan.plan_id);
    expect(rebuilt.source).toBe('sample');
    expect(rebuilt.grocery_list).toEqual(plan.grocery_list);
    expect(rebuilt.warnings).toEqual([WARNINGS.healthConditions, WARNINGS.sampleKeywordFiltered]);
  });
});
