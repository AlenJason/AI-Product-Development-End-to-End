import type { DayContentDto, ExerciseContentDto, PlanContentDto } from './dto/plan-content.dto.js';
import { WALK_EXERCISE } from './exercise-presets.js';
import { scaleMealToCalories } from './meal-scaling.js';
import { findAvoidedIngredient, hasAvoidedTag, type RestrictionMatch } from './restriction-matcher.js';
import { exerciseCandidates, exerciseLevel, mealCandidates, toPlanExercise } from './swap-pools.js';
import { normalizeKey } from './text.util.js';

export interface FilterResult {
  plan: PlanContentDto;
  // Có món/động tác vướng hạn chế đã nhận ra nhưng kho không còn gì thay được → vẫn giữ, app phải cảnh báo.
  incomplete: boolean;
}

// Lọc thực đơn mẫu theo dị ứng, chấn thương đã nhận ra (D4): thay món/động tác vướng hạn chế bằng món/động tác
// trong kho. Tất định (luôn lấy ứng viên đầu tiên) để cùng hồ sơ luôn ra cùng thực đơn mẫu.
export function filterPlanByRestrictions(plan: PlanContentDto, match: RestrictionMatch): FilterResult {
  if (match.avoidIngredients.length === 0 && match.avoidTags.length === 0) return { plan, incomplete: false };

  let incomplete = false;
  const usedMealNames = new Set(plan.days.flatMap((day) => day.meals.map((meal) => normalizeKey(meal.name))));

  const days = plan.days.map((day): DayContentDto => {
    const meals = day.meals.map((meal) => {
      if (findAvoidedIngredient(meal, match.avoidIngredients) === null) return meal;
      const [candidate] = mealCandidates(meal.meal_type, {
        avoidIngredients: match.avoidIngredients,
        excludeNames: usedMealNames,
      });
      if (!candidate) {
        incomplete = true;
        return meal;
      }
      usedMealNames.add(normalizeKey(candidate.name));
      return scaleMealToCalories(candidate, meal.calories);
    });

    const dayExerciseNames = new Set(day.workout.exercises.map((exercise) => normalizeKey(exercise.name)));
    const exercises = day.workout.exercises.flatMap((exercise): ExerciseContentDto[] => {
      if (!hasAvoidedTag(exercise, match.avoidTags)) return [exercise];
      const [candidate] = exerciseCandidates(exercise.muscle_group, {
        avoidTags: match.avoidTags,
        excludeNames: dayExerciseNames,
        maxLevel: exerciseLevel(exercise.name) ?? 3,
      });
      if (!candidate) return [];
      dayExerciseNames.add(normalizeKey(candidate.name));
      return [toPlanExercise(candidate, exercise.sets)];
    });

    return { meals, workout: { ...day.workout, exercises: exercises.length > 0 ? exercises : [WALK_EXERCISE] } };
  });

  return { plan: { days }, incomplete };
}

// Kiểm lại kết quả Gemini theo hạn chế đã nhận ra. Thông báo không nêu từ khoá hay tag:
// chúng suy ra từ dữ liệu sức khoẻ và thông báo này được ghi log (#12).
export function findRestrictionViolations(days: DayContentDto[], match: RestrictionMatch): string[] {
  const violations: string[] = [];
  days.forEach((day, dayIndex) => {
    for (const meal of day.meals) {
      if (findAvoidedIngredient(meal, match.avoidIngredients) !== null) {
        violations.push(`Ngày ${dayIndex + 1} ${meal.meal_type}: có nguyên liệu người dùng cần tránh`);
      }
    }
    if (day.workout.exercises.some((exercise) => hasAvoidedTag(exercise, match.avoidTags))) {
      violations.push(`Ngày ${dayIndex + 1}: có động tác không phù hợp chấn thương đã khai`);
    }
  });
  return violations;
}
