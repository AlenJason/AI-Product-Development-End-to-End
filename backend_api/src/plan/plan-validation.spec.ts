import { dayCalorieBounds, mealCalorieBounds, parsePlanContent } from './plan-validation.js';

// 3 bữa × 500 kcal = 1500: nằm trong khoảng ngày [max(0,85 × 1500, 1300); 1,1 × 1500] = [1300; 1650].
const TARGET = { target_calories: 1500, bmr: 1300 };

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
    const { plan, errors } = parsePlanContent(validPlan(), TARGET);
    expect(errors).toEqual([]);
    expect(plan?.days).toHaveLength(3);
  });

  it('rejects input that is not a JSON object', () => {
    expect(parsePlanContent('không phải json', TARGET).plan).toBeNull();
    expect(parsePlanContent(null, TARGET).plan).toBeNull();
    expect(parsePlanContent([], TARGET).plan).toBeNull();
  });

  it('rejects an unknown meal_type instead of skipping the calorie check', () => {
    const raw = validPlan();
    raw.days[0].meals[0].meal_type = 'Bữa sáng';
    const { plan, errors } = parsePlanContent(raw, TARGET);
    expect(plan).toBeNull();
    expect(errors.some((error) => error.includes('meal_type'))).toBe(true);
  });

  it('rejects a plan with fewer than 3 days', () => {
    const raw = validPlan();
    raw.days.pop();
    expect(parsePlanContent(raw, TARGET).plan).toBeNull();
  });

  it('drops fields outside the contract', () => {
    const { plan } = parsePlanContent({ ...validPlan(), grocery_list: [], plan_id: 'x' }, TARGET);
    expect(plan).not.toBeNull();
    expect(plan).not.toHaveProperty('grocery_list');
    expect(plan).not.toHaveProperty('plan_id');
  });
});

describe('parsePlanContent — plan rules', () => {
  it('flags calories outside the meal bounds', () => {
    const raw = validPlan();
    Object.assign(raw.days[0].meals[0], { calories: 900, protein_g: 50, carbs_g: 120, fat_g: 24 });
    expect(parsePlanContent(raw, TARGET).errors.join('\n')).toContain('breakfast: 900 kcal ngoài khoảng 225–525');
  });

  it('flags calories that do not match the macros', () => {
    const raw = validPlan();
    raw.days[0].meals[1].calories = 700;
    expect(parsePlanContent(raw, TARGET).errors.join('\n')).toContain('lệch quá 15%');
  });

  it('flags a dish repeated across days, ignoring case and spaces', () => {
    const raw = validPlan();
    raw.days[2].meals[2].name = '  món TRƯA 1 ';
    expect(parsePlanContent(raw, TARGET).errors.join('\n')).toContain('trùng với ngày 1');
  });

  it('flags a day missing one of the three meal types', () => {
    const raw = validPlan();
    raw.days[1].meals[2].meal_type = 'lunch';
    expect(parsePlanContent(raw, TARGET).errors.join('\n')).toContain('Ngày 2: phải có đúng 1 bữa');
  });
});

describe('calorie bounds follow the daily target (BRD NFR-4, v2.5.0)', () => {
  it('derives meal bounds from the target instead of fixed numbers', () => {
    expect(mealCalorieBounds(1624)).toEqual({
      breakfast: { min: 244, max: 568 },
      lunch: { min: 406, max: 731 },
      dinner: { min: 406, max: 731 },
    });
    expect(mealCalorieBounds(2806).lunch).toEqual({ min: 702, max: 1263 });
  });

  it('never lets the lower day bound drop under BMR', () => {
    expect(dayCalorieBounds({ target_calories: 1624, bmr: 1399 })).toEqual({ min: 1399, max: 1786 });
    expect(dayCalorieBounds({ target_calories: 2806, bmr: 1649 })).toEqual({ min: 2385, max: 3087 });
  });

  it('flags a day whose total is below the lower bound', () => {
    const raw = validPlan();
    for (const meal of raw.days[1].meals) Object.assign(meal, { calories: 400, protein_g: 24, carbs_g: 48, fat_g: 12 });
    expect(parsePlanContent(raw, TARGET).errors.join('\n')).toContain('Ngày 2: tổng 1200 kcal ngoài khoảng 1300–1650');
  });

  it('accepts a high target that the old fixed bounds (≤ 2200 kcal/day) could never reach', () => {
    const raw = validPlan();
    for (const day of raw.days) {
      Object.assign(day.meals[0], { calories: 750, protein_g: 45, carbs_g: 90, fat_g: 23 });
      Object.assign(day.meals[1], { calories: 1050, protein_g: 63, carbs_g: 126, fat_g: 32 });
      Object.assign(day.meals[2], { calories: 1000, protein_g: 60, carbs_g: 120, fat_g: 30 });
    }
    expect(parsePlanContent(raw, { target_calories: 2806, bmr: 1649 }).errors).toEqual([]);
  });
});
