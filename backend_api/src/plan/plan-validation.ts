import { plainToInstance } from 'class-transformer';
import { validateSync, type ValidationError } from 'class-validator';
import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
import { PlanContentDto } from './dto/plan-content.dto.js';
import { MealType } from './enums/meal-type.enum.js';
import { normalizeKey } from './text.util.js';
import { safePlanPath, type PlanValidationIssue } from './plan-diagnostics.js';

// Calo mỗi bữa tính theo tỉ lệ mục tiêu ngày, không dùng số cố định: trần cố định cũ
// (sáng 600, trưa/tối 800) chặn tổng ngày ở 2200 kcal, thấp hơn mục tiêu của nhiều người (BRD NFR-4, v2.5.0).
export const MEAL_CALORIE_SHARE: Record<
  MealType,
  { min: number; max: number }
> = {
  [MealType.BREAKFAST]: { min: 0.15, max: 0.35 },
  [MealType.LUNCH]: { min: 0.25, max: 0.45 },
  [MealType.DINNER]: { min: 0.25, max: 0.45 },
};

// Tổng calo một ngày so với mục tiêu. Cận dưới không bao giờ thấp hơn BMR (FR-1.5, #13).
export const DAY_CALORIE_SHARE = { min: 0.85, max: 1.1 };

// Lệch tối đa giữa calo khai báo và 4P + 4C + 9F (BRD NFR-4).
export const MACRO_CALORIE_TOLERANCE = 0.15;

export type CalorieTarget = Pick<DailyTargetDto, 'target_calories' | 'bmr'>;

export interface CalorieRange {
  min: number;
  max: number;
}

export function mealCalorieBounds(
  targetCalories: number,
): Record<MealType, CalorieRange> {
  const bounds = {} as Record<MealType, CalorieRange>;
  for (const mealType of Object.values(MealType)) {
    const share = MEAL_CALORIE_SHARE[mealType];
    bounds[mealType] = {
      min: Math.round(share.min * targetCalories),
      max: Math.round(share.max * targetCalories),
    };
  }
  return bounds;
}

export function dayCalorieBounds(target: CalorieTarget): CalorieRange {
  return {
    min: Math.max(
      Math.round(DAY_CALORIE_SHARE.min * target.target_calories),
      target.bmr,
    ),
    max: Math.round(DAY_CALORIE_SHARE.max * target.target_calories),
  };
}

export interface PlanContentResult {
  plan: PlanContentDto | null;
  errors: string[];
  issues?: PlanValidationIssue[];
}

// Chỉ kiểm cấu trúc (class-validator). Dùng khi nội dung còn phải xử lý tiếp (lọc, nhân khẩu phần)
// trước lần kiểm đầy đủ bằng parsePlanContent().
export function parsePlanStructure(raw: unknown): PlanContentResult {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return {
      plan: null,
      errors: ['Kết quả không phải một object JSON'],
      issues: [
        {
          validator: 'class-validator',
          kind: 'schema',
          code: 'JSON_OBJECT',
          path: '$',
        },
      ],
    };
  }
  const plan = plainToInstance(PlanContentDto, raw);
  const structural = validateSync(plan, { whitelist: true });
  return structural.length > 0
    ? {
        plan: null,
        errors: flattenErrors(structural),
        issues: structuralIssues(structural),
      }
    : { plan, errors: [], issues: [] };
}

// Kiểm một object theo DTO bất kỳ (một món, một động tác, 3 bữa của một ngày) — dùng cho kết quả Gemini khi đổi món,
// đổi bài tập, cân đối món ăn.
export function parseContent<T extends object>(
  dto: new () => T,
  raw: unknown,
): { value: T | null; errors: string[] } {
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) {
    return { value: null, errors: ['Kết quả không phải một object JSON'] };
  }
  const value = plainToInstance(dto, raw);
  const errors = validateSync(value, { whitelist: true });
  return errors.length > 0
    ? { value: null, errors: flattenErrors(errors) }
    : { value, errors: [] };
}

export function parsePlanContent(
  raw: unknown,
  target: CalorieTarget,
): PlanContentResult {
  const parsed = parsePlanStructure(raw);
  if (!parsed.plan) return parsed;
  const findings = inspectPlan(parsed.plan, target);
  return findings.errors.length > 0 ? { plan: null, ...findings } : parsed;
}

export function findPlanViolations(
  plan: PlanContentDto,
  target: CalorieTarget,
): string[] {
  return inspectPlan(plan, target).errors;
}

function inspectPlan(
  plan: PlanContentDto,
  target: CalorieTarget,
): { errors: string[]; issues: PlanValidationIssue[] } {
  const violations: string[] = [];
  const issues: PlanValidationIssue[] = [];
  const issue = (code: string, path: string) =>
    issues.push({ validator: 'plan-rules', kind: 'semantic', code, path });
  const firstDayByName = new Map<string, number>();
  const expectedMealTypes = Object.values(MealType).sort().join();
  const mealBounds = mealCalorieBounds(target.target_calories);
  const dayBounds = dayCalorieBounds(target);

  plan.days.forEach((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    const mealTypes = day.meals
      .map((meal) => meal.meal_type)
      .sort()
      .join();
    if (mealTypes !== expectedMealTypes) {
      issue('MEAL_TYPES', `days[${dayIndex}].meals`);
      violations.push(
        `Ngày ${dayNumber}: phải có đúng 1 bữa ${Object.values(MealType).join(', ')}`,
      );
    }

    const dayCalories = Math.round(
      day.meals.reduce((sum, meal) => sum + meal.calories, 0),
    );
    if (dayCalories < dayBounds.min || dayCalories > dayBounds.max) {
      issue('DAY_CALORIES', `days[${dayIndex}].meals`);
      violations.push(
        `Ngày ${dayNumber}: tổng ${dayCalories} kcal ngoài khoảng ${dayBounds.min}–${dayBounds.max}`,
      );
    }

    for (const [mealIndex, meal] of day.meals.entries()) {
      const path = `days[${dayIndex}].meals[${mealIndex}]`;
      const label = `Ngày ${dayNumber} ${meal.meal_type}`;
      const { min, max } = mealBounds[meal.meal_type];
      if (meal.calories < min || meal.calories > max) {
        issue('MEAL_CALORIES', `${path}.calories`);
        violations.push(
          `${label}: ${meal.calories} kcal ngoài khoảng ${min}–${max}`,
        );
      }

      const macroCalories =
        4 * meal.protein_g + 4 * meal.carbs_g + 9 * meal.fat_g;
      if (
        Math.abs(macroCalories - meal.calories) >
        meal.calories * MACRO_CALORIE_TOLERANCE
      ) {
        issue('MACRO_CALORIES', path);
        violations.push(
          `${label}: ${meal.calories} kcal lệch quá ${MACRO_CALORIE_TOLERANCE * 100}% so với 4P+4C+9F = ${Math.round(macroCalories)}`,
        );
      }

      const key = normalizeKey(meal.name);
      const firstDay = firstDayByName.get(key);
      if (firstDay === undefined) {
        firstDayByName.set(key, dayNumber);
      } else {
        issue('DUPLICATE_MEAL', `${path}.name`);
        violations.push(
          `Ngày ${dayNumber}: món "${meal.name.trim()}" trùng với ngày ${firstDay}`,
        );
      }
    }
  });

  return { errors: violations, issues };
}

function structuralIssues(
  errors: ValidationError[],
  parent = '',
): PlanValidationIssue[] {
  return errors.flatMap((error) => {
    const path = /^\d+$/.test(error.property)
      ? `${parent}[${error.property}]`
      : parent
        ? `${parent}.${error.property}`
        : error.property;
    const own = Object.keys(error.constraints ?? {}).map(
      (constraint): PlanValidationIssue => ({
        validator: 'class-validator',
        kind: 'schema',
        path: safePlanPath(path),
        code: ['isDefined', 'isNotEmpty'].includes(constraint)
          ? 'REQUIRED'
          : ['arrayMinSize', 'arrayMaxSize'].includes(constraint)
            ? 'ARRAY_SIZE'
            : [
                  'isNumber',
                  'isInt',
                  'isString',
                  'isArray',
                  'nestedValidation',
                  'isObject',
                ].includes(constraint)
              ? 'TYPE'
              : constraint === 'isEnum'
                ? 'ENUM'
                : ['min', 'max', 'maxLength', 'isPositive'].includes(constraint)
                  ? 'RANGE'
                  : 'SCHEMA',
      }),
    );
    return [...own, ...structuralIssues(error.children ?? [], path)];
  });
}

function flattenErrors(errors: ValidationError[], parentPath = ''): string[] {
  return errors.flatMap((error) => {
    const path = parentPath
      ? `${parentPath}.${error.property}`
      : error.property;
    const own = Object.values(error.constraints ?? {}).map(
      (message) => `${path}: ${message}`,
    );
    return [...own, ...flattenErrors(error.children ?? [], path)];
  });
}
