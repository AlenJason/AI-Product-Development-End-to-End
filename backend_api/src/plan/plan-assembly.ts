import { randomUUID } from 'node:crypto';
import type {
  DailyTargetDto,
  DayPlanDto,
  GroceryCategoryDto,
  GroceryItemDto,
  MealPlanResponseDto,
} from './dto/meal-plan-response.dto.js';
import type { PlanContentDto } from './dto/plan-content.dto.js';
import { IngredientCategory, IngredientUnit } from './enums/ingredient.enum.js';
import { MealType } from './enums/meal-type.enum.js';
import type { PlanSource } from './enums/plan-source.enum.js';
import { normalizeKey } from './text.util.js';

const MEAL_ORDER = [MealType.BREAKFAST, MealType.LUNCH, MealType.DINNER];
const CATEGORY_ORDER = [IngredientCategory.PROTEIN, IngredientCategory.PRODUCE, IngredientCategory.PANTRY];

interface GroceryEntry {
  name: string;
  unit: IngredientUnit;
  amount: number;
  mealIds: string[];
}

export function assemblePlan(
  content: PlanContentDto,
  dailyTarget: DailyTargetDto,
  source: PlanSource,
  warnings: string[],
): MealPlanResponseDto {
  const days: DayPlanDto[] = content.days.map((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    const meals = [...day.meals].sort(
      (a, b) => MEAL_ORDER.indexOf(a.meal_type) - MEAL_ORDER.indexOf(b.meal_type),
    );
    return {
      day_number: dayNumber,
      meals: meals.map((meal, mealIndex) => ({
        ...meal,
        calories: Math.round(meal.calories),
        meal_id: `m${dayNumber}_${mealIndex + 1}`,
      })),
      workout: {
        title: day.workout.title,
        duration_minutes: day.workout.duration_minutes,
        exercises: day.workout.exercises.map((exercise, exerciseIndex) => ({
          ...exercise,
          exercise_id: `e${dayNumber}_${exerciseIndex + 1}`,
        })),
      },
    };
  });

  return {
    plan_id: randomUUID(),
    source,
    warnings,
    daily_target: dailyTarget,
    days,
    grocery_list: buildGroceryList(days),
  };
}

// Danh sách đi chợ luôn tính lại từ nguyên liệu của mọi món, không lấy từ Gemini hay client (BRD FR-3.1, FR-4.1).
export function buildGroceryList(days: DayPlanDto[]): GroceryCategoryDto[] {
  const byCategory = new Map<IngredientCategory, Map<string, GroceryEntry>>();

  for (const day of days) {
    for (const meal of day.meals) {
      for (const ingredient of meal.ingredients) {
        const entries = byCategory.get(ingredient.category) ?? new Map<string, GroceryEntry>();
        byCategory.set(ingredient.category, entries);

        const key = `${normalizeKey(ingredient.name)}|${ingredient.unit}`;
        const entry = entries.get(key);
        if (!entry) {
          entries.set(key, {
            name: ingredient.name.trim(),
            unit: ingredient.unit,
            amount: ingredient.amount,
            mealIds: [meal.meal_id],
          });
          continue;
        }
        entry.amount += ingredient.amount;
        if (!entry.mealIds.includes(meal.meal_id)) entry.mealIds.push(meal.meal_id);
      }
    }
  }

  return CATEGORY_ORDER.flatMap((category) => {
    const entries = byCategory.get(category);
    if (!entries) return [];
    const items: GroceryItemDto[] = [...entries.values()].map((entry) => ({
      name: entry.name,
      quantity: formatQuantity(entry.amount, entry.unit),
      source_meal_ids: entry.mealIds,
    }));
    return [{ category, items }];
  });
}

export function formatQuantity(amount: number, unit: IngredientUnit): string {
  const value = String(Math.round(amount * 10) / 10);
  switch (unit) {
    case IngredientUnit.G:
      return `${value}g`;
    case IngredientUnit.ML:
      return `${value}ml`;
    case IngredientUnit.PIECE:
      return `×${value}`;
    case IngredientUnit.TBSP:
      return `${value} muỗng canh`;
    case IngredientUnit.TSP:
      return `${value} muỗng cà phê`;
  }
}
