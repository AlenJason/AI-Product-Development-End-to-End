import type { ExerciseContentDto, WorkoutContentDto } from '../dto/plan-content.dto.js';
import { ExerciseTag, type MuscleGroup } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
import { exerciseCandidates, exerciseLevel, toPlanExercise } from '../swap-pools.js';
import { normalizeKey } from '../text.util.js';

// Quy tắc cố định cho buổi tập ngày kế tiếp sau feedback (BRD FR-5.2, D2) — không cần Gemini.

export const MAX_SETS = 6;
export const MAX_EXERCISES = 8;
const MIN_DURATION_MINUTES = 10;
const TIRED_DURATION_FACTOR = 0.75;
// Đau khớp → bỏ bật nhảy và chống quỳ (BRD FR-5.2).
const JOINT_PAIN_TAGS = [ExerciseTag.JUMPING, ExerciseTag.KNEELING];

export interface NormalizedFeedback {
  intensity: Intensity;
  states: Set<BodyState>;
  eating: Eating;
}

// Bỏ trùng; `normal` đi cùng trạng thái khác thì bị bỏ qua (BRD 6.4).
export function normalizeFeedback(input: { intensity: Intensity; body_states: BodyState[]; eating: Eating }): NormalizedFeedback {
  const states = new Set(input.body_states);
  if (states.size > 1) states.delete(BodyState.NORMAL);
  return { intensity: input.intensity, states, eating: input.eating };
}

export function hasDangerSign(feedback: NormalizedFeedback): boolean {
  return feedback.states.has(BodyState.DANGER_SIGN);
}

// Thứ tự ưu tiên: dấu hiệu nguy hiểm (thay cả buổi, bỏ qua mọi quy tắc khác — #14) → đau khớp → rất mệt/uể oải
// → căng mỏi cơ → nhẹ nhàng. Giảm không cộng dồn: một động tác giảm tối đa 1 hiệp.
export function adjustWorkout(
  workout: WorkoutContentDto,
  feedback: NormalizedFeedback,
  trainedMuscles: Set<MuscleGroup>,
  profileAvoidTags: ExerciseTag[],
): WorkoutContentDto {
  if (hasDangerSign(feedback)) return structuredClone(REST_WORKOUT);

  let exercises = workout.exercises.map((exercise) => ({ ...exercise, tags: [...exercise.tags] }));
  let durationMinutes = workout.duration_minutes;

  if (feedback.states.has(BodyState.JOINT_PAIN)) {
    exercises = replaceJointLoading(exercises, profileAvoidTags);
  }

  const tired = feedback.intensity === Intensity.HARD || feedback.states.has(BodyState.FATIGUED);
  if (tired) {
    exercises = exercises.map((exercise) => ({ ...exercise, sets: Math.max(1, exercise.sets - 1) }));
    durationMinutes = Math.max(MIN_DURATION_MINUTES, Math.round(durationMinutes * TIRED_DURATION_FACTOR));
  }

  if (feedback.states.has(BodyState.SORE)) {
    if (!tired) {
      exercises = exercises.map((exercise) =>
        trainedMuscles.has(exercise.muscle_group) ? { ...exercise, sets: Math.max(1, exercise.sets - 1) } : exercise,
      );
    }
    const hasStretch = exercises.some((exercise) => normalizeKey(exercise.name) === normalizeKey(STRETCH_EXERCISE.name));
    if (!hasStretch && exercises.length < MAX_EXERCISES) exercises.push({ ...STRETCH_EXERCISE, tags: [] });
  }

  const allNormal = [...feedback.states].every((state) => state === BodyState.NORMAL);
  if (feedback.intensity === Intensity.EASY && allNormal) {
    exercises = exercises.map((exercise) => ({ ...exercise, sets: Math.min(MAX_SETS, exercise.sets + 1) }));
  }

  if (exercises.length === 0) exercises = [{ ...WALK_EXERCISE, tags: [] }];
  return { ...workout, duration_minutes: durationMinutes, exercises };
}

function replaceJointLoading(exercises: ExerciseContentDto[], profileAvoidTags: ExerciseTag[]): ExerciseContentDto[] {
  const names = new Set(exercises.map((exercise) => normalizeKey(exercise.name)));
  return exercises.flatMap((exercise): ExerciseContentDto[] => {
    if (!exercise.tags.some((tag) => JOINT_PAIN_TAGS.includes(tag))) return [exercise];
    const [candidate] = exerciseCandidates(exercise.muscle_group, {
      avoidTags: [...JOINT_PAIN_TAGS, ...profileAvoidTags],
      excludeNames: names,
      maxLevel: exerciseLevel(exercise.name) ?? 3,
    });
    if (!candidate) return [];
    names.add(normalizeKey(candidate.name));
    return [toPlanExercise(candidate, exercise.sets)];
  });
}

const INTENSITY_NOTE: Record<Intensity, string> = {
  [Intensity.EASY]: 'buổi tập nhẹ nhàng',
  [Intensity.MODERATE]: 'buổi tập vừa sức',
  [Intensity.HARD]: 'buổi tập rất mệt',
};
const STATE_NOTE: Record<BodyState, string> = {
  [BodyState.NORMAL]: 'cơ thể bình thường',
  [BodyState.SORE]: 'căng mỏi cơ',
  [BodyState.JOINT_PAIN]: 'đau khớp',
  [BodyState.FATIGUED]: 'uể oải, thiếu ngủ',
  [BodyState.DANGER_SIGN]: 'có dấu hiệu chóng mặt, khó thở hoặc đau ngực',
};
const EATING_NOTE: Record<Eating, string> = {
  [Eating.ON_PLAN]: 'ăn đúng thực đơn',
  [Eating.OVER]: 'ăn nhiều hơn thực đơn',
  [Eating.UNDER]: 'ăn ít hơn thực đơn hoặc bỏ bữa',
};

// Câu tóm tắt feedback cho prompt tạo plan mới (FR-5.3). Chỉ dựng từ mã cố định, không có chữ người dùng nhập.
export function describeFeedback(feedback: NormalizedFeedback): string {
  return [INTENSITY_NOTE[feedback.intensity], ...[...feedback.states].map((state) => STATE_NOTE[state]), EATING_NOTE[feedback.eating]].join('; ');
}
