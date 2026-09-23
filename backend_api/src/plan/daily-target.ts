import type { CreatePlanDto } from './dto/create-plan.dto.js';
import type { DailyTargetDto } from './dto/meal-plan-response.dto.js';
import { ACTIVITY_MULTIPLIER } from './enums/activity-level.enum.js';
import { Gender } from './enums/gender.enum.js';
import { GOAL_CALORIE_ADJUSTMENT } from './enums/goal.enum.js';

type BodyProfile = Pick<
  CreatePlanDto,
  'age' | 'gender' | 'height_cm' | 'weight_kg' | 'activity_level' | 'goal'
>;

export interface DailyTargetResult {
  target: DailyTargetDto;
  flooredToBmr: boolean;
}

// BMR theo Mifflin-St Jeor, TDEE = BMR × hệ số vận động; mục tiêu không bao giờ thấp hơn BMR (BRD FR-1.5).
export function computeDailyTarget(profile: BodyProfile): DailyTargetResult {
  const genderOffset = profile.gender === Gender.MALE ? 5 : -161;
  const bmr = 10 * profile.weight_kg + 6.25 * profile.height_cm - 5 * profile.age + genderOffset;
  const tdee = bmr * ACTIVITY_MULTIPLIER[profile.activity_level];
  const adjusted = tdee + GOAL_CALORIE_ADJUSTMENT[profile.goal];
  const targetCalories = Math.round(Math.max(adjusted, bmr));
  const heightM = profile.height_cm / 100;

  return {
    flooredToBmr: adjusted < bmr,
    target: {
      bmi: Math.round((profile.weight_kg / (heightM * heightM)) * 10) / 10,
      bmr: Math.round(bmr),
      tdee: Math.round(tdee),
      target_calories: targetCalories,
      protein_g: Math.round((targetCalories * 0.25) / 4),
      carbs_g: Math.round((targetCalories * 0.45) / 4),
      fat_g: Math.round((targetCalories * 0.3) / 9),
    },
  };
}
