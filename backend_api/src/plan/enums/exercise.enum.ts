export enum MuscleGroup {
  LEGS = 'legs',
  CHEST = 'chest',
  BACK = 'back',
  CORE = 'core',
  SHOULDERS = 'shoulders',
  ARMS = 'arms',
  FULL_BODY = 'full_body',
  CARDIO = 'cardio',
}

// Đặc điểm động tác, dùng để loại bài theo chấn thương (BRD FR-4.2, FR-5.2).
export enum ExerciseTag {
  JUMPING = 'jumping',
  KNEELING = 'kneeling',
  // Gập gối chịu sức nặng cơ thể: squat, lunge, ngồi dựa tường, bước lên bục (bản 2.7.0, PLAN D8).
  KNEE_BEND = 'knee_bend',
  WRIST_LOAD = 'wrist_load',
  BACK_LOAD = 'back_load',
  OVERHEAD = 'overhead',
}
