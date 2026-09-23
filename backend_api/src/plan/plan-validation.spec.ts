import { parsePlanContent } from './plan-validation.js';

function validMeal(meal_type: string, name: string) {
  return {
    meal_type,
    name,
    portion: '1 phần',
    calories: 500,
    protein_g: 30,
    carbs_g: 60,
    fat_g: 15,
    ingredients: [{ name: 'Gạo tẻ', amount: 100, unit: 'g', category: 'pantry' }],
  };
}

function validDay(day: number) {
  return {
    meals: [
      validMeal('breakfast', `Món sáng ${day}`),
      validMeal('lunch', `Món trưa ${day}`),
      validMeal('dinner', `Món tối ${day}`),
    ],
    workout: {
      title: 'Buổi tập',
      duration_minutes: 20,
      exercises: [
        { name: 'Squat', sets: 3, reps_or_duration: '12 lần', muscle_group: 'legs', tags: [] },
      ],
    },
  };
}

function validPlan() {
  return { days: [validDay(1), validDay(2), validDay(3)] };
}

describe('parsePlanContent — structure', () => {
  it('accepts a plan that follows the contract', () => {
    const { plan, errors } = parsePlanContent(validPlan());
    expect(errors).toEqual([]);
    expect(plan?.days).toHaveLength(3);
  });

  it('rejects input that is not a JSON object', () => {
    expect(parsePlanContent('không phải json').plan).toBeNull();
    expect(parsePlanContent(null).plan).toBeNull();
    expect(parsePlanContent([]).plan).toBeNull();
  });

  it('rejects an unknown meal_type instead of skipping the calorie check', () => {
    const raw = validPlan();
    raw.days[0].meals[0].meal_type = 'Bữa sáng';
    const { plan, errors } = parsePlanContent(raw);
    expect(plan).toBeNull();
    expect(errors.some((error) => error.includes('meal_type'))).toBe(true);
  });

  it('rejects a plan with fewer than 3 days', () => {
    const raw = validPlan();
    raw.days.pop();
    expect(parsePlanContent(raw).plan).toBeNull();
  });

  it('drops fields outside the contract', () => {
    const { plan } = parsePlanContent({ ...validPlan(), grocery_list: [], plan_id: 'x' });
    expect(plan).not.toBeNull();
    expect(plan).not.toHaveProperty('grocery_list');
    expect(plan).not.toHaveProperty('plan_id');
  });
});

describe('parsePlanContent — plan rules', () => {
  it('flags calories outside the meal bounds', () => {
    const raw = validPlan();
    Object.assign(raw.days[0].meals[0], { calories: 900, protein_g: 50, carbs_g: 120, fat_g: 24 });
    expect(parsePlanContent(raw).errors.join('\n')).toContain('ngoài khoảng 250–600');
  });

  it('flags calories that do not match the macros', () => {
    const raw = validPlan();
    raw.days[0].meals[1].calories = 700;
    expect(parsePlanContent(raw).errors.join('\n')).toContain('lệch quá 15%');
  });

  it('flags a dish repeated across days, ignoring case and spaces', () => {
    const raw = validPlan();
    raw.days[2].meals[2].name = '  món TRƯA 1 ';
    expect(parsePlanContent(raw).errors.join('\n')).toContain('trùng với ngày 1');
  });

  it('flags a day missing one of the three meal types', () => {
    const raw = validPlan();
    raw.days[1].meals[2].meal_type = 'lunch';
    expect(parsePlanContent(raw).errors.join('\n')).toContain('Ngày 2: phải có đúng 1 bữa');
  });
});
