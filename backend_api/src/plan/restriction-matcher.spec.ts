import type { MealContentDto } from './dto/plan-content.dto.js';
import { RestrictionsDto } from './dto/restrictions.dto.js';
import { ExerciseTag } from './enums/exercise.enum.js';
import { IngredientCategory, IngredientUnit } from './enums/ingredient.enum.js';
import { MealType } from './enums/meal-type.enum.js';
import {
  findAvoidedIngredient,
  hasAvoidedTag,
  impliedExerciseTags,
  matchRestrictions,
  withImpliedTags,
} from './restriction-matcher.js';

const restrictions = (values: Partial<RestrictionsDto>) => Object.assign(new RestrictionsDto(), values);

function meal(name: string, ingredients: string[]): MealContentDto {
  return {
    meal_type: MealType.LUNCH,
    name,
    portion: '1 phần',
    calories: 500,
    protein_g: 30,
    carbs_g: 60,
    fat_g: 15,
    ingredients: ingredients.map((ingredient) => ({
      name: ingredient,
      amount: 100,
      unit: IngredientUnit.G,
      category: IngredientCategory.PANTRY,
    })),
  };
}

describe('matchRestrictions', () => {
  it('recognises allergies and injuries typed with or without accents', () => {
    for (const text of ['Hải sản', 'hai san', 'HẢI SẢN', 'dị ứng hải sản']) {
      expect(matchRestrictions(restrictions({ allergies: text })).avoidIngredients).toContain('tôm');
    }
    for (const text of ['Đau gối', 'dau goi', 'đau đầu gối trái']) {
      // Từ bản 2.7.0 đau gối tránh cả động tác gập gối chịu sức nặng (PLAN D8).
      expect(matchRestrictions(restrictions({ injuries: text })).avoidTags).toEqual([
        ExerciseTag.JUMPING,
        ExerciseTag.KNEELING,
        ExerciseTag.KNEE_BEND,
      ]);
    }
  });

  it('splits several restrictions in one field', () => {
    const match = matchRestrictions(restrictions({ allergies: 'tôm, đậu phộng và sữa', injuries: 'cổ tay; lưng' }));
    expect(match.avoidIngredients).toEqual(expect.arrayContaining(['tôm', 'đậu phộng', 'sữa']));
    expect(match.avoidTags).toEqual(expect.arrayContaining([ExerciseTag.WRIST_LOAD, ExerciseTag.BACK_LOAD]));
    expect(match.hasUnrecognized).toBe(false);
  });

  it('does not read "cà chua" as fish when the user typed accents', () => {
    const match = matchRestrictions(restrictions({ allergies: 'cà chua' }));
    expect(match.avoidIngredients).not.toContain('cá');
    expect(match.hasUnrecognized).toBe(true);
  });

  it('reports unrecognised parts without returning them', () => {
    const match = matchRestrictions(restrictions({ allergies: 'hải sản, phấn hoa' }));
    expect(match.hasUnrecognized).toBe(true);
    expect(JSON.stringify(match)).not.toContain('phấn hoa');
  });

  it('treats empty text and "không" as no restriction', () => {
    for (const text of ['', '   ', 'không', 'Không có', 'ko']) {
      expect(matchRestrictions(restrictions({ allergies: text, injuries: text }))).toEqual({
        avoidIngredients: [],
        avoidTags: [],
        hasUnrecognized: false,
      });
    }
  });
});

describe('findAvoidedIngredient', () => {
  it('matches whole words in the dish or ingredient names', () => {
    expect(findAvoidedIngredient(meal('Canh chua cá lóc', ['Cá lóc']), ['cá'])).toBe('cá');
    expect(findAvoidedIngredient(meal('Cơm thịt kho', ['Nước mắm']), ['mắm'])).toBe('mắm');
  });

  it('keeps accents, so tomato is not fish and avocado is not beef', () => {
    expect(findAvoidedIngredient(meal('Trứng chiên cà chua', ['Cà chua']), ['cá'])).toBeNull();
    expect(findAvoidedIngredient(meal('Sinh tố bơ', ['Quả bơ']), ['bò'])).toBeNull();
  });
});

describe('hasAvoidedTag', () => {
  it('flags an exercise carrying any avoided tag', () => {
    expect(hasAvoidedTag({ tags: [ExerciseTag.KNEELING] }, [ExerciseTag.JUMPING, ExerciseTag.KNEELING])).toBe(true);
    expect(hasAvoidedTag({ tags: [] }, [ExerciseTag.JUMPING])).toBe(false);
  });
});

// #34: tag suy từ tên — Gemini hay plan cũ ghi thiếu tag thì "Squat" vẫn bị nhận là gập gối.
describe('impliedExerciseTags', () => {
  it.each([
    ['Squat tay không', [ExerciseTag.KNEE_BEND]],
    ['Bulgarian split squat (chân sau gác ghế)', [ExerciseTag.KNEE_BEND]],
    ['Lunge lùi', [ExerciseTag.KNEE_BEND]],
    ['Ngồi dựa tường (Wall sit)', [ExerciseTag.KNEE_BEND]],
    ['Step-up lên ghế', [ExerciseTag.KNEE_BEND]],
    ['Burpee', [ExerciseTag.KNEE_BEND, ExerciseTag.JUMPING]],
    ['Squat nhảy', [ExerciseTag.KNEE_BEND, ExerciseTag.JUMPING]],
    ['Nhảy dây không dây', [ExerciseTag.JUMPING]],
    ['Chống đẩy khuỵu gối', [ExerciseTag.KNEELING]],
    ['Ngồi xuống đứng lên với ghế', [ExerciseTag.KNEE_BEND]],
  ])('%s', (name, tags) => {
    expect(impliedExerciseTags(name)).toEqual(tags);
  });

  it('does not flag exercises that only mention the knee or bend it without load', () => {
    for (const name of ['Đi bộ tại chỗ nâng cao gối (khởi động)', 'Cầu mông (Glute bridge)', 'Nhón gót (Calf raise)', 'Plank cẳng tay']) {
      expect(impliedExerciseTags(name)).toEqual([]);
    }
  });

  it('adds implied tags after the given ones, without duplicates', () => {
    expect(withImpliedTags('Squat kết hợp giơ tay', [ExerciseTag.OVERHEAD])).toEqual([ExerciseTag.OVERHEAD, ExerciseTag.KNEE_BEND]);
    expect(withImpliedTags('Squat tay không', [ExerciseTag.KNEE_BEND])).toEqual([ExerciseTag.KNEE_BEND]);
  });
});
