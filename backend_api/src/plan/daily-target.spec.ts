import { computeDailyTarget } from './daily-target.js';
import { ActivityLevel } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { Goal } from './enums/goal.enum.js';

const profile = {
  age: 22,
  gender: Gender.FEMALE,
  height_cm: 168,
  weight_kg: 62,
  activity_level: ActivityLevel.LIGHT,
  goal: Goal.CUT,
};

describe('computeDailyTarget', () => {
  it('applies a 300 kcal deficit for cut and matches the BRD example', () => {
    expect(computeDailyTarget(profile)).toEqual({
      flooredToBmr: false,
      target: {
        bmi: 22,
        bmr: 1399,
        tdee: 1924,
        target_calories: 1624,
        protein_g: 102,
        carbs_g: 183,
        fat_g: 54,
      },
    });
  });

  it('applies a 250 kcal surplus for bulk', () => {
    const { target } = computeDailyTarget({ ...profile, goal: Goal.BULK });
    expect(target.target_calories).toBe(2174);
  });

  it('never sets the target below BMR', () => {
    const result = computeDailyTarget({
      ...profile,
      height_cm: 150,
      weight_kg: 45,
      activity_level: ActivityLevel.SEDENTARY,
    });
    expect(result.flooredToBmr).toBe(true);
    expect(result.target.bmr).toBe(1117);
    expect(result.target.target_calories).toBe(1117);
    expect(result.target.bmi).toBe(20);
  });
});

const PROFILES = {
  FEMALE: { age: 22, gender: Gender.FEMALE, height_cm: 168, weight_kg: 62 },
  MALE: { age: 30, gender: Gender.MALE, height_cm: 175, weight_kg: 70 },
};

// Số liệu tính độc lập bằng script Python trong docs/superpowers/plans/phase-2-backend-tests/specs/F01-daily-target-matrix.md
// [hồ sơ, mức vận động, mục tiêu, bị nâng lên BMR, bmi, bmr, tdee, target_calories, protein_g, carbs_g, fat_g]
const MATRIX = [
  ['FEMALE', ActivityLevel.SEDENTARY, Goal.CUT, true, 22, 1399, 1679, 1399, 87, 157, 47],
  ['FEMALE', ActivityLevel.SEDENTARY, Goal.MAINTAIN, false, 22, 1399, 1679, 1679, 105, 189, 56],
  ['FEMALE', ActivityLevel.SEDENTARY, Goal.BULK, false, 22, 1399, 1679, 1929, 121, 217, 64],
  ['FEMALE', ActivityLevel.LIGHT, Goal.CUT, false, 22, 1399, 1924, 1624, 102, 183, 54],
  ['FEMALE', ActivityLevel.LIGHT, Goal.MAINTAIN, false, 22, 1399, 1924, 1924, 120, 216, 64],
  ['FEMALE', ActivityLevel.LIGHT, Goal.BULK, false, 22, 1399, 1924, 2174, 136, 245, 72],
  ['FEMALE', ActivityLevel.ACTIVE, Goal.CUT, false, 22, 1399, 2168, 1868, 117, 210, 62],
  ['FEMALE', ActivityLevel.ACTIVE, Goal.MAINTAIN, false, 22, 1399, 2168, 2168, 136, 244, 72],
  ['FEMALE', ActivityLevel.ACTIVE, Goal.BULK, false, 22, 1399, 2168, 2418, 151, 272, 81],
  ['MALE', ActivityLevel.SEDENTARY, Goal.CUT, false, 22.9, 1649, 1979, 1679, 105, 189, 56],
  ['MALE', ActivityLevel.SEDENTARY, Goal.MAINTAIN, false, 22.9, 1649, 1979, 1979, 124, 223, 66],
  ['MALE', ActivityLevel.SEDENTARY, Goal.BULK, false, 22.9, 1649, 1979, 2229, 139, 251, 74],
  ['MALE', ActivityLevel.LIGHT, Goal.CUT, false, 22.9, 1649, 2267, 1967, 123, 221, 66],
  ['MALE', ActivityLevel.LIGHT, Goal.MAINTAIN, false, 22.9, 1649, 2267, 2267, 142, 255, 76],
  ['MALE', ActivityLevel.LIGHT, Goal.BULK, false, 22.9, 1649, 2267, 2517, 157, 283, 84],
  ['MALE', ActivityLevel.ACTIVE, Goal.CUT, false, 22.9, 1649, 2556, 2256, 141, 254, 75],
  ['MALE', ActivityLevel.ACTIVE, Goal.MAINTAIN, false, 22.9, 1649, 2556, 2556, 160, 288, 85],
  ['MALE', ActivityLevel.ACTIVE, Goal.BULK, false, 22.9, 1649, 2556, 2806, 175, 316, 94],
] as const;

describe('computeDailyTarget — nam/nữ × mức vận động × mục tiêu', () => {
  it.each(MATRIX)(
    '%s · %s · %s',
    (profile, activity_level, goal, flooredToBmr, bmi, bmr, tdee, target_calories, protein_g, carbs_g, fat_g) => {
      expect(computeDailyTarget({ ...PROFILES[profile], activity_level, goal })).toEqual({
        flooredToBmr,
        target: { bmi, bmr, tdee, target_calories, protein_g, carbs_g, fat_g },
      });
    },
  );
});
