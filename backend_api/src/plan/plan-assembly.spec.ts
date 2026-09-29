import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
import { IngredientUnit } from './enums/ingredient.enum.js';
import { PlanSource } from './enums/plan-source.enum.js';
import { assemblePlan, formatQuantity } from './plan-assembly.js';
import { parsePlanContent } from './plan-validation.js';

const target: DailyTargetDto = {
  bmi: 22,
  bmr: 1399,
  tdee: 1924,
  target_calories: 1624,
  protein_g: 102,
  carbs_g: 183,
  fat_g: 54,
};

const rice = (amount: number) => ({ name: 'Gạo tẻ', amount, unit: 'g', category: 'pantry' });

function meal(meal_type: string, name: string, ingredients: object[]) {
  return { meal_type, name, portion: '1 phần', calories: 500, protein_g: 30, carbs_g: 60, fat_g: 15, ingredients };
}

function day(n: number, lunchIngredients: object[]) {
  return {
    meals: [
      meal('dinner', `Tối ${n}`, [rice(80)]),
      meal('breakfast', `Sáng ${n}`, [{ name: 'Trứng gà', amount: 2, unit: 'piece', category: 'protein' }]),
      meal('lunch', `Trưa ${n}`, lunchIngredients),
    ],
    workout: {
      title: 'Tập',
      duration_minutes: 20,
      exercises: [
        { name: 'Squat', sets: 3, reps_or_duration: '12 lần', muscle_group: 'legs', tags: [] },
        { name: 'Plank', sets: 3, reps_or_duration: '30 giây', muscle_group: 'core', tags: [] },
      ],
    },
  };
}

function content() {
  const { plan, errors } = parsePlanContent({
    days: [
      day(1, [rice(100), { name: 'Rau muống', amount: 150, unit: 'g', category: 'produce' }]),
      day(2, [rice(100), { name: 'Dầu ăn', amount: 1, unit: 'tbsp', category: 'pantry' }]),
      day(3, [rice(100), { name: 'dầu ăn ', amount: 1, unit: 'tsp', category: 'pantry' }]),
    ],
  }, target);
  if (!plan) throw new Error(`fixture không hợp lệ: ${errors.join('; ')}`);
  return plan;
}

describe('assemblePlan', () => {
  const plan = assemblePlan(content(), target, PlanSource.SAMPLE, ['cảnh báo']);

  it('assigns a UUID plan_id and keeps source, warnings and daily target', () => {
    expect(plan.plan_id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}$/);
    expect(plan.source).toBe('sample');
    expect(plan.warnings).toEqual(['cảnh báo']);
    expect(plan.daily_target).toEqual(target);
  });

  it('orders meals breakfast → lunch → dinner and numbers ids by day', () => {
    expect(plan.days.map((d) => d.day_number)).toEqual([1, 2, 3]);
    expect(plan.days[1].meals.map((m) => [m.meal_id, m.meal_type])).toEqual([
      ['m2_1', 'breakfast'],
      ['m2_2', 'lunch'],
      ['m2_3', 'dinner'],
    ]);
    expect(plan.days[2].workout.exercises.map((e) => e.exercise_id)).toEqual(['e3_1', 'e3_2']);
  });
});

describe('grocery_list', () => {
  const grocery = assemblePlan(content(), target, PlanSource.SAMPLE, []).grocery_list;
  const items = (category: string, name: string) =>
    grocery
      .find((group) => group.category === category)
      ?.items.filter((item) => item.name.trim().toLowerCase() === name) ?? [];

  it('orders categories protein → produce → pantry', () => {
    expect(grocery.map((group) => group.category)).toEqual(['protein', 'produce', 'pantry']);
  });

  it('sums the same ingredient and unit across meals, listing each source meal once', () => {
    expect(items('pantry', 'gạo tẻ')).toEqual([
      {
        name: 'Gạo tẻ',
        quantity: '540g',
        source_meal_ids: ['m1_2', 'm1_3', 'm2_2', 'm2_3', 'm3_2', 'm3_3'],
      },
    ]);
    expect(items('protein', 'trứng gà')[0].quantity).toBe('×6');
  });

  it('keeps different units of the same ingredient on separate lines', () => {
    expect(items('pantry', 'dầu ăn').map((item) => item.quantity)).toEqual([
      '1 muỗng canh',
      '1 muỗng cà phê',
    ]);
  });
});

describe('formatQuantity', () => {
  it('formats every unit for display', () => {
    expect(formatQuantity(450, IngredientUnit.G)).toBe('450g');
    expect(formatQuantity(30, IngredientUnit.ML)).toBe('30ml');
    expect(formatQuantity(2, IngredientUnit.PIECE)).toBe('×2');
    expect(formatQuantity(1.25, IngredientUnit.TBSP)).toBe('1.3 muỗng canh');
    expect(formatQuantity(0.5, IngredientUnit.TSP)).toBe('0.5 muỗng cà phê');
  });
});
