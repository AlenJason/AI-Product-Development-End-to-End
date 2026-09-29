import type { MealContentDto } from './dto/plan-content.dto.js';
import { IngredientCategory, IngredientUnit } from './enums/ingredient.enum.js';
import { MealType } from './enums/meal-type.enum.js';
import { scaleMeal, scaleMealsToTotal, scaleMealToCalories } from './meal-scaling.js';

const meal: MealContentDto = {
  meal_type: MealType.BREAKFAST,
  name: 'Bánh mì trứng ốp la',
  portion: '1 ổ',
  calories: 380,
  protein_g: 15,
  carbs_g: 45,
  fat_g: 15,
  ingredients: [
    { name: 'Bánh mì', amount: 1, unit: IngredientUnit.PIECE, category: IngredientCategory.PANTRY },
    { name: 'Trứng gà', amount: 2, unit: IngredientUnit.PIECE, category: IngredientCategory.PROTEIN },
    { name: 'Dưa leo', amount: 40, unit: IngredientUnit.G, category: IngredientCategory.PRODUCE },
    { name: 'Dầu ăn', amount: 1, unit: IngredientUnit.TSP, category: IngredientCategory.PANTRY },
  ],
};

describe('scaleMeal', () => {
  it('scales calories, macros and ingredients by the same factor, so macros still match calories', () => {
    const scaled = scaleMeal(meal, 1.5);
    expect(scaled).toMatchObject({ calories: 570, protein_g: 22.5, carbs_g: 67.5, fat_g: 22.5 });
    expect(scaled.ingredients.map((i) => i.amount)).toEqual([1.5, 3, 60, 1.5]);
    expect(4 * scaled.protein_g + 4 * scaled.carbs_g + 9 * scaled.fat_g).toBeCloseTo(4 * 15 * 1.5 + 4 * 45 * 1.5 + 9 * 15 * 1.5);
  });

  it('notes the factor in the portion only when it changes by 10% or more', () => {
    expect(scaleMeal(meal, 1.05).portion).toBe('1 ổ');
    expect(scaleMeal(meal, 1.5).portion).toBe('1 ổ (khẩu phần ×1,5)');
    expect(scaleMeal(meal, 0.5).portion).toBe('1 ổ (khẩu phần ×0,5)');
  });

  it('keeps tiny portions above zero', () => {
    const scaled = scaleMeal(meal, 0.05);
    expect(scaled.ingredients.map((i) => i.amount)).toEqual([0.5, 0.5, 5, 0.5]);
    expect(scaled.calories).toBeGreaterThan(0);
  });

  it('does not mutate the original meal', () => {
    scaleMeal(meal, 2);
    expect(meal.calories).toBe(380);
    expect(meal.ingredients[1].amount).toBe(2);
  });

  it('rejects a non-positive factor', () => {
    expect(() => scaleMeal(meal, 0)).toThrow();
  });
});

describe('scaleMealToCalories / scaleMealsToTotal', () => {
  it('hits the requested calories', () => {
    expect(scaleMealToCalories(meal, 456).calories).toBe(456);
  });

  it('brings a day to the target total and keeps the ratio between meals', () => {
    const lunch = { ...meal, meal_type: MealType.LUNCH, calories: 620 };
    const [b, l] = scaleMealsToTotal([meal, lunch], 2000);
    expect(b.calories + l.calories).toBe(2000);
    expect(b.calories / l.calories).toBeCloseTo(380 / 620, 2);
  });
});
