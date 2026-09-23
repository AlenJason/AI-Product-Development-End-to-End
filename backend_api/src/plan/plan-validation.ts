import { plainToInstance } from 'class-transformer';
import { validateSync, type ValidationError } from 'class-validator';
import { PlanContentDto } from './dto/plan-content.dto.js';
import { MealType } from './enums/meal-type.enum.js';
import { normalizeKey } from './text.util.js';

// Khoảng calo hợp lý theo bữa (BRD NFR-4).
export const CALORIE_BOUNDS: Record<MealType, { min: number; max: number }> = {
  [MealType.BREAKFAST]: { min: 250, max: 600 },
  [MealType.LUNCH]: { min: 400, max: 800 },
  [MealType.DINNER]: { min: 400, max: 800 },
};

// Lệch tối đa giữa calo khai báo và 4P + 4C + 9F (BRD NFR-4).
export const MACRO_CALORIE_TOLERANCE = 0.15;

export interface PlanContentResult {
  plan: PlanContentDto | null;
  errors: string[];
}

export function parsePlanContent(raw: unknown): PlanContentResult {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return { plan: null, errors: ['Kết quả không phải một object JSON'] };
  }
  const plan = plainToInstance(PlanContentDto, raw);
  const structural = validateSync(plan, { whitelist: true });
  if (structural.length > 0) {
    return { plan: null, errors: flattenErrors(structural) };
  }
  const violations = findPlanViolations(plan);
  return violations.length > 0 ? { plan: null, errors: violations } : { plan, errors: [] };
}

export function findPlanViolations(plan: PlanContentDto): string[] {
  const violations: string[] = [];
  const firstDayByName = new Map<string, number>();
  const expectedMealTypes = Object.values(MealType).sort().join();

  plan.days.forEach((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    const mealTypes = day.meals.map((meal) => meal.meal_type).sort().join();
    if (mealTypes !== expectedMealTypes) {
      violations.push(`Ngày ${dayNumber}: phải có đúng 1 bữa ${Object.values(MealType).join(', ')}`);
    }

    for (const meal of day.meals) {
      const label = `Ngày ${dayNumber} ${meal.meal_type}`;
      const { min, max } = CALORIE_BOUNDS[meal.meal_type];
      if (meal.calories < min || meal.calories > max) {
        violations.push(`${label}: ${meal.calories} kcal ngoài khoảng ${min}–${max}`);
      }

      const macroCalories = 4 * meal.protein_g + 4 * meal.carbs_g + 9 * meal.fat_g;
      if (Math.abs(macroCalories - meal.calories) > meal.calories * MACRO_CALORIE_TOLERANCE) {
        violations.push(
          `${label}: ${meal.calories} kcal lệch quá ${MACRO_CALORIE_TOLERANCE * 100}% so với 4P+4C+9F = ${Math.round(macroCalories)}`,
        );
      }

      const key = normalizeKey(meal.name);
      const firstDay = firstDayByName.get(key);
      if (firstDay === undefined) {
        firstDayByName.set(key, dayNumber);
      } else {
        violations.push(`Ngày ${dayNumber}: món "${meal.name.trim()}" trùng với ngày ${firstDay}`);
      }
    }
  });

  return violations;
}

function flattenErrors(errors: ValidationError[], parentPath = ''): string[] {
  return errors.flatMap((error) => {
    const path = parentPath ? `${parentPath}.${error.property}` : error.property;
    const own = Object.values(error.constraints ?? {}).map((message) => `${path}: ${message}`);
    return [...own, ...flattenErrors(error.children ?? [], path)];
  });
}
