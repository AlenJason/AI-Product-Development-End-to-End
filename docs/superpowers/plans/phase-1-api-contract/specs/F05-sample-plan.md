# F05 — Thực đơn mẫu 3 ngày theo hợp đồng mới

## Feature

Soạn lại `sample-plan.json` theo định dạng nội dung mới (`PlanContentDto`: chỉ có `days`, không có `plan_id`, `daily_target`, `grocery_list` — server tự thêm) và **đủ 3 ngày** (hiện chỉ có Ngày 1). Thực đơn mẫu phải qua cùng bộ kiểm tra với kết quả Gemini, và có test đảm bảo điều đó để file mẫu không lệch hợp đồng về sau.

Món trong thực đơn mẫu **tránh hải sản và đậu phộng** (hai nhóm dị ứng hay gặp) để giảm rủi ro ở chế độ giả lập; F06 vẫn thêm cảnh báo "chưa lọc theo dị ứng" khi người dùng có nhập hạn chế.

## Scope

API-only:

- `backend_api/src/plan/data/sample-plan.json` (viết lại toàn bộ)
- `backend_api/src/plan/sample-plan.spec.ts` (mới)

## Implementation

### API Routes

`POST /api/v1/generate-plan` dùng file này làm fallback từ F06. Latency đường fallback: đọc file ~5 KB + kiểm tra, dưới 100 ms trên máy dev.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#5** (file không phải `.ts` phải khai báo trong `nest-cli.json`): `plan/data/*.json` đã có trong `compilerOptions.assets` — không cần sửa, nhưng cổng kiểm tra F06 xác nhận lại bằng `curl`.
- **#2, #6**: thực đơn mẫu qua `parsePlanContent()` (F02) — test ở Task 1.

Kiểm tra tay số liệu từng món (calo khai báo so với 4P + 4C + 9F, khoảng calo theo bữa):

| Ngày | Bữa | Món | P / C / F | 4P+4C+9F | Khai báo |
|---|---|---|---|---|---|
| 1 | sáng | Bún thịt bò nạc | 25 / 55 / 10 | 410 | 410 |
| 1 | trưa | Cơm trắng, ức gà xào nấm, canh cải ngọt | 45 / 85 / 12 | 628 | 630 |
| 1 | tối | Đậu phụ sốt cà chua, canh bí đỏ thịt băm | 30 / 75 / 15 | 555 | 555 |
| 2 | sáng | Bánh mì trứng ốp la | 18 / 45 / 14 | 378 | 380 |
| 2 | trưa | Cơm gà luộc, rau muống xào tỏi | 42 / 82 / 13 | 613 | 615 |
| 2 | tối | Bò xào cần tây, canh rau ngót | 32 / 70 / 16 | 552 | 550 |
| 3 | sáng | Phở gà | 24 / 58 / 8 | 400 | 400 |
| 3 | trưa | Cơm thịt nạc kho, canh bầu | 36 / 84 / 14 | 606 | 605 |
| 3 | tối | Trứng hấp thịt băm, rau cải luộc | 28 / 68 / 17 | 537 | 535 |

Bữa sáng 380–410 (khoảng 250–600), trưa 605–630 và tối 535–555 (khoảng 400–800); lệch macro lớn nhất 0,53% (bánh mì trứng: 378 so với 380), dưới ngưỡng 15% rất xa.

## Definition of Done

- [ ] `sample-plan.json` qua `parsePlanContent()` không lỗi
- [ ] 3 ngày, 9 tên món khác nhau, không có hải sản hay đậu phộng
- [ ] Ghép qua `assemblePlan()` ra dòng `Gạo tẻ — 540g` với 6 `source_meal_ids`
- [ ] `npm run build` không lỗi, `npm test` xanh
- [x] All API routes complete within deployment timeout — đường fallback < 100 ms
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: thực đơn mẫu qua bộ kiểm tra; ghép ra danh sách đi chợ đúng
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng (đọc file cục bộ)
4. **@partial-fail**: nếu ai đó sửa file mẫu sai hợp đồng về sau → test này đỏ trước khi lên tới người dùng
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Viết test trước

`backend_api/src/plan/sample-plan.spec.ts`:

```ts
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { PlanSource } from './enums/plan-source.enum.js';
import { assemblePlan } from './plan-assembly.js';
import { parsePlanContent } from './plan-validation.js';

const raw: unknown = JSON.parse(
  readFileSync(fileURLToPath(new URL('./data/sample-plan.json', import.meta.url)), 'utf-8'),
);

describe('sample-plan.json', () => {
  it('follows the same contract as Gemini output', () => {
    expect(parsePlanContent(raw).errors).toEqual([]);
  });

  it('has 3 days and aggregates shared ingredients into the grocery list', () => {
    const { plan } = parsePlanContent(raw);
    if (!plan) throw new Error('sample-plan.json không hợp lệ');
    const target = { bmi: 1, bmr: 1, tdee: 1, target_calories: 1, protein_g: 1, carbs_g: 1, fat_g: 1 };
    const assembled = assemblePlan(plan, target, PlanSource.SAMPLE, []);
    const rice = assembled.grocery_list
      .find((group) => group.category === 'pantry')
      ?.items.find((item) => item.name === 'Gạo tẻ');

    expect(assembled.days).toHaveLength(3);
    expect(rice).toEqual({
      name: 'Gạo tẻ',
      quantity: '540g',
      source_meal_ids: ['m1_2', 'm1_3', 'm2_2', 'm2_3', 'm3_2', 'm3_3'],
    });
  });
});
```

Chạy:

```bash
cd backend_api && npx vitest run src/plan/sample-plan.spec.ts
```

Mong đợi: **FAIL** — file mẫu hiện tại có `meal_type: "Bữa sáng"`, `ingredients` là chuỗi, thiếu `carbs_g`/`fat_g` và chỉ có 1 ngày.

### Task 2 — Viết lại file mẫu

`backend_api/src/plan/data/sample-plan.json`:

```json
{
  "days": [
    {
      "meals": [
        {
          "meal_type": "breakfast",
          "name": "Bún thịt bò nạc",
          "portion": "1 tô vừa",
          "calories": 410,
          "protein_g": 25,
          "carbs_g": 55,
          "fat_g": 10,
          "ingredients": [
            { "name": "Bún tươi", "amount": 150, "unit": "g", "category": "pantry" },
            { "name": "Thịt bò nạc", "amount": 70, "unit": "g", "category": "protein" },
            { "name": "Rau thơm", "amount": 20, "unit": "g", "category": "produce" },
            { "name": "Hành lá", "amount": 10, "unit": "g", "category": "produce" }
          ]
        },
        {
          "meal_type": "lunch",
          "name": "Cơm trắng, ức gà xào nấm, canh cải ngọt",
          "portion": "1 chén cơm + 1 đĩa thức ăn + 1 bát canh",
          "calories": 630,
          "protein_g": 45,
          "carbs_g": 85,
          "fat_g": 12,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 100, "unit": "g", "category": "pantry" },
            { "name": "Ức gà", "amount": 150, "unit": "g", "category": "protein" },
            { "name": "Nấm rơm", "amount": 50, "unit": "g", "category": "produce" },
            { "name": "Rau cải ngọt", "amount": 150, "unit": "g", "category": "produce" },
            { "name": "Dầu ăn", "amount": 1, "unit": "tbsp", "category": "pantry" }
          ]
        },
        {
          "meal_type": "dinner",
          "name": "Đậu phụ sốt cà chua, canh bí đỏ thịt băm",
          "portion": "1 chén cơm + 1 đĩa đậu + 1 bát canh",
          "calories": 555,
          "protein_g": 30,
          "carbs_g": 75,
          "fat_g": 15,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 80, "unit": "g", "category": "pantry" },
            { "name": "Đậu phụ", "amount": 150, "unit": "g", "category": "protein" },
            { "name": "Cà chua", "amount": 100, "unit": "g", "category": "produce" },
            { "name": "Bí đỏ", "amount": 150, "unit": "g", "category": "produce" },
            { "name": "Thịt nạc băm", "amount": 40, "unit": "g", "category": "protein" }
          ]
        }
      ],
      "workout": {
        "title": "Vận động toàn thân tại nhà",
        "duration_minutes": 20,
        "exercises": [
          { "name": "Jumping Jacks (khởi động)", "sets": 2, "reps_or_duration": "30 giây", "muscle_group": "cardio", "tags": ["jumping"] },
          { "name": "Squat tay không", "sets": 3, "reps_or_duration": "12-15 lần", "muscle_group": "legs", "tags": [] },
          { "name": "Chống đẩy khuỵu gối", "sets": 3, "reps_or_duration": "10-12 lần", "muscle_group": "chest", "tags": ["kneeling", "wrist_load"] },
          { "name": "Plank cẳng tay", "sets": 3, "reps_or_duration": "30 giây", "muscle_group": "core", "tags": [] }
        ]
      }
    },
    {
      "meals": [
        {
          "meal_type": "breakfast",
          "name": "Bánh mì trứng ốp la",
          "portion": "1 ổ bánh mì + 2 quả trứng",
          "calories": 380,
          "protein_g": 18,
          "carbs_g": 45,
          "fat_g": 14,
          "ingredients": [
            { "name": "Bánh mì", "amount": 1, "unit": "piece", "category": "pantry" },
            { "name": "Trứng gà", "amount": 2, "unit": "piece", "category": "protein" },
            { "name": "Dưa leo", "amount": 50, "unit": "g", "category": "produce" },
            { "name": "Dầu ăn", "amount": 1, "unit": "tsp", "category": "pantry" }
          ]
        },
        {
          "meal_type": "lunch",
          "name": "Cơm gà luộc, rau muống xào tỏi",
          "portion": "1 chén cơm + 1 đĩa gà + 1 đĩa rau",
          "calories": 615,
          "protein_g": 42,
          "carbs_g": 82,
          "fat_g": 13,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 100, "unit": "g", "category": "pantry" },
            { "name": "Thịt gà bỏ da", "amount": 150, "unit": "g", "category": "protein" },
            { "name": "Rau muống", "amount": 150, "unit": "g", "category": "produce" },
            { "name": "Tỏi", "amount": 5, "unit": "g", "category": "produce" },
            { "name": "Dầu ăn", "amount": 1, "unit": "tbsp", "category": "pantry" }
          ]
        },
        {
          "meal_type": "dinner",
          "name": "Bò xào cần tây, canh rau ngót",
          "portion": "1 chén cơm + 1 đĩa bò + 1 bát canh",
          "calories": 550,
          "protein_g": 32,
          "carbs_g": 70,
          "fat_g": 16,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 80, "unit": "g", "category": "pantry" },
            { "name": "Thịt bò nạc", "amount": 100, "unit": "g", "category": "protein" },
            { "name": "Cần tây", "amount": 80, "unit": "g", "category": "produce" },
            { "name": "Rau ngót", "amount": 100, "unit": "g", "category": "produce" },
            { "name": "Dầu ăn", "amount": 1, "unit": "tbsp", "category": "pantry" }
          ]
        }
      ],
      "workout": {
        "title": "Chân và mông, không bật nhảy",
        "duration_minutes": 20,
        "exercises": [
          { "name": "Đi bộ tại chỗ nâng cao gối (khởi động)", "sets": 2, "reps_or_duration": "45 giây", "muscle_group": "cardio", "tags": [] },
          { "name": "Lunge lùi", "sets": 3, "reps_or_duration": "10 lần mỗi chân", "muscle_group": "legs", "tags": [] },
          { "name": "Cầu mông (Glute bridge)", "sets": 3, "reps_or_duration": "15 lần", "muscle_group": "legs", "tags": [] },
          { "name": "Bird-dog", "sets": 3, "reps_or_duration": "10 lần mỗi bên", "muscle_group": "core", "tags": ["kneeling", "wrist_load"] }
        ]
      }
    },
    {
      "meals": [
        {
          "meal_type": "breakfast",
          "name": "Phở gà",
          "portion": "1 tô vừa",
          "calories": 400,
          "protein_g": 24,
          "carbs_g": 58,
          "fat_g": 8,
          "ingredients": [
            { "name": "Bánh phở", "amount": 150, "unit": "g", "category": "pantry" },
            { "name": "Thịt gà bỏ da", "amount": 70, "unit": "g", "category": "protein" },
            { "name": "Hành lá", "amount": 10, "unit": "g", "category": "produce" },
            { "name": "Rau thơm", "amount": 20, "unit": "g", "category": "produce" }
          ]
        },
        {
          "meal_type": "lunch",
          "name": "Cơm thịt nạc kho, canh bầu",
          "portion": "1 chén cơm + 1 đĩa thịt + 1 bát canh",
          "calories": 605,
          "protein_g": 36,
          "carbs_g": 84,
          "fat_g": 14,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 100, "unit": "g", "category": "pantry" },
            { "name": "Thịt heo nạc", "amount": 120, "unit": "g", "category": "protein" },
            { "name": "Bầu", "amount": 150, "unit": "g", "category": "produce" },
            { "name": "Nước mắm", "amount": 1, "unit": "tbsp", "category": "pantry" }
          ]
        },
        {
          "meal_type": "dinner",
          "name": "Trứng hấp thịt băm, rau cải luộc",
          "portion": "1 chén cơm + 1 đĩa trứng + 1 đĩa rau",
          "calories": 535,
          "protein_g": 28,
          "carbs_g": 68,
          "fat_g": 17,
          "ingredients": [
            { "name": "Gạo tẻ", "amount": 80, "unit": "g", "category": "pantry" },
            { "name": "Trứng gà", "amount": 2, "unit": "piece", "category": "protein" },
            { "name": "Thịt nạc băm", "amount": 50, "unit": "g", "category": "protein" },
            { "name": "Rau cải ngọt", "amount": 150, "unit": "g", "category": "produce" }
          ]
        }
      ],
      "workout": {
        "title": "Thân trên và cơ lõi",
        "duration_minutes": 20,
        "exercises": [
          { "name": "Xoay khớp vai và tay (khởi động)", "sets": 1, "reps_or_duration": "2 phút", "muscle_group": "full_body", "tags": [] },
          { "name": "Chống đẩy tường", "sets": 3, "reps_or_duration": "12-15 lần", "muscle_group": "chest", "tags": [] },
          { "name": "Superman", "sets": 3, "reps_or_duration": "12 lần", "muscle_group": "back", "tags": ["back_load"] },
          { "name": "Gập bụng chạm gót", "sets": 3, "reps_or_duration": "20 lần", "muscle_group": "core", "tags": [] }
        ]
      }
    }
  ]
}
```

### Task 3 — Chạy lại

```bash
cd backend_api && npx vitest run src/plan/sample-plan.spec.ts
cd backend_api && npm run build && npm test
```

Mong đợi: `Test Files  1 passed (1)`, `Tests  2 passed (2)`; build không lỗi; `npm test` xanh toàn bộ.
