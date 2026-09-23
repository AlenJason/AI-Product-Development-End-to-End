# F03 — Mục tiêu calo: D1, sàn BMR, BMI

## Feature

Tách phép tính mục tiêu calo ra một hàm thuần `computeDailyTarget()` (dễ test, không cần DI của NestJS), áp dụng D1 (giảm mỡ −300, tăng cơ +250), sàn BMR theo Q4 (mục tiêu không bao giờ thấp hơn BMR), và thêm `bmi`, `bmr`, `tdee` vào `daily_target` như BRD FR-1.5 v2.3.0. Hàm trả thêm cờ `flooredToBmr` để F06 thêm câu giải thích vào `warnings`.

`PlanService.computeDailyTarget()` cũ vẫn giữ tới F06 (nó cũng dùng hằng số D1 mới ngay từ feature này).

## Scope

API-only:

- `backend_api/src/plan/enums/goal.enum.ts` (sửa hằng số)
- `backend_api/src/plan/daily-target.ts` (mới)
- `backend_api/src/plan/daily-target.spec.ts` (mới)

## Implementation

### API Routes

Chưa đổi route; F06 nối vào `POST /api/v1/generate-plan`.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#1** (hệ số vận động 1.2 / 1.375 / 1.55): dùng lại `ACTIVITY_MULTIPLIER`, không đổi.
- **#4** (ESM): import có đuôi `.js`.
- Ràng buộc mới về sàn BMR (F07 thêm vào wiki): `target_calories = max(TDEE + điều chỉnh, BMR)`.

## Definition of Done

- [ ] `GOAL_CALORIE_ADJUSTMENT`: cut −300, bulk +250, maintain 0
- [ ] Nữ 22 tuổi, 168 cm, 62 kg, vận động nhẹ, giảm mỡ → `{ bmi: 22, bmr: 1399, tdee: 1924, target_calories: 1624, protein_g: 102, carbs_g: 183, fat_g: 54 }`, `flooredToBmr: false`
- [ ] Nữ 22 tuổi, 150 cm, 45 kg, ít vận động, giảm mỡ → `target_calories` = `bmr` = 1117, `flooredToBmr: true`
- [ ] `npm run build` không lỗi, `npm test` xanh
- [x] All API routes complete within deployment timeout — không áp dụng (hàm thuần)
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: ví dụ BRD mục 6.2 ra đúng từng con số
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: người nhỏ con, ít vận động, giảm mỡ → được nâng lên bằng BMR, không ra số dưới BMR
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết test trước

`backend_api/src/plan/daily-target.spec.ts`:

```ts
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
```

Số liệu kiểm tra (Mifflin-St Jeor, nữ = −161):

- Ca 1: BMR = 620 + 1050 − 110 − 161 = 1399; TDEE = 1399 × 1.375 = 1923.625 → 1924; mục tiêu = 1623.625 → 1624; protein = 1624 × 0.25 / 4 = 101.5 → 102; carbs = 182.7 → 183; fat = 54.13 → 54; BMI = 62 / 1.68² = 21.97 → 22.
- Ca 2: 1923.625 + 250 = 2173.625 → 2174.
- Ca 3: BMR = 450 + 937.5 − 110 − 161 = 1116.5; TDEE = 1339.8; 1339.8 − 300 = 1039.8 < BMR → mục tiêu = 1116.5 → 1117; BMI = 45 / 1.5² = 20.

Chạy:

```bash
cd backend_api && npx vitest run src/plan/daily-target.spec.ts
```

Mong đợi: **FAIL** — `Cannot find module './daily-target.js'`.

### Task 2 — Hằng số D1

`backend_api/src/plan/enums/goal.enum.ts` — thay khối `GOAL_CALORIE_ADJUSTMENT`:

```ts
// Điều chỉnh calo mục tiêu so với TDEE theo mục tiêu người dùng (BRD FR-1.3, quyết định D1).
export const GOAL_CALORIE_ADJUSTMENT: Record<Goal, number> = {
  [Goal.CUT]: -300,
  [Goal.BULK]: 250,
  [Goal.MAINTAIN]: 0,
};
```

### Task 3 — Hàm tính

`backend_api/src/plan/daily-target.ts`:

```ts
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
```

### Task 4 — Chạy lại

```bash
cd backend_api && npx vitest run src/plan/daily-target.spec.ts
cd backend_api && npm run build && npm test
```

Mong đợi: `Test Files  1 passed (1)`, `Tests  3 passed (3)`; build không lỗi; `npm test` xanh toàn bộ.
