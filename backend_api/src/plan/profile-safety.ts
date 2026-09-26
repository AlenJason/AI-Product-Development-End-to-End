import { Gender } from './enums/gender.enum.js';

// Hồ sơ không được phép thâm hụt calo (BRD FR-1.1, FR-1.3, v2.6.0; quyết định D6 A1–A3). Kiểm ở mọi endpoint nhận
// hồ sơ (`SafeGoalConstraint` trên `CreatePlanDto`). App Flutter khoá lựa chọn theo đúng các ngưỡng này
// (`frontend_app/lib/models/profile_rules.dart`); backend vẫn là nơi quyết định.

// Công thức Mifflin-St Jeor dành cho người trưởng thành; đối tượng BRD mục 3 là sinh viên và người đi làm.
export const MIN_AGE = 18;
export const MAX_AGE = 100;
// Ngưỡng thiếu cân của WHO.
export const UNDERWEIGHT_BMI = 18.5;

export const PROFILE_SAFETY_MESSAGES = {
  underweightCut:
    'Chỉ số BMI dưới 18,5 (thiếu cân) nên không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng hoặc Tăng cơ.',
  pregnantCut:
    'Đang mang thai hoặc cho con bú thì không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng và hỏi ý kiến bác sĩ.',
  pregnantNotFemale: 'pregnant_or_breastfeeding chỉ được là true khi gender là female.',
} as const;

export interface SafetyProfile {
  gender: Gender;
  height_cm: number;
  weight_kg: number;
  pregnant_or_breastfeeding?: boolean;
}

// BMI chưa làm tròn: làm tròn trước khi so sẽ cho 18,46 thành 18,5 và lọt qua ngưỡng.
export function bodyMassIndex(heightCm: number, weightKg: number): number {
  const heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

// Lý do không được chọn Giảm mỡ, hoặc null. Chiều cao/cân nặng sai kiểu → NaN → không chặn (validator khác báo lỗi).
export function cutBlockReason(profile: SafetyProfile): string | null {
  if (profile.pregnant_or_breastfeeding === true) return PROFILE_SAFETY_MESSAGES.pregnantCut;
  if (bodyMassIndex(profile.height_cm, profile.weight_kg) < UNDERWEIGHT_BMI) return PROFILE_SAFETY_MESSAGES.underweightCut;
  return null;
}
