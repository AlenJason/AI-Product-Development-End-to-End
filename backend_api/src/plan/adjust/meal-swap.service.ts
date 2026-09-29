import { BadRequestException, Injectable, Logger, UnprocessableEntityException } from '@nestjs/common';
import type { SwapMealDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { type DayContentDto, MealContentDto } from '../dto/plan-content.dto.js';
import { GeminiService } from '../gemini.service.js';
import { generateWithRetry } from '../gemini-retry.js';
import { scaleMealToCalories } from '../meal-scaling.js';
import { type CalorieRange, findPlanViolations, mealCalorieBounds, parseContent } from '../plan-validation.js';
import { WARNINGS } from '../plan-warnings.js';
import { findAvoidedIngredient } from '../restriction-matcher.js';
import { mealCandidates } from '../swap-pools.js';
import { normalizeKey } from '../text.util.js';
import { buildMealSwapPrompt } from './adjust-prompts.js';
import { type ClientPlanContext, readClientPlan, rebuildPlan } from './client-plan.js';
import { pickOne, RandomSource } from './random-source.js';

// Calo món mới lệch tối đa ±10% so với món cũ (BRD FR-4.1).
export const SWAP_CALORIE_TOLERANCE = 0.1;

@Injectable()
export class MealSwapService {
  private readonly logger = new Logger(MealSwapService.name);

  constructor(
    private readonly gemini: GeminiService,
    private readonly random: RandomSource,
  ) {}

  async swap(dto: SwapMealDto): Promise<MealPlanResponseDto> {
    const context = readClientPlan(dto.profile, dto.plan);
    const [dayIndex, mealIndex] = parseMealId(dto.meal_id);
    const original = context.plan.days[dayIndex]?.meals[mealIndex];
    if (!original) throw new BadRequestException(`meal_id ${dto.meal_id} không có trong plan`);

    const range = swapCalorieRange(original.calories, mealCalorieBounds(context.target.target_calories)[original.meal_type]);
    const usedNames = new Set(context.plan.days.flatMap((day) => day.meals.map((meal) => normalizeKey(meal.name))));
    const withMeal = (meal: MealContentDto): DayContentDto[] =>
      context.plan.days.map((day, d) => ({
        ...day,
        meals: day.meals.map((existing, m) => (d === dayIndex && m === mealIndex ? meal : existing)),
      }));
    const violations = (meal: MealContentDto): string[] => [
      ...(meal.meal_type === original.meal_type ? [] : [`meal_type phải là ${original.meal_type}`]),
      ...(meal.calories >= range.min && meal.calories <= range.max ? [] : [`calories ${meal.calories} ngoài khoảng ${range.min}–${range.max}`]),
      ...(usedNames.has(normalizeKey(meal.name)) ? [`món "${meal.name}" đã có trong kế hoạch`] : []),
      ...(findAvoidedIngredient(meal, context.match.avoidIngredients) === null ? [] : ['có nguyên liệu người dùng cần tránh']),
      ...findPlanViolations({ days: withMeal(meal) }, context.target),
    ];

    const fromGemini = await this.fromGemini(context, original, range, usedNames, violations);
    const replacement = fromGemini ?? this.fromPool(context, original, usedNames, violations);
    if (!replacement) {
      throw new UnprocessableEntityException('Không tìm được món thay thế phù hợp với bữa này và các hạn chế bạn đã nhập.');
    }
    const extra = !fromGemini && context.match.hasUnrecognized ? [WARNINGS.restrictionsIncomplete] : [];
    return rebuildPlan(context, withMeal(replacement), extra);
  }

  private async fromGemini(
    context: ClientPlanContext,
    original: MealContentDto,
    range: CalorieRange,
    usedNames: Set<string>,
    violations: (meal: MealContentDto) => string[],
  ): Promise<MealContentDto | null> {
    if (!this.gemini.isConfigured) return null;
    const names = context.plan.days.flatMap((day) => day.meals.map((meal) => meal.name));
    return generateWithRetry(
      this.logger,
      'đổi món',
      this.gemini.budget,
      (timeoutMs) => this.gemini.generateJson(buildMealSwapPrompt(context.profile, original, range, names), timeoutMs),
      (raw) => {
        const parsed = parseContent(MealContentDto, raw);
        if (!parsed.value) return parsed;
        const errors = violations(parsed.value);
        return errors.length > 0 ? { value: null, errors } : parsed;
      },
    );
  }

  // Kho món: cùng bữa, không dị ứng, không trùng; nhân khẩu phần cho đúng calo món cũ (nằm sẵn trong ±10%).
  private fromPool(
    context: ClientPlanContext,
    original: MealContentDto,
    usedNames: Set<string>,
    violations: (meal: MealContentDto) => string[],
  ): MealContentDto | null {
    const candidates = mealCandidates(original.meal_type, {
      avoidIngredients: context.match.avoidIngredients,
      excludeNames: usedNames,
    })
      .map((meal) => scaleMealToCalories(meal, original.calories))
      .filter((meal) => violations(meal).length === 0);
    return pickOne(candidates, this.random) ?? null;
  }
}

export function swapCalorieRange(calories: number, mealBounds: CalorieRange): CalorieRange {
  return {
    min: Math.max(Math.round(calories * (1 - SWAP_CALORIE_TOLERANCE)), mealBounds.min),
    max: Math.min(Math.round(calories * (1 + SWAP_CALORIE_TOLERANCE)), mealBounds.max),
  };
}

// "m2_3" → [1, 2]; định dạng đã được DTO kiểm.
function parseMealId(mealId: string): [number, number] {
  const [day, meal] = mealId.slice(1).split('_').map(Number);
  return [day - 1, meal - 1];
}
