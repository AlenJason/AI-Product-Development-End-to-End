import { BadRequestException, ConflictException } from '@nestjs/common';
import { computeDailyTarget } from '../daily-target.js';
import type { CreatePlanDto } from '../dto/create-plan.dto.js';
import type { DailyTargetDto, MealPlanResponseDto } from '../dto/meal-plan-response.dto.js';
import type { DayContentDto } from '../dto/plan-content.dto.js';
import { PlanSource } from '../enums/plan-source.enum.js';
import { assemblePlan, MEAL_ORDER } from '../plan-assembly.js';
import { findPlanViolations } from '../plan-validation.js';
import { hasRestrictions, profileWarnings, WARNINGS } from '../plan-warnings.js';
import { matchRestrictions, type RestrictionMatch } from '../restriction-matcher.js';

export interface ClientPlanContext {
  profile: CreatePlanDto;
  plan: MealPlanResponseDto;
  target: DailyTargetDto;
  flooredToBmr: boolean;
  match: RestrictionMatch;
}

// Kiểm plan client gửi lên trước khi đổi món/đổi bài/feedback (BRD 6.4, #2, #13, #16).
// Cấu trúc đã qua ValidationPipe; ở đây kiểm ID đúng vị trí, quy tắc calo/trùng món, và mục tiêu calo
// tính lại từ hồ sơ — không tin `daily_target`, `grocery_list`, `warnings` trong plan.
export function readClientPlan(profile: CreatePlanDto, plan: MealPlanResponseDto): ClientPlanContext {
  const { target, flooredToBmr } = computeDailyTarget(profile);
  if (plan.daily_target.target_calories !== target.target_calories || plan.daily_target.bmr !== target.bmr) {
    throw new ConflictException('Kế hoạch này được tạo cho hồ sơ khác (mục tiêu calo đã đổi). Hãy tạo kế hoạch mới.');
  }
  const violations = [...findIdErrors(plan), ...findPlanViolations(plan, target)];
  if (violations.length > 0) {
    throw new BadRequestException(['Kế hoạch gửi lên không đúng hợp đồng', ...violations.slice(0, 10)]);
  }
  return { profile, plan, target, flooredToBmr, match: matchRestrictions(profile.restrictions) };
}

// Lắp lại plan sau khi sửa: giữ plan_id và source, gán lại ID theo vị trí, tính lại danh sách đi chợ (#7)
// và cảnh báo từ hồ sơ hiện tại.
export function rebuildPlan(
  context: ClientPlanContext,
  days: DayContentDto[],
  extraWarnings: string[] = [],
): MealPlanResponseDto {
  return assemblePlan(
    { days },
    context.target,
    context.plan.source,
    unique([...planWarnings(context), ...extraWarnings]),
    context.plan.plan_id,
  );
}

// Cảnh báo theo hồ sơ + theo nguồn plan: plan mẫu chỉ được lọc bằng từ khoá (D4).
export function planWarnings(context: Pick<ClientPlanContext, 'profile' | 'plan' | 'target' | 'flooredToBmr' | 'match'>): string[] {
  const warnings = profileWarnings(context.profile, context.flooredToBmr, context.target.bmr);
  if (context.plan.source === PlanSource.SAMPLE && hasRestrictions(context.profile)) {
    warnings.push(WARNINGS.sampleKeywordFiltered);
    if (context.match.hasUnrecognized) warnings.push(WARNINGS.restrictionsIncomplete);
  }
  return warnings;
}

function findIdErrors(plan: MealPlanResponseDto): string[] {
  const errors: string[] = [];
  plan.days.forEach((day, dayIndex) => {
    const dayNumber = dayIndex + 1;
    if (day.day_number !== dayNumber) errors.push(`days[${dayIndex}].day_number phải là ${dayNumber}`);
    day.meals.forEach((meal, mealIndex) => {
      if (meal.meal_type !== MEAL_ORDER[mealIndex] || meal.meal_id !== `m${dayNumber}_${mealIndex + 1}`) {
        errors.push(`Ngày ${dayNumber}: bữa thứ ${mealIndex + 1} phải là ${MEAL_ORDER[mealIndex]} với meal_id m${dayNumber}_${mealIndex + 1}`);
      }
    });
    day.workout.exercises.forEach((exercise, exerciseIndex) => {
      if (exercise.exercise_id !== `e${dayNumber}_${exerciseIndex + 1}`) {
        errors.push(`Ngày ${dayNumber}: động tác thứ ${exerciseIndex + 1} phải có exercise_id e${dayNumber}_${exerciseIndex + 1}`);
      }
    });
  });
  return errors;
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}
