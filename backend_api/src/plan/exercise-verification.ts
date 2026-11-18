import { SWAP_EXERCISES } from './swap-pools.js';
import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
export const exerciseKey = (text: string) =>
  text
    .normalize('NFKC')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/đ/g, 'd')
    .replace(/[‐‑‒–—−]/g, '-')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
// Exact reviewed aliases only; no arbitrary substring or model-declared ID.
const aliases: Record<string, string> = {
  'wall push up': 'Chống đẩy tường',
  'day tuong wall push up': 'Chống đẩy tường',
  'chong day tuong wall push up': 'Chống đẩy tường',
  'plank khuyu tay': 'Plank cẳng tay',
  'forearm plank': 'Plank cẳng tay',
  'elbow plank': 'Plank cẳng tay',
  'bird dog tren san': 'Bird-dog',
  'marching tren cho': 'Đi bộ tại chỗ',
  'marching tai cho': 'Đi bộ tại chỗ',
};
export function verifiedExercise(name: string) {
  const key = exerciseKey(name),
    canonical = aliases[key];
  return SWAP_EXERCISES.find(
    (e) => exerciseKey(e.name) === key || e.name === canonical,
  );
}
export function positiveLoadText(text: string) {
  return exerciseKey(text).replace(
    /\b(?:khong|tranh|khong duoc|khong can|do not|without|no)\s+(?:bat\s+)?(?:nhay|jumping|jump|quy|kneeling)\b/g,
    '',
  );
}
export function inferredLoads(text: string): ExerciseTag[] {
  const positive = positiveLoadText(text);
  const rules: [RegExp, ExerciseTag][] = [
    [/\b(nhay|jump|jumping|hopping|plyometric|burpee)\b/, ExerciseTag.JUMPING],
    [/\b(quy|kneeling)\b/, ExerciseTag.KNEELING],
    [/\b(chong day|chong tay|push up|bird dog)\b/, ExerciseTag.WRIST_LOAD],
    [/\b(qua dau|overhead)\b/, ExerciseTag.OVERHEAD],
  ];
  if (
    /\bplank\b/.test(positive) &&
    !/\b(khuyu tay|cang tay|forearm|elbow)\b/.test(positive)
  )
    rules.push([/\bplank\b/, ExerciseTag.WRIST_LOAD]);
  return rules
    .filter(([pattern]) => pattern.test(positive))
    .map(([, tag]) => tag);
}
export function metadataOf(raw: Record<string, unknown>) {
  const a =
    raw.assessment &&
    typeof raw.assessment === 'object' &&
    !Array.isArray(raw.assessment)
      ? (raw.assessment as Record<string, unknown>)
      : {};
  const number = (v: unknown) =>
    typeof v === 'number' && Number.isFinite(v) && Math.abs(v) < 10000
      ? v
      : 'INVALID';
  const tags = Array.isArray(raw.tags) ? raw.tags : [];
  const reps =
    typeof raw.reps_or_duration === 'string' ? raw.reps_or_duration : '';
  const values = reps.match(/\d+/g)?.map(Number) ?? [];
  const max = values.length ? Math.max(...values) : NaN;
  const unit = /\b(?:phút|minutes?)\b/iu.test(reps)
    ? 'minutes'
    : /giây|seconds?/iu.test(reps)
      ? 'seconds'
      : /lần|reps?/iu.test(reps)
        ? 'reps'
        : 'INVALID';
  return {
    muscle_group: Object.values(MuscleGroup).includes(
      raw.muscle_group as MuscleGroup,
    )
      ? raw.muscle_group
      : 'INVALID',
    tags: tags.filter((v): v is ExerciseTag =>
      Object.values(ExerciseTag).includes(v as ExerciseTag),
    ),
    tags_valid:
      Array.isArray(raw.tags) &&
      tags.every((v) => Object.values(ExerciseTag).includes(v as ExerciseTag)),
    difficulty_level: number(a.difficulty_level),
    equipment: a.equipment === 'none' ? 'none' : 'INVALID',
    impact: ['low', 'moderate', 'high'].includes(String(a.impact))
      ? a.impact
      : 'INVALID',
    sets: number(raw.sets),
    workload_max: number(max * (unit === 'minutes' ? 60 : 1)),
    workload_unit: unit === 'minutes' ? 'seconds' : unit,
  };
}
export interface ExerciseDiagnostic {
  error_code: string;
  day_index: number;
  exercise_index: number;
  violated_rule: string;
  expected: Record<string, unknown>;
  actual: ReturnType<typeof metadataOf>;
  action: 'repaired' | 'replaced' | 'rejected' | 'assessed';
}
export class ExerciseValidationError extends Error {
  day_index = -1;
  exercise_index = -1;
  constructor(
    readonly error_code: string,
    readonly violated_rule: string,
    readonly expected: Record<string, unknown>,
    readonly actual: ReturnType<typeof metadataOf>,
  ) {
    super(error_code);
  }
  diagnostic(
    action: ExerciseDiagnostic['action'] = 'rejected',
  ): ExerciseDiagnostic {
    return {
      error_code: this.error_code,
      day_index: this.day_index,
      exercise_index: this.exercise_index,
      violated_rule: this.violated_rule,
      expected: this.expected,
      actual: this.actual,
      action,
    };
  }
}
