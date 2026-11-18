import type { WorkoutContentDto } from '../dto/plan-content.dto.js';
import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import {
  REST_WORKOUT,
  STRETCH_EXERCISE,
  WALK_EXERCISE,
} from '../exercise-presets.js';
import {
  adjustWorkout,
  describeFeedback,
  normalizeFeedback,
} from './workout-rules.js';

const workout = (): WorkoutContentDto => ({
  title: 'Chân và cơ lõi',
  duration_minutes: 20,
  exercises: [
    {
      name: 'Jumping Jacks (khởi động)',
      sets: 2,
      reps_or_duration: '30 giây',
      muscle_group: MuscleGroup.CARDIO,
      tags: [ExerciseTag.JUMPING],
    },
    {
      name: 'Squat tay không',
      sets: 3,
      reps_or_duration: '12-15 lần',
      muscle_group: MuscleGroup.LEGS,
      tags: [],
    },
    {
      name: 'Chống đẩy khuỵu gối',
      sets: 3,
      reps_or_duration: '10-12 lần',
      muscle_group: MuscleGroup.CHEST,
      tags: [ExerciseTag.KNEELING, ExerciseTag.WRIST_LOAD],
    },
    {
      name: 'Plank cẳng tay',
      sets: 6,
      reps_or_duration: '30 giây',
      muscle_group: MuscleGroup.CORE,
      tags: [],
    },
  ],
});
const feedback = (
  intensity: Intensity,
  body_states: BodyState[],
  eating = Eating.ON_PLAN,
) => normalizeFeedback({ intensity, body_states, eating });
const sets = (value: WorkoutContentDto) =>
  value.exercises.map((exercise) => exercise.sets);
const NONE = new Set<MuscleGroup>();

describe('normalizeFeedback', () => {
  it('removes duplicate states and ignores normal beside another state', () => {
    expect([
      ...normalizeFeedback({
        intensity: Intensity.EASY,
        body_states: [BodyState.NORMAL, BodyState.SORE, BodyState.SORE],
        eating: Eating.ON_PLAN,
      }).states,
    ]).toEqual([BodyState.SORE]);
    expect([
      ...normalizeFeedback({
        intensity: Intensity.EASY,
        body_states: [BodyState.NORMAL],
        eating: Eating.ON_PLAN,
      }).states,
    ]).toEqual([BodyState.NORMAL]);
  });
});

describe('adjustWorkout — danger sign (#14)', () => {
  it('replaces the workout with rest and ignores other feedback', () => {
    expect(
      adjustWorkout(
        workout(),
        feedback(Intensity.EASY, [BodyState.DANGER_SIGN, BodyState.SORE]),
        new Set([MuscleGroup.LEGS]),
        [],
      ),
    ).toEqual(REST_WORKOUT);
  });

  it('returns an independent copy of the rest preset', () => {
    const adjusted = adjustWorkout(
      workout(),
      feedback(Intensity.HARD, [BodyState.DANGER_SIGN]),
      NONE,
      [],
    );
    adjusted.exercises[0].sets = 5;
    expect(REST_WORKOUT.exercises[0].sets).toBe(1);
  });

  it('does not leave any existing meal/workout exercise in the replacement', () => {
    expect(
      adjustWorkout(
        workout(),
        feedback(Intensity.MODERATE, [BodyState.DANGER_SIGN]),
        NONE,
        [],
      ).exercises,
    ).toMatchObject(REST_WORKOUT.exercises);
  });
});

describe('adjustWorkout — regular rules', () => {
  it('keeps a moderate workout unchanged for a normal body', () => {
    expect(
      adjustWorkout(
        workout(),
        feedback(Intensity.MODERATE, [BodyState.NORMAL]),
        NONE,
        [],
      ),
    ).toEqual(workout());
  });

  it('adds one set after an easy session, capped at six', () => {
    expect(
      sets(
        adjustWorkout(
          workout(),
          feedback(Intensity.EASY, [BodyState.NORMAL]),
          NONE,
          [],
        ),
      ),
    ).toEqual([3, 4, 4, 6]);
  });

  it('does not add sets after an easy session when another body state is reported', () => {
    expect(
      sets(
        adjustWorkout(
          workout(),
          feedback(Intensity.EASY, [BodyState.FATIGUED]),
          NONE,
          [],
        ),
      ),
    ).toEqual([1, 2, 2, 5]);
  });

  it.each([
    ['a hard session', feedback(Intensity.HARD, [BodyState.NORMAL])],
    ['fatigue', feedback(Intensity.MODERATE, [BodyState.FATIGUED])],
  ])('removes one set and shortens the session after %s', (_label, input) => {
    const adjusted = adjustWorkout(workout(), input, NONE, []);
    expect(sets(adjusted)).toEqual([1, 2, 2, 5]);
    expect(adjusted.duration_minutes).toBe(15);
  });

  it('reduces trained muscles after soreness and adds a stretch', () => {
    const adjusted = adjustWorkout(
      workout(),
      feedback(Intensity.MODERATE, [BodyState.SORE]),
      new Set([MuscleGroup.LEGS]),
      [],
    );
    expect(sets(adjusted)).toEqual([2, 2, 3, 6, 1]);
    expect(adjusted.exercises.at(-1)?.name).toBe(STRETCH_EXERCISE.name);
  });

  it('does not stack soreness reduction on top of the tired reduction', () => {
    expect(
      sets(
        adjustWorkout(
          workout(),
          feedback(Intensity.HARD, [BodyState.SORE]),
          new Set([MuscleGroup.LEGS]),
          [],
        ),
      ),
    ).toEqual([1, 2, 2, 5, 1]);
  });

  it('replaces exercises that load a painful joint while respecting profile injuries', () => {
    const adjusted = adjustWorkout(
      workout(),
      feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]),
      NONE,
      [ExerciseTag.WRIST_LOAD],
    );
    const tags = adjusted.exercises.flatMap((exercise) => exercise.tags);
    expect(tags).not.toContain(ExerciseTag.JUMPING);
    expect(tags).not.toContain(ExerciseTag.KNEELING);
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(adjusted.exercises.map((exercise) => exercise.muscle_group)).toEqual(
      [
        MuscleGroup.CARDIO,
        MuscleGroup.LEGS,
        MuscleGroup.CHEST,
        MuscleGroup.CORE,
      ],
    );
  });

  it('falls back to a light walk when all exercises are removed', () => {
    const only: WorkoutContentDto = {
      ...workout(),
      exercises: [
        {
          ...workout().exercises[0],
          name: 'Bật nhảy lạ',
          muscle_group: MuscleGroup.SHOULDERS,
          tags: [ExerciseTag.JUMPING],
        },
      ],
    };
    const filtered = adjustWorkout(
      only,
      feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]),
      NONE,
      [ExerciseTag.OVERHEAD, ExerciseTag.WRIST_LOAD],
    );
    expect(filtered.exercises.length).toBeGreaterThan(0);
    expect(
      filtered.exercises.every(
        (exercise) => !exercise.tags.includes(ExerciseTag.JUMPING),
      ),
    ).toBe(true);

    const empty = adjustWorkout(
      { ...workout(), exercises: [] },
      feedback(Intensity.MODERATE, [BodyState.NORMAL]),
      NONE,
      [],
    );
    expect(empty.exercises).toEqual([{ ...WALK_EXERCISE, tags: [] }]);
  });

  it('does not add more than eight exercises when adding a stretch', () => {
    const full: WorkoutContentDto = {
      ...workout(),
      exercises: Array.from({ length: 8 }, (_, index) => ({
        ...workout().exercises[1],
        name: `Động tác ${index}`,
      })),
    };
    expect(
      adjustWorkout(
        full,
        feedback(Intensity.MODERATE, [BodyState.SORE]),
        NONE,
        [],
      ).exercises,
    ).toHaveLength(8);
  });

  it('never shortens a session below ten minutes', () => {
    expect(
      adjustWorkout(
        { ...workout(), duration_minutes: 5 },
        feedback(Intensity.HARD, [BodyState.NORMAL]),
        NONE,
        [],
      ).duration_minutes,
    ).toBe(10);
  });
});

describe('describeFeedback', () => {
  it('builds a summary only from fixed labels', () => {
    expect(
      describeFeedback(
        feedback(
          Intensity.HARD,
          [BodyState.SORE, BodyState.JOINT_PAIN],
          Eating.OVER,
        ),
      ),
    ).toBe('buổi tập rất mệt; căng mỏi cơ; đau khớp; ăn nhiều hơn thực đơn');
  });
});
