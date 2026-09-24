// Câu trả lời của bảng feedback cuối ngày (BRD FR-5.1, mục 6.4).

export enum Intensity {
  EASY = 'easy',
  MODERATE = 'moderate',
  HARD = 'hard',
}

export enum BodyState {
  NORMAL = 'normal',
  SORE = 'sore',
  JOINT_PAIN = 'joint_pain',
  FATIGUED = 'fatigued',
  DANGER_SIGN = 'danger_sign',
}

export enum Eating {
  ON_PLAN = 'on_plan',
  OVER = 'over',
  UNDER = 'under',
}
