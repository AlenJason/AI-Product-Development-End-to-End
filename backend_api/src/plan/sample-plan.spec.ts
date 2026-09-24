import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { computeDailyTarget } from './daily-target.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { assemblePlan } from './plan-assembly.js';
import { buildSampleContent } from './plan.service.js';
import { dayCalorieBounds, parsePlanStructure } from './plan-validation.js';
import { matchRestrictions } from './restriction-matcher.js';

const raw: unknown = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
);
const NO_RESTRICTIONS = matchRestrictions(new RestrictionsDto());

// 18 hồ sơ của ma trận BMR/TDEE + 2 hồ sơ cực trị trong giới hạn BRD 6.1.
const PROFILES = [
  ...[Gender.FEMALE, Gender.MALE].flatMap((gender) =>
    Object.values(ActivityLevel).flatMap((activity_level) =>
      Object.values(Goal).map((goal) => ({
        gender,
        activity_level,
        goal,
        ...(gender === Gender.FEMALE ? { age: 22, height_cm: 168, weight_kg: 62 } : { age: 30, height_cm: 175, weight_kg: 70 }),
      })),
    ),
  ),
  { age: 100, gender: Gender.FEMALE, height_cm: 100, weight_kg: 30, activity_level: ActivityLevel.SEDENTARY, goal: Goal.CUT },
  { age: 10, gender: Gender.MALE, height_cm: 250, weight_kg: 250, activity_level: ActivityLevel.ACTIVE, goal: Goal.BULK },
];

describe('sample-plan.json', () => {
  it('has the structure of the content contract', () => {
    expect(parsePlanStructure(raw).errors).toEqual([]);
  });

  it('aggregates shared ingredients into the grocery list', () => {
    const { plan } = parsePlanStructure(raw);
    if (!plan) throw new Error('sample-plan.json không hợp lệ');
    const target = { bmi: 1, bmr: 1, tdee: 1, target_calories: 1, protein_g: 1, carbs_g: 1, fat_g: 1 };
    const assembled = assemblePlan(plan, target, PlanSource.SAMPLE, []);
    const rice = assembled.grocery_list
      .find((group) => group.category === 'pantry')
      ?.items.find((item) => item.name === 'Gạo tẻ');

    expect(assembled.days).toHaveLength(3);
    expect(rice).toEqual({
      name: 'Gạo tẻ',
      quantity: '540g',
      source_meal_ids: ['m1_2', 'm1_3', 'm2_2', 'm2_3', 'm3_2', 'm3_3'],
    });
  });

  // Trước v2.5.0: thực đơn mẫu cố định ~1550 kcal/ngày, dưới BMR của mọi hồ sơ nam trong ma trận.
  it.each(PROFILES)('is scaled to the target and never below BMR — %o', (profile) => {
    const { target } = computeDailyTarget(profile);
    const { plan } = buildSampleContent(target, NO_RESTRICTIONS);
    const { min, max } = dayCalorieBounds(target);
    for (const day of plan.days) {
      const total = day.meals.reduce((sum, meal) => sum + meal.calories, 0);
      expect(total).toBeGreaterThanOrEqual(Math.max(min, target.bmr));
      expect(total).toBeLessThanOrEqual(max);
      expect(Math.abs(total - target.target_calories)).toBeLessThanOrEqual(3);
    }
  });
});
