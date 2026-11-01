import type { CreatePlanDto } from '../dto/create-plan.dto.js';
import type { WorkoutContentDto } from '../dto/plan-content.dto.js';
import type { ExerciseTag } from '../enums/exercise.enum.js';
import { assessedExercise } from '../ai-exercise.js';
import { verifiedExercise } from '../exercise-verification.js';
import {
  REST_WORKOUT,
  STRETCH_EXERCISE,
  WALK_EXERCISE,
} from '../exercise-presets.js';
import { exerciseCandidates, toPlanExercise } from '../swap-pools.js';
import { capSwapWorkload } from './exercise-swap-validation.js';
import { normalizeKey } from '../text.util.js';

// The public contract intentionally omits provider assessments. A client-sent
// unknown name cannot supply trusted difficulty/equipment at the feedback boundary.
// Replacements and increased sets therefore use reviewed metadata and caps.
export function safeFeedbackWorkout(
  workout: WorkoutContentDto,
  profile: CreatePlanDto,
  avoid: ExerciseTag[],
): WorkoutContentDto {
  const names = new Set<string>();
  const exercises = workout.exercises.flatMap((exercise) => {
    const preset = [
      STRETCH_EXERCISE,
      WALK_EXERCISE,
      ...REST_WORKOUT.exercises,
    ].find((e) => e.name === exercise.name);
    if (preset) return [structuredClone(preset)];
    const known = verifiedExercise(exercise.name);
    if (known) {
      const capped = capSwapWorkload(
        { ...exercise, sets: Math.min(exercise.sets, known.sets) },
        known,
      );
      try {
        const checked = assessedExercise(capped, profile)
          .value as typeof exercise;
        if (!checked.tags.some((t) => avoid.includes(t))) {
          names.add(normalizeKey(checked.name));
          return [checked];
        }
      } catch {
        /* Choose a reviewed, eligible replacement below. */
      }
    }
    const [candidate] = exerciseCandidates(exercise.muscle_group, {
      avoidTags: avoid,
      excludeNames: names,
      maxLevel: 1,
    }).filter(
      (e) =>
        !/ghe|chai nuoc/.test(
          e.name.normalize('NFD').replace(/[\u0300-\u036f]/g, ''),
        ),
    );
    if (!candidate) return [];
    names.add(normalizeKey(candidate.name));
    return [
      capSwapWorkload(
        toPlanExercise(candidate, Math.min(exercise.sets, candidate.sets)),
        exercise,
      ),
    ];
  });
  return {
    ...workout,
    exercises: exercises.length
      ? exercises
      : structuredClone(REST_WORKOUT.exercises),
  };
}
