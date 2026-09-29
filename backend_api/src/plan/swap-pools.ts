import { plainToInstance } from 'class-transformer';
import { IsIn, validateSync } from 'class-validator';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ExerciseContentDto, MealContentDto } from './dto/plan-content.dto.js';
import type { ExerciseTag, MuscleGroup } from './enums/exercise.enum.js';
import type { MealType } from './enums/meal-type.enum.js';
import { findAvoidedIngredient, hasAvoidedTag } from './restriction-matcher.js';
import { normalizeKey } from './text.util.js';

// Kho món Việt và kho động tác soạn sẵn: nguồn thay thế khi không có Gemini hoặc Gemini hỏng
// (BRD FR-4, D4). Nạp và kiểm lúc khởi động — file hỏng thì backend không lên, thay vì lỗi giữa request.

export const EXERCISE_LEVELS = [1, 2, 3] as const;
export type ExerciseLevel = (typeof EXERCISE_LEVELS)[number];

export class PoolExerciseDto extends ExerciseContentDto {
  // 1 nhẹ nhất, 3 nặng nhất — "nhẹ hơn" ở FR-4.2 so bằng trường này.
  @IsIn(EXERCISE_LEVELS)
  level: ExerciseLevel;
}

export const SWAP_MEALS: MealContentDto[] = loadPool('swap-meals.json', MealContentDto);
export const SWAP_EXERCISES: PoolExerciseDto[] = loadPool('swap-exercises.json', PoolExerciseDto);

const LEVEL_BY_NAME = new Map(SWAP_EXERCISES.map((exercise) => [normalizeKey(exercise.name), exercise.level]));

// Động tác không có trong kho (do Gemini sinh) → undefined; nơi gọi tự quyết cách hiểu.
export function exerciseLevel(name: string): ExerciseLevel | undefined {
  return LEVEL_BY_NAME.get(normalizeKey(name));
}

function loadPool<T extends object>(file: string, dto: new () => T): T[] {
  const raw = JSON.parse(readFileSync(fileURLToPath(new URL(`./data/${file}`, import.meta.url)), 'utf-8')) as unknown[];
  const items = raw.map((item) => plainToInstance(dto, item));
  const errors = items.flatMap((item, index) =>
    validateSync(item, { whitelist: true, forbidNonWhitelisted: true }).map((error) => `#${index} ${error.property}`),
  );
  if (errors.length > 0) throw new Error(`${file} không đúng hợp đồng: ${errors.slice(0, 5).join('; ')}`);
  const names = items.map((item) => normalizeKey((item as { name: string }).name));
  const duplicate = names.find((name, index) => names.indexOf(name) !== index);
  if (duplicate) throw new Error(`${file}: tên "${duplicate}" bị trùng`);
  return items;
}

export interface MealCandidateFilter {
  avoidIngredients: string[];
  excludeNames: Set<string>;
}

// Món trong kho cùng bữa, không chứa từ khoá dị ứng, không trùng tên món đã có (so bằng normalizeKey).
export function mealCandidates(mealType: MealType, filter: MealCandidateFilter): MealContentDto[] {
  return SWAP_MEALS.filter(
    (meal) =>
      meal.meal_type === mealType &&
      !filter.excludeNames.has(normalizeKey(meal.name)) &&
      findAvoidedIngredient(meal, filter.avoidIngredients) === null,
  );
}

export interface ExerciseCandidateFilter {
  avoidTags: ExerciseTag[];
  excludeNames: Set<string>;
  maxLevel: number;
}

// Động tác trong kho cùng nhóm cơ, không có tag cần tránh, không trùng động tác trong ngày,
// mức khó ≤ maxLevel; xếp khó trước để thay bằng động tác gần mức cũ nhất.
export function exerciseCandidates(muscleGroup: MuscleGroup, filter: ExerciseCandidateFilter): PoolExerciseDto[] {
  return SWAP_EXERCISES.filter(
    (exercise) =>
      exercise.muscle_group === muscleGroup &&
      exercise.level <= filter.maxLevel &&
      !filter.excludeNames.has(normalizeKey(exercise.name)) &&
      !hasAvoidedTag(exercise, filter.avoidTags),
  ).sort((a, b) => b.level - a.level);
}

// Bỏ trường level khi đưa động tác trong kho vào plan (hợp đồng BRD 6.2 không có level).
export function toPlanExercise(exercise: PoolExerciseDto, maxSets = 6): ExerciseContentDto {
  const { level: _level, ...rest } = exercise;
  return { ...rest, sets: Math.min(rest.sets, maxSets) };
}
