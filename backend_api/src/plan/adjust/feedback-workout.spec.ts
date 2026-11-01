import { safeFeedbackWorkout } from './feedback-workout.js';
import { makeProfile } from '../../../test/plan-fixtures.js';
import { verifiedExercise } from '../exercise-verification.js';
import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
import { REST_WORKOUT } from '../exercise-presets.js';
import { workload } from './exercise-swap-validation.js';
import { matchRestrictions } from '../restriction-matcher.js';

describe('feedback final workout boundary', () => {
  const bird = () => ({ ...verifiedExercise('Bird-dog')! });
  it('uses reviewed tags and caps workload even when client metadata lies', () => {
    const exercise = {
      ...bird(),
      tags: [],
      sets: 6,
      reps_or_duration: '999 lần',
    };
    const result = safeFeedbackWorkout(
      { title: 'Test', duration_minutes: 20, exercises: [exercise] },
      makeProfile(),
      [],
    ).exercises[0];
    expect(result.tags).toEqual(bird().tags);
    expect(result.sets).toBeLessThanOrEqual(bird().sets);
    expect(workload(result.reps_or_duration)!.max).toBeLessThanOrEqual(
      workload(bird().reps_or_duration)!.max,
    );
  });
  it('cannot hide wrist/knee restrictions behind empty tags', () => {
    const profile = makeProfile({}, { injuries: 'Đau cổ tay, đau gối' }),
      avoid = matchRestrictions(profile.restrictions).avoidTags;
    expect(avoid).toContain(ExerciseTag.WRIST_LOAD);
    const result = safeFeedbackWorkout(
      {
        title: 'Test',
        duration_minutes: 20,
        exercises: [{ ...bird(), tags: [] }],
      },
      profile,
      avoid,
    );
    expect(
      result.exercises.flatMap((e) => e.tags).some((t) => avoid.includes(t)),
    ).toBe(false);
  });
  it('replaces unknown client exercises with reviewed low-level movements', () => {
    const result = safeFeedbackWorkout(
      {
        title: 'Test',
        duration_minutes: 20,
        exercises: [
          {
            name: 'AI exercise without assessment',
            sets: 1,
            reps_or_duration: '8 lần',
            muscle_group: MuscleGroup.LEGS,
            tags: [],
          },
        ],
      },
      makeProfile(),
      [],
    );
    expect(result.exercises[0].name).not.toBe('AI exercise without assessment');
    expect(verifiedExercise(result.exercises[0].name)?.level).toBe(1);
    expect(result.exercises[0].sets).toBe(1);
  });
  it('keeps the reviewed danger rest prescription and ignores client modifications', () => {
    const result = safeFeedbackWorkout(
      {
        ...REST_WORKOUT,
        exercises: REST_WORKOUT.exercises.map((e) => ({
          ...e,
          sets: 6,
          reps_or_duration: '999 lần',
        })),
      },
      makeProfile(),
      [],
    );
    expect(result).toEqual(REST_WORKOUT);
  });
});
