import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { PlanSource } from './enums/plan-source.enum.js';
import { assemblePlan } from './plan-assembly.js';
import { parsePlanContent } from './plan-validation.js';

const raw: unknown = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
);

describe('sample-plan.json', () => {
  it('follows the same contract as Gemini output', () => {
    expect(parsePlanContent(raw).errors).toEqual([]);
  });

  it('has 3 days and aggregates shared ingredients into the grocery list', () => {
    const { plan } = parsePlanContent(raw);
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
});
