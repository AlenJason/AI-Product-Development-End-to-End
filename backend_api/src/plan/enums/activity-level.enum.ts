export enum ActivityLevel {
  SEDENTARY = 'sedentary',
  LIGHT = 'light',
  ACTIVE = 'active',
}

// Hệ số nhân theo mức độ vận động — dùng để tính TDEE = BMR × hệ số (BRD mục 4/FR-1.5).
export const ACTIVITY_MULTIPLIER: Record<ActivityLevel, number> = {
  [ActivityLevel.SEDENTARY]: 1.2,
  [ActivityLevel.LIGHT]: 1.375,
  [ActivityLevel.ACTIVE]: 1.55,
};
