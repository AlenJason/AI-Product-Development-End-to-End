import type { IngredientDto, MealContentDto } from './dto/plan-content.dto.js';
import { IngredientUnit } from './enums/ingredient.enum.js';

// Khẩu phần đổi từ 10% trở lên thì ghi rõ hệ số, để "1 tô vừa" không còn đúng nghĩa đen nữa.
const PORTION_NOTE_THRESHOLD = 0.1;

// Nhân khẩu phần một món: calo, macro và lượng nguyên liệu cùng một hệ số, nên calo vẫn khớp 4P+4C+9F.
// Dùng cho thực đơn mẫu và món trong kho, vốn được soạn cho một mức calo cố định (BRD NFR-4, v2.5.0).
export function scaleMeal<T extends MealContentDto>(meal: T, factor: number): T {
  if (!(factor > 0)) throw new Error(`Hệ số khẩu phần phải dương (đang là ${factor})`);
  return {
    ...meal,
    portion:
      Math.abs(factor - 1) >= PORTION_NOTE_THRESHOLD
        ? `${meal.portion} (khẩu phần ×${formatFactor(factor)})`
        : meal.portion,
    calories: Math.round(meal.calories * factor),
    protein_g: roundTenth(meal.protein_g * factor),
    carbs_g: roundTenth(meal.carbs_g * factor),
    fat_g: roundTenth(meal.fat_g * factor),
    ingredients: meal.ingredients.map((ingredient) => scaleIngredient(ingredient, factor)),
  };
}

export function scaleMealToCalories<T extends MealContentDto>(meal: T, calories: number): T {
  return scaleMeal(meal, calories / meal.calories);
}

// Nhân cả ngày theo một hệ số để tổng calo bằng mục tiêu; tỉ lệ giữa các bữa giữ nguyên.
export function scaleMealsToTotal<T extends MealContentDto>(meals: T[], totalCalories: number): T[] {
  const current = meals.reduce((sum, meal) => sum + meal.calories, 0);
  const factor = totalCalories / current;
  const exact = meals.map((meal) => meal.calories * factor);
  const calories = exact.map(Math.floor);
  // Làm tròn từng bữa riêng có thể thiếu 1 kcal khi mục tiêu nằm ngay sàn BMR.
  // Phân bổ phần dư lớn nhất để tổng ngày đúng mục tiêu, không nới validation.
  const remainder = Math.round(totalCalories) - calories.reduce((sum, value) => sum + value, 0);
  const order = exact.map((value, index) => ({ index, fraction: value - calories[index] }));
  order.sort((a, b) => b.fraction - a.fraction || a.index - b.index);
  for (let i = 0; i < remainder; i++) calories[order[i].index]++;
  return meals.map((meal, index) => ({ ...scaleMeal(meal, factor), calories: calories[index] }));
}

function scaleIngredient(ingredient: IngredientDto, factor: number): IngredientDto {
  const amount = ingredient.amount * factor;
  switch (ingredient.unit) {
    case IngredientUnit.G:
    case IngredientUnit.ML:
      return { ...ingredient, amount: Math.max(5, Math.round(amount / 5) * 5) };
    case IngredientUnit.PIECE:
    case IngredientUnit.TBSP:
    case IngredientUnit.TSP:
      return { ...ingredient, amount: Math.max(0.5, Math.round(amount * 2) / 2) };
  }
}

function roundTenth(value: number): number {
  return Math.round(value * 10) / 10;
}

function formatFactor(factor: number): string {
  return String(Math.round(factor * 10) / 10).replace('.', ',');
}
