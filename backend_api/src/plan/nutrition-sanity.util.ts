import type { MealPlanResponse } from './interfaces/plan.interface.js';

// Khoảng calo hợp lý theo loại bữa ăn — BRD.md mục 7, NFR-4 (Nutrition Data Sanity Check).
const CALORIE_BOUNDS: Record<string, { min: number; max: number }> = {
  'Bữa sáng': { min: 250, max: 600 },
  'Bữa trưa': { min: 400, max: 800 },
  'Bữa tối': { min: 400, max: 800 },
};

export function isNutritionWithinBounds(plan: MealPlanResponse): boolean {
  return plan.days.every((day) =>
    day.meals.every((meal) => {
      const bounds = CALORIE_BOUNDS[meal.meal_type];
      if (!bounds) return true;
      return meal.calories >= bounds.min && meal.calories <= bounds.max;
    }),
  );
}
