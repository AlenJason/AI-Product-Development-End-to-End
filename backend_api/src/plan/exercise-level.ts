import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DayContentDto, ExerciseContentDto, PlanContentDto } from './dto/plan-content.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { ExerciseTag } from './enums/exercise.enum.js';
import { WALK_EXERCISE } from './exercise-presets.js';
import { exerciseCandidates, exerciseLevel, type ExerciseLevel, toPlanExercise } from './swap-pools.js';
import { normalizeKey } from './text.util.js';

// Mức khó tối đa của động tác theo hồ sơ (BRD FR-2.2, v2.6.0; quyết định Q2 giai đoạn 6). Mức lấy từ
// `data/swap-exercises.json` (1 = nhẹ nhất). Chỉ hạ mức, không bao giờ tự nâng bài của người vận động nhiều.
export function maxExerciseLevel(
  profile: Pick<CreatePlanDto, 'age' | 'activity_level'> & { pregnant_or_breastfeeding?: boolean },
): ExerciseLevel {
  if (profile.pregnant_or_breastfeeding) return 1;
  if (profile.age >= 60 || (profile.age >= 45 && profile.activity_level === ActivityLevel.SEDENTARY)) return 1;
  if (profile.activity_level === ActivityLevel.ACTIVE && profile.age < 45) return 3;
  return 2;
}

// Động tác vượt mức cho phép. Động tác không có trong kho (Gemini tự đặt) không biết mức: chỉ coi là vượt khi
// giới hạn là 1 mà động tác có bật nhảy — mọi động tác mức 1 trong kho đều không bật nhảy.
export function exceedsLevel(exercise: ExerciseContentDto, maxLevel: ExerciseLevel): boolean {
  const level = exerciseLevel(exercise.name);
  if (level !== undefined) return level > maxLevel;
  return maxLevel === 1 && exercise.tags.includes(ExerciseTag.JUMPING);
}

// Thay động tác vượt mức bằng động tác trong kho cùng nhóm cơ, mức ≤ giới hạn, không vướng chấn thương,
// giữ số hiệp. Tất định (lấy ứng viên khó nhất còn hợp lệ) — dùng cho thực đơn mẫu và cả kết quả Gemini.
export function capWorkoutLevel(
  plan: PlanContentDto,
  maxLevel: ExerciseLevel,
  avoidTags: ExerciseTag[],
): PlanContentDto {
  const days = plan.days.map((day): DayContentDto => {
    const names = new Set(day.workout.exercises.map((exercise) => normalizeKey(exercise.name)));
    const exercises = day.workout.exercises.flatMap((exercise): ExerciseContentDto[] => {
      if (!exceedsLevel(exercise, maxLevel)) return [exercise];
      const [candidate] = exerciseCandidates(exercise.muscle_group, { avoidTags, excludeNames: names, maxLevel });
      if (!candidate) return [];
      names.add(normalizeKey(candidate.name));
      return [toPlanExercise(candidate, exercise.sets)];
    });
    return { ...day, workout: { ...day.workout, exercises: exercises.length > 0 ? exercises : [WALK_EXERCISE] } };
  });
  return { days };
}
