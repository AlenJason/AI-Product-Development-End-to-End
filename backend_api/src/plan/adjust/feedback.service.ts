import { Injectable, Logger } from '@nestjs/common';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  ValidateNested,
} from 'class-validator';
import type { FeedbackDto } from '../dto/adjust-plan.dto.js';
import type { MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import { MealContentDto, type DayContentDto } from '../dto/plan-content.dto.js';
import type { MuscleGroup } from '../enums/exercise.enum.js';
import { Eating } from '../enums/feedback.enum.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { GeminiService } from '../gemini.service.js';
import { generateWithRetry } from '../gemini-retry.js';
import { assemblePlan, MEAL_ORDER } from '../plan-assembly.js';
import {
  dayCalorieBounds,
  findPlanViolations,
  parseContent,
} from '../plan-validation.js';
import { PlanService } from '../plan.service.js';
import { SAFETY_WARNING_MESSAGE, WARNINGS } from '../plan-warnings.js';
import { findRestrictionViolations } from '../restriction-filter.js';
import { matchRestrictions } from '../restriction-matcher.js';
import { buildDayMealsPrompt } from './adjust-prompts.js';
import {
  type ClientPlanContext,
  readClientPlan,
  rebuildPlan,
} from './client-plan.js';
import {
  adjustWorkout,
  describeFeedback,
  hasDangerSign,
  normalizeFeedback,
  type NormalizedFeedback,
} from './workout-rules.js';

export const OVER_EATING_FACTOR = 0.9;

class DayMealsDto {
  @IsArray()
  @ArrayMinSize(3)
  @ArrayMaxSize(3)
  @ValidateNested({ each: true })
  @Type(() => MealContentDto)
  meals: MealContentDto[];
}

export interface FeedbackResult {
  response: {
    plan: MealPlanResponseDto;
    safety_warning: { message: string } | null;
  };
  isNewPlan: boolean;
}

@Injectable()
export class FeedbackService {
  private readonly logger = new Logger(FeedbackService.name);

  constructor(
    private readonly gemini: GeminiService,
    private readonly planService: PlanService,
  ) {}

  async apply(dto: FeedbackDto): Promise<FeedbackResult> {
    const context = readClientPlan(dto.profile, dto.plan);
    const feedback = normalizeFeedback(dto);
    const safety_warning = hasDangerSign(feedback)
      ? { message: SAFETY_WARNING_MESSAGE }
      : null;
    const trainedMuscles = new Set<MuscleGroup>(
      context.plan.days[dto.day_number - 1].workout.exercises.map(
        (exercise) => exercise.muscle_group,
      ),
    );

    if (dto.day_number === 3) {
      const plan = await this.nextPlan(context, feedback, trainedMuscles);
      return { response: { plan, safety_warning }, isNewPlan: true };
    }

    const nextIndex = dto.day_number;
    const days: DayContentDto[] = context.plan.days.map((day) => ({
      meals: day.meals,
      workout: day.workout,
    }));
    days[nextIndex] = {
      ...days[nextIndex],
      workout: adjustWorkout(
        days[nextIndex].workout,
        feedback,
        trainedMuscles,
        context.match.avoidTags,
      ),
    };

    const extra: string[] = [];
    if (!hasDangerSign(feedback) && feedback.eating !== Eating.ON_PLAN) {
      const meals = await this.rebalanceMeals(
        context,
        days,
        nextIndex,
        feedback.eating,
      );
      if (meals) days[nextIndex] = { ...days[nextIndex], meals };
      else extra.push(WARNINGS.mealsNotRebalanced);
    }
    return {
      response: { plan: rebuildPlan(context, days, extra), safety_warning },
      isNewPlan: false,
    };
  }

  private async nextPlan(
    context: ClientPlanContext,
    feedback: NormalizedFeedback,
    trainedMuscles: Set<MuscleGroup>,
  ): Promise<MealPlanResponseDto> {
    const options = {
      feedbackNote: describeFeedback(feedback),
      ...(hasDangerSign(feedback) ? { skipGemini: true } : {}),
    };
    const next = await this.planService.generatePlan(context.profile, options);
    const avoidTags = matchRestrictions(context.profile.restrictions).avoidTags;
    const days: DayContentDto[] = next.days.map((day, index) => ({
      meals: day.meals,
      workout:
        index === 0
          ? adjustWorkout(day.workout, feedback, trainedMuscles, avoidTags)
          : day.workout,
    }));
    const warnings = [...next.warnings];
    if (
      next.source === PlanSource.SAMPLE &&
      feedback.eating !== Eating.ON_PLAN &&
      !hasDangerSign(feedback)
    ) {
      warnings.push(WARNINGS.mealsNotRebalanced);
    }
    return assemblePlan(
      { days },
      next.daily_target,
      next.source,
      warnings,
      next.plan_id,
    );
  }

  private async rebalanceMeals(
    context: ClientPlanContext,
    days: DayContentDto[],
    dayIndex: number,
    eating: Exclude<Eating, Eating.ON_PLAN>,
  ): Promise<MealContentDto[] | null> {
    if (!this.gemini.isConfigured) return null;
    const { target } = context;
    const planRange = dayCalorieBounds(target);
    const dayCalories =
      eating === Eating.OVER
        ? Math.max(
            Math.round(target.target_calories * OVER_EATING_FACTOR),
            target.bmr,
          )
        : target.target_calories;
    const range =
      eating === Eating.OVER
        ? { min: planRange.min, max: target.target_calories }
        : planRange;
    const otherNames = days.flatMap((day, index) =>
      index === dayIndex ? [] : day.meals.map((meal) => meal.name),
    );

    return generateWithRetry(
      this.logger,
      'cân đối món ăn',
      this.gemini.budget,
      (timeoutMs) =>
        this.gemini.generateJson(
          buildDayMealsPrompt(
            context.profile,
            target.target_calories,
            dayIndex + 1,
            dayCalories,
            range,
            eating,
            otherNames,
          ),
          timeoutMs,
        ),
      (raw) => {
        const parsed = parseContent(DayMealsDto, raw);
        if (!parsed.value) return { value: null, errors: parsed.errors };
        const meals = [...parsed.value.meals].sort(
          (a, b) =>
            MEAL_ORDER.indexOf(a.meal_type) - MEAL_ORDER.indexOf(b.meal_type),
        );
        const candidateDays = days.map((day, index) =>
          index === dayIndex ? { ...day, meals } : day,
        );
        const total = meals.reduce((sum, meal) => sum + meal.calories, 0);
        const errors = [
          ...findPlanViolations({ days: candidateDays }, target),
          ...(total <= range.max
            ? []
            : [`Ngày ${dayIndex + 1}: tổng ${total} kcal vượt ${range.max}`]),
          ...findRestrictionViolations(
            [candidateDays[dayIndex]],
            context.match,
          ),
        ];
        return errors.length > 0
          ? { value: null, errors }
          : { value: meals, errors: [] };
      },
    );
  }
}
