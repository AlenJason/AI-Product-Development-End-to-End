import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { energySplit, MACRO_ENERGY_SPLIT } from './daily-target.js';
import { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
import { MealType } from './enums/meal-type.enum.js';
import { scaleMealToCalories } from './meal-scaling.js';
import { MACRO_CALORIE_TOLERANCE } from './plan-validation.js';
import { impliedExerciseTags } from './restriction-matcher.js';
import { exerciseCandidates, exerciseLevel, mealCandidates, SWAP_EXERCISES, SWAP_MEALS } from './swap-pools.js';
import { normalizeKey } from './text.util.js';

const sample = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
) as {
  days: {
    meals: { name: string; protein_g: number; carbs_g: number; fat_g: number }[];
    workout: { exercises: { name: string }[] };
  }[];
};

// Mỗi món (kho và thực đơn mẫu) lệch mục tiêu 25/45/30 không quá 8 điểm phần trăm ở từng chất, để ngày có món
// được thay vẫn gần mục tiêu (BRD FR-1.5; trước đây xôi đậu xanh 78 % tinh bột).
const MAX_DISH_DEVIATION = 0.08;

describe('swap-meals.json', () => {
  it('has several dishes for every meal type', () => {
    for (const mealType of Object.values(MealType)) {
      expect(SWAP_MEALS.filter((meal) => meal.meal_type === mealType).length).toBeGreaterThanOrEqual(6);
    }
  });

  it('keeps calories consistent with macros, before and after scaling', () => {
    for (const meal of SWAP_MEALS) {
      for (const candidate of [meal, scaleMealToCalories(meal, 1000), scaleMealToCalories(meal, 200)]) {
        const macros = 4 * candidate.protein_g + 4 * candidate.carbs_g + 9 * candidate.fat_g;
        expect(Math.abs(macros - candidate.calories)).toBeLessThanOrEqual(candidate.calories * MACRO_CALORIE_TOLERANCE);
        expect(candidate.portion.length).toBeLessThanOrEqual(80);
      }
    }
  });

  it.each([...SWAP_MEALS, ...sample.days.flatMap((day) => day.meals)].map((meal) => [meal.name, meal] as const))(
    'keeps %s close to the 25/45/30 energy split',
    (_name, meal) => {
      const split = energySplit([meal]);
      for (const key of Object.keys(MACRO_ENERGY_SPLIT) as (keyof typeof MACRO_ENERGY_SPLIT)[]) {
        expect(Math.abs(split[key] - MACRO_ENERGY_SPLIT[key])).toBeLessThanOrEqual(MAX_DISH_DEVIATION);
      }
    },
  );

  it('shares no dish name with the sample plan', () => {
    const sampleNames = new Set(sample.days.flatMap((day) => day.meals.map((meal) => normalizeKey(meal.name))));
    expect(SWAP_MEALS.filter((meal) => sampleNames.has(normalizeKey(meal.name)))).toEqual([]);
  });

  it('filters candidates by meal type, allergens and names already in the plan', () => {
    const names = mealCandidates(MealType.LUNCH, { avoidIngredients: ['cá', 'tôm', 'mắm'], excludeNames: new Set(['bún chả']) })
      .map((meal) => meal.name);
    expect(names).toContain('Cơm gà xé phay, canh cải');
    expect(names).not.toContain('Bún chả');
    expect(names.some((name) => /cá|tôm/i.test(name))).toBe(false);
  });
});

describe('swap-exercises.json', () => {
  it('covers every muscle group, with a level-1 option for each', () => {
    for (const group of Object.values(MuscleGroup)) {
      expect(SWAP_EXERCISES.some((exercise) => exercise.muscle_group === group && exercise.level === 1)).toBe(true);
    }
  });

  // #34: tag ghi trong dữ liệu phải đủ — không dựa vào lớp suy từ tên để che dữ liệu thiếu.
  it('writes every tag the exercise name implies, in the pool and in the sample plan', () => {
    const exercises = [...SWAP_EXERCISES, ...sample.days.flatMap((day) => day.workout.exercises)] as { name: string; tags: string[] }[];
    const missing = exercises.filter((exercise) => impliedExerciseTags(exercise.name).some((tag) => !exercise.tags.includes(tag)));
    expect(missing.map((exercise) => exercise.name)).toEqual([]);
  });

  // PLAN D8: đau gối bỏ mọi động tác gập gối — nhóm chân vẫn còn ít nhất 3 động tác mức 1 để thay.
  it('keeps at least three level-1 leg exercises without knee bending', () => {
    const safe = exerciseCandidates(MuscleGroup.LEGS, { avoidTags: [ExerciseTag.KNEE_BEND], excludeNames: new Set(), maxLevel: 1 });
    expect(safe.length).toBeGreaterThanOrEqual(3);
  });

  it('knows the level of every exercise in the sample plan', () => {
    const unknown = sample.days
      .flatMap((day) => day.workout.exercises.map((exercise) => exercise.name))
      .filter((name) => exerciseLevel(name) === undefined);
    expect(unknown).toEqual([]);
  });

  it('returns lighter-or-equal candidates without avoided tags, closest level first', () => {
    const candidates = exerciseCandidates(MuscleGroup.LEGS, { avoidTags: [], excludeNames: new Set(['squat tay không']), maxLevel: 2 });
    const levels = candidates.map((exercise) => exercise.level);
    expect(levels).toEqual(levels.toSorted((a, b) => b - a));
    expect(candidates.every((exercise) => exercise.level <= 2)).toBe(true);
    expect(candidates.map((exercise) => exercise.name)).not.toContain('Squat tay không');
  });
});
