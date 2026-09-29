import type { PlanContentDto } from './dto/plan-content.dto.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
import { capWorkoutLevel, exceedsLevel, maxExerciseLevel } from './exercise-level.js';
import { buildSampleContent } from './plan.service.js';
import { matchRestrictions } from './restriction-matcher.js';
import { exerciseCandidates, exerciseLevel } from './swap-pools.js';

const levels = (plan: PlanContentDto) =>
  plan.days.flatMap((day) => day.workout.exercises.map((exercise) => exerciseLevel(exercise.name)));
const target = { bmi: 22, bmr: 1400, tdee: 1900, target_calories: 1900, protein_g: 119, carbs_g: 214, fat_g: 63 };
const restrictions = (injuries = '') => matchRestrictions({ allergies: '', injuries, health_conditions: '' });

describe('maxExerciseLevel (quyết định Q2 giai đoạn 6)', () => {
  it.each([
    [22, ActivityLevel.ACTIVE, false, 3],
    [44, ActivityLevel.ACTIVE, false, 3],
    [45, ActivityLevel.ACTIVE, false, 2],
    [22, ActivityLevel.LIGHT, false, 2],
    [22, ActivityLevel.SEDENTARY, false, 2],
    [44, ActivityLevel.SEDENTARY, false, 2],
    [45, ActivityLevel.SEDENTARY, false, 1],
    [59, ActivityLevel.LIGHT, false, 2],
    [60, ActivityLevel.ACTIVE, false, 1],
    [30, ActivityLevel.ACTIVE, true, 1],
  ])('%i tuổi, %s, mang thai %s → mức %i', (age, activity_level, pregnant_or_breastfeeding, expected) => {
    expect(maxExerciseLevel({ age, activity_level, pregnant_or_breastfeeding })).toBe(expected);
  });
});

describe('capWorkoutLevel', () => {
  it('keeps the sample plan unchanged up to level 2 (it only has levels 1–2)', () => {
    const { plan } = buildSampleContent(target, restrictions(), 2);
    expect(buildSampleContent(target, restrictions(), 3).plan).toEqual(plan);
    expect(Math.max(...levels(plan).map((level) => level ?? 0))).toBe(2);
  });

  it('replaces every level-2 exercise with a level-1 one of the same muscle group, keeping the sets', () => {
    const before = buildSampleContent(target, restrictions(), 3).plan;
    const { plan } = buildSampleContent(target, restrictions(), 1);
    expect(levels(plan).every((level) => level === 1)).toBe(true);
    plan.days.forEach((day, d) =>
      day.workout.exercises.forEach((exercise, e) => {
        expect(exercise.muscle_group).toBe(before.days[d].workout.exercises[e].muscle_group);
        expect(exercise.sets).toBe(before.days[d].workout.exercises[e].sets);
      }),
    );
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain(ExerciseTag.JUMPING);
  });

  it('still avoids injury tags while lowering the level', () => {
    const { plan } = buildSampleContent(target, restrictions('Đau cổ tay'), 1);
    const tags = plan.days.flatMap((day) => day.workout.exercises.flatMap((exercise) => exercise.tags));
    expect(tags).not.toContain(ExerciseTag.WRIST_LOAD);
    expect(levels(plan).every((level) => level === 1)).toBe(true);
  });

  it('treats an unknown (Gemini) exercise as too hard only at level 1 with jumping', () => {
    const jump = { name: 'Nhảy bật cao tại chỗ', sets: 3, reps_or_duration: '20 lần', muscle_group: MuscleGroup.CARDIO, tags: [ExerciseTag.JUMPING] };
    const calm = { ...jump, name: 'Đứng thăng bằng một chân', muscle_group: MuscleGroup.CORE, tags: [] };
    expect(exceedsLevel(jump, 1)).toBe(true);
    expect(exceedsLevel(jump, 2)).toBe(false);
    expect(exceedsLevel(calm, 1)).toBe(false);

    const plan = { days: [{ meals: [], workout: { title: 'Thử', duration_minutes: 20, exercises: [jump, calm] } }] };
    const capped = capWorkoutLevel(plan, 1, []);
    const [first, second] = capped.days[0].workout.exercises;
    expect(first.muscle_group).toBe(MuscleGroup.CARDIO);
    expect(exerciseLevel(first.name)).toBe(1);
    expect(second).toEqual(calm);
  });

  it('never lowers the level into an exercise that loads a declared injury', () => {
    // Cơ lõi mức 1: Dead bug, Gập bụng chạm gót đã có trong buổi → ứng viên còn lại là Bird-dog (quỳ gối, chống tay).
    const exercise = (name: string) => ({ name, sets: 3, reps_or_duration: '30 giây', muscle_group: MuscleGroup.CORE, tags: [] });
    const plan = {
      days: [{ meals: [], workout: { title: 'Cơ lõi', duration_minutes: 20, exercises: ['Plank cẳng tay', 'Dead bug', 'Gập bụng chạm gót'].map(exercise) } }],
    };
    const names = capWorkoutLevel(plan, 1, [ExerciseTag.KNEELING]).days[0].workout.exercises.map((e) => e.name);
    expect(names).toEqual(['Dead bug', 'Gập bụng chạm gót']);
  });

  // Nhờ vậy hạ mức không bao giờ làm rỗng buổi tập, kể cả khi tránh mọi kiểu tải (#25).
  it.each(Object.values(MuscleGroup))('pool has a tag-free level-1 exercise for %s', (group) => {
    expect(exerciseCandidates(group, { avoidTags: Object.values(ExerciseTag), excludeNames: new Set(), maxLevel: 1 })).not.toEqual([]);
  });
});
