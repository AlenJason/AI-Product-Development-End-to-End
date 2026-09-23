# F01 — Ma trận BMR/TDEE 18 trường hợp

## Feature

Chứng minh tiêu chí nghiệm thu "Backend tính đúng công thức BMR/TDEE" (BRD mục 9) bằng 18 trường hợp: 2 hồ sơ (nữ, nam) × 3 mức vận động × 3 mục tiêu. Số liệu mong đợi được tính bằng **một bản cài đặt độc lập** (script Python dưới đây) và ghi cứng vào test — test tự tính lại bằng chính công thức trong code thì luôn xanh và không chứng minh được gì.

Hai trường hợp đáng chú ý nằm tự nhiên trong ma trận:

- Nữ · ít vận động · giảm mỡ: 1678,8 − 300 = 1378,8 < BMR 1399 → bị nâng lên bằng BMR (ràng buộc #13).
- Nam · ít vận động: TDEE = 1648,75 × 1,2 = 1978,5 — nằm đúng ranh giới làm tròn. `Math.round` của JS cho 1979; `round()` mặc định của Python (làm tròn kiểu ngân hàng) cho 1978. Test khoá luôn cách làm tròn.

## Scope

API-only (test) — `backend_api/src/plan/daily-target.spec.ts` (thêm một `describe`, giữ 3 test cũ).

## Implementation

### API Routes

Không đổi. Hàm được `POST /api/v1/generate-plan` dùng; latency không đổi (phép tính thuần, dưới 1 ms).

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#1** hệ số vận động 1.2 / 1.375 / 1.55 — dùng trong script Python.
- **#13** sàn BMR và mức điều chỉnh −300 / +250 — trường hợp nữ · ít vận động · giảm mỡ.
- **#4** ESM: import có đuôi `.js`.

### Script tính số liệu mong đợi

```python
import math

def js_round(x):  # giống Math.round của JS: .5 làm tròn lên
    return math.floor(x + 0.5)

profiles = {'FEMALE': dict(age=22, male=False, h=168, w=62), 'MALE': dict(age=30, male=True, h=175, w=70)}
acts = [('SEDENTARY', 1.2), ('LIGHT', 1.375), ('ACTIVE', 1.55)]
goals = [('CUT', -300), ('MAINTAIN', 0), ('BULK', 250)]

for pname, p in profiles.items():
    bmr = 10 * p['w'] + 6.25 * p['h'] - 5 * p['age'] + (5 if p['male'] else -161)
    bmi = js_round(p['w'] / (p['h'] / 100) ** 2 * 10) / 10
    for aname, mult in acts:
        tdee = bmr * mult
        for gname, adj in goals:
            adjusted = tdee + adj
            target = js_round(max(adjusted, bmr))
            print(pname, aname, gname, adjusted < bmr, bmi, js_round(bmr), js_round(tdee), target,
                  js_round(target * 0.25 / 4), js_round(target * 0.45 / 4), js_round(target * 0.3 / 9))
```

## Definition of Done

- [ ] 18 trường hợp mới pass, 3 test cũ vẫn pass (`Tests  21 passed (21)`)
- [ ] Có ít nhất 1 trường hợp bị nâng lên BMR và 1 trường hợp nằm đúng ranh giới làm tròn .5
- [x] All API routes complete within deployment timeout — không áp dụng (không đổi route)
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: 17 trường hợp thông thường khớp từng con số
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: nữ · ít vận động · giảm mỡ → `flooredToBmr: true`, mục tiêu = BMR
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Thêm ma trận vào `backend_api/src/plan/daily-target.spec.ts`

Thêm vào **cuối file** (giữ nguyên phần import và 3 test đang có):

```ts
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
```

### Task 2 — Chạy

```bash
cd backend_api && npx vitest run src/plan/daily-target.spec.ts
```

Mong đợi: `Tests  21 passed (21)`. Code `daily-target.ts` đã có từ giai đoạn 1 nên ma trận xanh ngay; nếu một hàng đỏ, **không sửa số trong test cho khớp** — chạy lại script Python để xem bên nào sai.
