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
