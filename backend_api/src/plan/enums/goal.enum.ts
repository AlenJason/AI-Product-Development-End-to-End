export enum Goal {
  CUT = 'cut',
  BULK = 'bulk',
  MAINTAIN = 'maintain',
}

// Điều chỉnh calo mục tiêu so với TDEE theo mục tiêu người dùng (BRD FR-1.3).
export const GOAL_CALORIE_ADJUSTMENT: Record<Goal, number> = {
  [Goal.CUT]: -500,
  [Goal.BULK]: 300,
  [Goal.MAINTAIN]: 0,
};
