import type { WorkoutContentDto } from '../dto/plan-content.dto.js';
import { ExerciseTag, MuscleGroup } from '../enums/exercise.enum.js';
import { BodyState, Eating, Intensity } from '../enums/feedback.enum.js';
import { REST_WORKOUT, STRETCH_EXERCISE, WALK_EXERCISE } from '../exercise-presets.js';
import { adjustWorkout, describeFeedback, normalizeFeedback } from './workout-rules.js';

const workout = (): WorkoutContentDto => ({
  title: 'Chân và cơ lõi',
  duration_minutes: 20,
  exercises: [
    { name: 'Jumping Jacks (khởi động)', sets: 2, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CARDIO, tags: [ExerciseTag.JUMPING] },
    { name: 'Squat tay không', sets: 3, reps_or_duration: '12-15 lần', muscle_group: MuscleGroup.LEGS, tags: [] },
    { name: 'Chống đẩy khuỵu gối', sets: 3, reps_or_duration: '10-12 lần', muscle_group: MuscleGroup.CHEST, tags: [ExerciseTag.KNEELING, ExerciseTag.WRIST_LOAD] },
    { name: 'Plank cẳng tay', sets: 6, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CORE, tags: [] },
  ],
});
const feedback = (intensity: Intensity, body_states: BodyState[], eating = Eating.ON_PLAN) =>
  normalizeFeedback({ intensity, body_states, eating });
const sets = (w: WorkoutContentDto) => w.exercises.map((exercise) => exercise.sets);
const NONE = new Set<MuscleGroup>();

describe('normalizeFeedback', () => {
  it('drops duplicates and ignores "normal" next to another state (BRD 6.4)', () => {
    expect([...normalizeFeedback({ intensity: Intensity.EASY, body_states: [BodyState.NORMAL, BodyState.SORE, BodyState.SORE], eating: Eating.ON_PLAN }).states])
      .toEqual([BodyState.SORE]);
    expect([...normalizeFeedback({ intensity: Intensity.EASY, body_states: [BodyState.NORMAL], eating: Eating.ON_PLAN }).states])
      .toEqual([BodyState.NORMAL]);
  });
});

describe('adjustWorkout — danger sign (#14, BRD FR-5.2)', () => {
  it('replaces the whole next workout with rest or a light walk', () => {
    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.DANGER_SIGN]), NONE, [])).toEqual(REST_WORKOUT);
  });

  it('overrides every other answer, including "easy" and other states', () => {
    const adjusted = adjustWorkout(
      workout(),
      feedback(Intensity.EASY, [BodyState.DANGER_SIGN, BodyState.SORE, BodyState.JOINT_PAIN, BodyState.NORMAL]),
      new Set([MuscleGroup.LEGS]),
      [],
    );
    expect(adjusted).toEqual(REST_WORKOUT);
  });

  it('returns a copy, so later edits cannot change the preset', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.DANGER_SIGN]), NONE, []);
    adjusted.exercises[0].sets = 5;
    expect(REST_WORKOUT.exercises[0].sets).toBe(1);
  });
});

describe('adjustWorkout — regular rules (BRD FR-5.2)', () => {
  it('keeps the workout for a moderate session with a normal body', () => {
    expect(adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, [])).toEqual(workout());
  });

  it('adds one set after an easy session, capped at 6', () => {
    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.NORMAL]), NONE, []))).toEqual([3, 4, 4, 6]);
  });

  it('does not add sets after an easy session when the body is not fine', () => {
    expect(sets(adjustWorkout(workout(), feedback(Intensity.EASY, [BodyState.FATIGUED]), NONE, []))).toEqual([1, 2, 2, 5]);
  });

  it.each([
    ['a hard session', feedback(Intensity.HARD, [BodyState.NORMAL])],
    ['fatigue', feedback(Intensity.MODERATE, [BodyState.FATIGUED])],
  ])('removes one set (at least 1 left) and shortens the session after %s', (_label, input) => {
    const adjusted = adjustWorkout(workout(), input, NONE, []);
    expect(sets(adjusted)).toEqual([1, 2, 2, 5]);
    expect(adjusted.duration_minutes).toBe(15);
  });

  it('eases muscle groups trained that day and adds a stretch when sore', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
    expect(sets(adjusted)).toEqual([2, 2, 3, 6, 1]);
    expect(adjusted.exercises.at(-1)?.name).toBe(STRETCH_EXERCISE.name);
  });

  it('does not stack the sore reduction on top of the tired one', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.HARD, [BodyState.SORE]), new Set([MuscleGroup.LEGS]), []);
    expect(sets(adjusted)).toEqual([1, 2, 2, 5, 1]);
  });

  it('replaces jumping and kneeling exercises on joint pain, respecting declared injuries', () => {
    const adjusted = adjustWorkout(workout(), feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.WRIST_LOAD]);
    const tags = adjusted.exercises.flatMap((exercise) => exercise.tags);
    expect(tags).not.toContain(ExerciseTag.JUMPING);
    expect(tags).not.toContain(ExerciseTag.KNEELING);
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(adjusted.exercises.map((exercise) => exercise.muscle_group)).toEqual([
      MuscleGroup.CARDIO,
      MuscleGroup.LEGS,
      MuscleGroup.CHEST,
      MuscleGroup.CORE,
    ]);
  });

  it('falls back to a walk when nothing is left', () => {
    const only: WorkoutContentDto = { ...workout(), exercises: [{ ...workout().exercises[0], name: 'Bật nhảy lạ', muscle_group: MuscleGroup.SHOULDERS, tags: [ExerciseTag.JUMPING] }] };
    const adjusted = adjustWorkout(only, feedback(Intensity.MODERATE, [BodyState.JOINT_PAIN]), NONE, [ExerciseTag.OVERHEAD, ExerciseTag.WRIST_LOAD]);
    expect(adjusted.exercises.length).toBeGreaterThan(0);
    expect(adjusted.exercises.every((exercise) => !exercise.tags.includes(ExerciseTag.JUMPING))).toBe(true);
    const empty = adjustWorkout({ ...workout(), exercises: [] }, feedback(Intensity.MODERATE, [BodyState.NORMAL]), NONE, []);
    expect(empty.exercises).toEqual([WALK_EXERCISE]);
  });

  it('never goes past 8 exercises when adding the stretch', () => {
    const full: WorkoutContentDto = {
      ...workout(),
      exercises: Array.from({ length: 8 }, (_, i) => ({ ...workout().exercises[1], name: `Động tác ${i}` })),
    };
    expect(adjustWorkout(full, feedback(Intensity.MODERATE, [BodyState.SORE]), NONE, []).exercises).toHaveLength(8);
  });
});

describe('describeFeedback', () => {
  it('builds the note only from fixed labels', () => {
    expect(describeFeedback(feedback(Intensity.HARD, [BodyState.SORE, BodyState.JOINT_PAIN], Eating.OVER))).toBe(
      'buổi tập rất mệt; căng mỏi cơ; đau khớp; ăn nhiều hơn thực đơn',
    );
  });
});
