import type { ExerciseContentDto } from '../dto/plan-content.dto.js';
import type { CreatePlanDto } from '../dto/create-plan.dto.js';
import { maxExerciseLevel } from '../exercise-level.js';
import { exerciseLevel } from '../swap-pools.js';
import { verifiedExercise } from '../exercise-verification.js';

// Known names use reviewed metadata. Outside-pool names require provider-only
// assessment checked before this boundary, plus the same workload checks.
export function swapExerciseProblems(
  candidate: ExerciseContentDto,
  original: ExerciseContentDto,
  profile: CreatePlanDto,
  assessedLevel?: number,
): string[] {
  const known = verifiedExercise(candidate.name);
  if (!known && assessedLevel === undefined)
    return ['EXERCISE_UNVERIFIED_LEVEL_OR_EQUIPMENT'];
  // Public plans do not persist AI assessments. Do not assume an unknown
  // original was hard enough to permit a more difficult replacement.
  const beforeLevel = exerciseLevel(original.name) ?? 1;
  const errors: string[] = [];
  const level = known?.level ?? assessedLevel!;
  if (
    (known ? level >= beforeLevel : level > beforeLevel) ||
    level > maxExerciseLevel(profile)
  )
    errors.push('EXERCISE_NOT_LIGHTER');
  if (
    known &&
    (known.muscle_group !== candidate.muscle_group ||
      known.tags.some((tag) => !candidate.tags.includes(tag)))
  )
    errors.push('EXERCISE_METADATA_CONFLICT');
  const before = workload(original.reps_or_duration),
    after = workload(candidate.reps_or_duration);
  if (!before || !after || before.unit !== after.unit || after.max > before.max)
    errors.push('EXERCISE_WORKLOAD_UNVERIFIED_OR_HIGHER');
  if (
    !known &&
    level === beforeLevel &&
    candidate.sets >= original.sets &&
    (!before || !after || after.max >= before.max)
  )
    errors.push('EXERCISE_NOT_LIGHTER');
  return errors;
}

export function workload(
  text: string,
): { unit: 'reps' | 'seconds'; max: number } | null {
  const match =
    /^(\d+)(?:\s*[-–]\s*(\d+))?\s*(lần|reps?|giây|phút|seconds?|minutes?)(?:\s+(?:mỗi|moi)\s+(?:bên|ben|chân|chan|tay|chiều|chieu))?$/iu.exec(
      text.trim(),
    );
  if (!match) return null;
  const min = Number(match[1]),
    max = Number(match[2] ?? match[1]);
  if (min <= 0 || max < min) return null;
  const unit = /lần|reps?/iu.test(match[3]) ? 'reps' : 'seconds';
  return { unit, max: max * (/phút|minutes?/iu.test(match[3]) ? 60 : 1) };
}

export function capSwapWorkload(
  candidate: ExerciseContentDto,
  original: ExerciseContentDto,
): ExerciseContentDto {
  const before = workload(original.reps_or_duration),
    after = workload(candidate.reps_or_duration);
  if (before && after && before.unit === after.unit && after.max > before.max) {
    return {
      ...candidate,
      reps_or_duration: `${before.max} ${before.unit === 'reps' ? 'lần' : 'giây'}`,
    };
  }
  return candidate;
}
