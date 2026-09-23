# F01 — BRD v2.3.0: hợp đồng API

## Feature

Đưa các quyết định D1–D4 (PLAN.md) và Q1–Q4 (brainstorm mục 10) vào `BRD.md`, nâng lên v2.3.0. Sau feature này, BRD mục 6 là hợp đồng đầy đủ cho mọi endpoint: `generate-plan` (6.1, 6.2), auth và lịch sử (6.3, không đổi), đổi món / đổi bài tập / feedback (6.4, mới). Code ở F02–F06 bám đúng theo văn bản này.

## Scope

Docs — `BRD.md`

## Implementation

### API Routes

Không sửa code. Mô tả hợp đồng cho `POST /api/v1/generate-plan` (6.1, 6.2) và ba endpoint giai đoạn 4 (6.4).

### UI Components

Không có. FR-1.4, FR-1.6, FR-5.1 mô tả giao diện mà giai đoạn 6–7 sẽ làm.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- #2, #6, #7 (`critical-constraints.md`): nội dung NFR-4, FR-2.1, FR-3.1, FR-4.1 dưới đây là phiên bản mới của ba ràng buộc này; F07 cập nhật wiki cho khớp.
- #11: không đổi (mục 7.6 giữ nguyên).

## Definition of Done

- [ ] Header ghi `2.3.0`, ngày `24/09/2026`
- [ ] FR-1.3, FR-1.4, FR-1.5, FR-1.6, FR-2.1, FR-2.3, FR-3.1, FR-4.1, FR-4.2, FR-5 đúng văn bản ở Tasks
- [ ] Mục 6 đổi tên, 6.1 / 6.2 viết lại, 6.4 thêm mới; 6.3 giữ nguyên
- [ ] NFR-1, NFR-2, NFR-4 sửa; NFR-7, NFR-8, NFR-9 thêm mới
- [ ] Mọi khối ```json trong BRD parse được (cổng kiểm tra F01)
- [ ] Không còn chuỗi `sample_plan.json`, `"allergies": [`, `source_meal_ids` kiểu cũ (mô tả cập nhật từng phần) trong BRD
- [x] All API routes complete within deployment timeout — không áp dụng (F01 không đụng code)
- [x] Auth check at top of each protected handler — không áp dụng (không có route cần đăng nhập)

## Test Checklist

1. **@happy**: chạy lệnh cổng kiểm tra F01 → in `N json blocks ok`
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: `grep -n "sample_plan.json\|\"allergies\": \[" BRD.md` → không có kết quả
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — Header

Trong `BRD.md`, thay:

```
**Phiên bản:** 2.2.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
```

bằng:

```
**Phiên bản:** 2.3.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
```

(Ngày cập nhật đã là `24/09/2026`.)

### Task 2 — Mục 2.2 và sơ đồ mục 4

Thay dòng:

```
* **Khảo sát đơn giản & cá nhân:** Nhập chiều cao, cân nặng, mục tiêu và hạn chế (dị ứng, đau khớp).
```

bằng:

```
* **Khảo sát đơn giản & cá nhân:** Nhập chiều cao, cân nặng, mục tiêu, hạn chế (dị ứng, chấn thương) và tình trạng sức khoẻ bằng lời của chính người dùng.
```

Trong sơ đồ đầu mục 4, thay:

```
    Gemini-->>NestJS: 4. Trả về chuỗi JSON Kế hoạch 3 ngày
    Note over NestJS: class-validator kiểm tra tính hợp lệ JSON
```

bằng:

```
    Gemini-->>NestJS: 4. Trả về JSON 3 ngày (món ăn + bài tập)
    Note over NestJS: Kiểm tra hợp đồng (class-validator + quy tắc calo, trùng món)<br/>Gán ID, tự tính danh sách đi chợ
```

### Task 3 — FR-1

Thay FR-1.3, FR-1.4, FR-1.5 bằng các dòng dưới, và thêm FR-1.6 ngay sau FR-1.5:

```
* **FR-1.3:** Chọn mục tiêu: *Giảm mỡ (Cut)* — thâm hụt 300 kcal/ngày, *Tăng cơ (Bulk)* — dư 250 kcal/ngày, hoặc *Duy trì vóc dáng (Maintain)*.
* **FR-1.4:** Ba ô nhập tự do, tối đa 300 ký tự mỗi ô: *Dị ứng / thực phẩm cần tránh*, *Chấn thương / vùng cơ thể cần tránh*, *Tình trạng sức khoẻ / bệnh nền* (ví dụ tiểu đường, cao huyết áp, gout). Có chip gợi ý bấm nhanh (hải sản, trứng, sữa, đậu phộng, đau gối, đau lưng…); bấm vào chỉ điền sẵn chữ vào ô. Màn hình ghi rõ: gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế.
* **FR-1.5 (Logic Deterministic):** Backend tự tính BMI, BMR (công thức Mifflin-St Jeor), TDEE = BMR × hệ số hoạt động (FR-1.2), và calo mục tiêu = TDEE + mức điều chỉnh theo mục tiêu (FR-1.3), **nhưng không bao giờ thấp hơn BMR**. Khi phải nâng lên bằng BMR, response có câu giải thích để app hiển thị.
* **FR-1.6:** Tab "Cá nhân" cho xem và sửa hồ sơ (chỉ số cơ thể, mục tiêu, ba ô ở FR-1.4) bất cứ lúc nào. Hồ sơ chỉ lưu trên máy (`shared_preferences`) và gửi kèm từng request, **không lưu ở server**. Sửa xong, app gợi ý tạo lại plan.
```

### Task 4 — FR-2, FR-3, FR-4

Thay FR-2.1:

```
* **FR-2.1 (Thực đơn món Việt):** 3 ngày, mỗi ngày 3 bữa chính (Sáng, Trưa, Tối). Món ăn quen thuộc (phở, bún thịt nạc, canh rau ngót, trứng luộc...). **Ràng buộc đa dạng:** không lặp lại tên món giữa các ngày trong cùng một plan 3 ngày — backend kiểm tra bằng code, không chỉ dặn trong prompt.
```

Thay FR-2.3:

```
* **FR-2.3 (Hiển thị Calo):** Hiển thị tổng Calo dự tính và phân bổ Protein / Carbs / Fat mỗi ngày. Mỗi món có đủ `calories`, `protein_g`, `carbs_g`, `fat_g`.
```

Thay FR-3.1:

```
* **FR-3.1:** Backend tự tổng hợp nguyên liệu của cả 3 ngày thành danh sách 3 nhóm cố định: *Đạm* (thịt, cá, trứng, đậu phụ, sữa), *Rau củ quả*, *Gạo, bún & gia vị* (gạo, bún, mì, gia vị, dầu ăn). Nguyên liệu trùng tên và cùng đơn vị được cộng dồn khối lượng.
```

Thay FR-4.1 và FR-4.2:

```
* **FR-4.1:** Nhấn nút "Đổi món" tại một bữa ăn $\rightarrow$ Backend gọi AI sinh 1 món khác cùng bữa, calo lệch không quá $\pm 10\%$, tránh các hạn chế người dùng đã nhập, không trùng tên món khác trong plan. **Đồng bộ checklist:** backend tính lại toàn bộ danh sách đi chợ từ thực đơn mới, nên checklist luôn khớp thực đơn.
* **FR-4.2:** Nhấn nút "Đổi bài tập" $\rightarrow$ gợi ý động tác khác nhẹ hơn, **cùng nhóm cơ**, tránh động tác gây hại cho chấn thương đã khai (ví dụ bỏ bật nhảy, chống quỳ khi đau gối).
```

### Task 5 — FR-5

Thay toàn bộ khối FR-5 (từ `#### FR-5:` tới hết FR-5.2) bằng:

```
#### FR-5: Đánh giá thích ứng cuối ngày (Adaptive Feedback)
* **FR-5.1:** Form đánh giá nhanh cuối ngày (1 phút), gồm 3 câu hỏi:

| Câu hỏi | Lựa chọn |
|---|---|
| Cường độ buổi tập hôm nay (chọn 1) | Nhẹ nhàng / Vừa sức / Rất mệt |
| Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều) | Bình thường · Căng mỏi cơ · Đau khớp (gối, cổ tay, vai…) · Uể oải, thiếu ngủ · ⚠️ Chóng mặt, khó thở bất thường, đau ngực |
| Ăn uống (chọn 1) | Đúng thực đơn / Ăn nhiều hơn / Ăn ít hơn hoặc bỏ bữa |

* **FR-5.2:** Điều chỉnh ngày kế tiếp:
  * Bài tập theo quy tắc cố định (không cần AI): Nhẹ nhàng → tăng tối đa 1 hiệp; Rất mệt hoặc uể oải → giảm khối lượng, rút ngắn buổi tập; Căng mỏi cơ → giảm hiệp cho nhóm cơ đã tập, thêm giãn cơ; Đau khớp → bỏ động tác bật nhảy, chống quỳ.
  * Món ăn cân đối lại theo câu trả lời về ăn uống (cần AI), không bao giờ hạ calo mục tiêu xuống dưới BMR.
  * **⚠️ Dấu hiệu nguy hiểm** (chóng mặt, khó thở bất thường, đau ngực): không tự điều chỉnh như trên. App hiện khuyến cáo ngừng tập và hỏi ý kiến bác sĩ; ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ.
* **FR-5.3:** Feedback của ngày 3 (ngày cuối plan) tạo luôn plan 3 ngày mới có tính tới feedback đó (cuốn chiếu).
```

### Task 6 — Mục 6: tiêu đề, 6.1, 6.2

Thay tiêu đề `## 6. THIẾT KẾ CẤU TRÚC ĐẦU RA AI (STRUCTURED OUTPUT JSON SCHEMA)` bằng:

```
## 6. HỢP ĐỒNG API (REQUEST / RESPONSE JSON)
```

Thay toàn bộ 6.1 và 6.2 (từ `### 6.1.` tới hết đoạn giải thích `source_meal_ids`, **giữ lại** khối `> [!TIP]` quicktype phía sau) bằng:

````
### 6.1. Request — `POST /api/v1/generate-plan`

```json
{
  "age": 22,
  "gender": "female",
  "height_cm": 168,
  "weight_kg": 62,
  "activity_level": "light",
  "goal": "cut",
  "restrictions": {
    "allergies": "Hải sản",
    "injuries": "Đau gối",
    "health_conditions": ""
  }
}
```

| Trường | Giá trị |
|---|---|
| `age` | số nguyên 10–100 |
| `gender` | `male` / `female` |
| `height_cm`, `weight_kg` | 100–250 cm, 30–250 kg |
| `activity_level` | `sedentary` (ít vận động) / `light` (vận động nhẹ) / `active` (vận động nhiều) — FR-1.2 |
| `goal` | `cut` / `bulk` / `maintain` — FR-1.3 |
| `restrictions.allergies`, `.injuries`, `.health_conditions` | văn bản tự do, tối đa 300 ký tự, có thể bỏ trống hoặc bỏ hẳn `restrictions` — FR-1.4. Không lưu ở server (NFR-7) |

### 6.2. Response — Kế hoạch 3 ngày

`days` luôn có đúng 3 phần tử; ví dụ dưới chỉ ghi Ngày 1 và danh sách đi chợ tương ứng.

```json
{
  "plan_id": "3f1c2b7e-6a55-4c1a-9f0e-2d9b1c7a4e10",
  "source": "gemini",
  "warnings": [],
  "daily_target": {
    "bmi": 22,
    "bmr": 1399,
    "tdee": 1924,
    "target_calories": 1624,
    "protein_g": 102,
    "carbs_g": 183,
    "fat_g": 54
  },
  "days": [
    {
      "day_number": 1,
      "meals": [
        {
          "meal_id": "m1_1",
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
          "meal_id": "m1_2",
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
          "meal_id": "m1_3",
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
          { "exercise_id": "e1_1", "name": "Jumping Jacks (khởi động)", "sets": 2, "reps_or_duration": "30 giây", "muscle_group": "cardio", "tags": ["jumping"] },
          { "exercise_id": "e1_2", "name": "Squat tay không", "sets": 3, "reps_or_duration": "12-15 lần", "muscle_group": "legs", "tags": [] },
          { "exercise_id": "e1_3", "name": "Chống đẩy khuỵu gối", "sets": 3, "reps_or_duration": "10-12 lần", "muscle_group": "chest", "tags": ["kneeling", "wrist_load"] },
          { "exercise_id": "e1_4", "name": "Plank cẳng tay", "sets": 3, "reps_or_duration": "30 giây", "muscle_group": "core", "tags": [] }
        ]
      }
    }
  ],
  "grocery_list": [
    {
      "category": "protein",
      "items": [
        { "name": "Thịt bò nạc", "quantity": "70g", "source_meal_ids": ["m1_1"] },
        { "name": "Ức gà", "quantity": "150g", "source_meal_ids": ["m1_2"] },
        { "name": "Đậu phụ", "quantity": "150g", "source_meal_ids": ["m1_3"] },
        { "name": "Thịt nạc băm", "quantity": "40g", "source_meal_ids": ["m1_3"] }
      ]
    },
    {
      "category": "produce",
      "items": [
        { "name": "Rau thơm", "quantity": "20g", "source_meal_ids": ["m1_1"] },
        { "name": "Hành lá", "quantity": "10g", "source_meal_ids": ["m1_1"] },
        { "name": "Nấm rơm", "quantity": "50g", "source_meal_ids": ["m1_2"] },
        { "name": "Rau cải ngọt", "quantity": "150g", "source_meal_ids": ["m1_2"] },
        { "name": "Cà chua", "quantity": "100g", "source_meal_ids": ["m1_3"] },
        { "name": "Bí đỏ", "quantity": "150g", "source_meal_ids": ["m1_3"] }
      ]
    },
    {
      "category": "pantry",
      "items": [
        { "name": "Bún tươi", "quantity": "150g", "source_meal_ids": ["m1_1"] },
        { "name": "Gạo tẻ", "quantity": "180g", "source_meal_ids": ["m1_2", "m1_3"] },
        { "name": "Dầu ăn", "quantity": "1 muỗng canh", "source_meal_ids": ["m1_2"] }
      ]
    }
  ]
}
```

| Trường | Giá trị |
|---|---|
| `source` | `gemini` (AI thật) / `sample` (thực đơn mẫu — khi chưa có khoá hoặc Gemini lỗi) |
| `warnings` | danh sách câu cảnh báo tiếng Việt, app hiển thị nguyên văn (ví dụ: calo đã nâng lên bằng BMR; thực đơn mẫu chưa lọc theo dị ứng) |
| `daily_target` | `bmi` (1 chữ số thập phân), `bmr`, `tdee`, `target_calories`, macro mục tiêu (g) — FR-1.5 |
| `meals[].meal_type` | `breakfast` / `lunch` / `dinner` — mỗi ngày đúng mỗi loại một bữa |
| `ingredients[].unit` | `g`, `ml`, `piece` (hiển thị ×n), `tbsp` (muỗng canh), `tsp` (muỗng cà phê) |
| `ingredients[].category`, `grocery_list[].category` | `protein` (Đạm), `produce` (Rau củ quả), `pantry` (Gạo, bún & gia vị) |
| `exercises[].muscle_group` | `legs`, `chest`, `back`, `core`, `shoulders`, `arms`, `full_body`, `cardio` |
| `exercises[].tags` | `jumping` (bật nhảy), `kneeling` (quỳ, chống gối), `wrist_load` (chống tay), `back_load` (tải lên lưng), `overhead` (đưa tay qua đầu) |

Server chịu trách nhiệm:

* **Kiểm tra** mọi plan (từ Gemini hay thực đơn mẫu) theo NFR-4 trước khi trả về.
* **Gán ID:** `plan_id` là UUID; `meal_id` = `m{ngày}_{thứ tự bữa}`; `exercise_id` = `e{ngày}_{thứ tự động tác}`.
* **Tính `grocery_list`** từ `ingredients` của mọi món: gộp theo nhóm + tên + đơn vị, cộng `amount`; `source_meal_ids` là các món dùng nguyên liệu đó. Cùng nguyên liệu nhưng khác đơn vị (ví dụ `tbsp` và `tsp`) nằm ở hai dòng riêng.
````

### Task 7 — Mục 6.4 (thêm sau 6.3)

Thêm ngay sau khối 6.3 (trước `---` của mục 7):

````
### 6.4. Đổi món, đổi bài tập, feedback (bổ sung bản 2.3.0, triển khai ở giai đoạn 4 của `docs/PLAN.md`)

Ba endpoint này nhận **toàn bộ plan hiện tại** và trả về **toàn bộ plan mới** (cùng cấu trúc 6.2), nên Flutter chỉ việc thay plan đang lưu và backend không cần lưu trạng thái. `profile` có cùng cấu trúc với request 6.1: server dùng nó để tránh dị ứng/chấn thương và **tự tính lại BMR** — không tin số `bmr` trong plan gửi lên.

| Endpoint | Request | Response |
|---|---|---|
| `POST /api/v1/meals/swap` (FR-4.1) | `{ "profile": {…}, "plan": {…}, "meal_id": "m1_2" }` | `{ "plan": {…} }` |
| `POST /api/v1/exercises/swap` (FR-4.2) | `{ "profile": {…}, "plan": {…}, "exercise_id": "e1_3" }` | `{ "plan": {…} }` |
| `POST /api/v1/feedback` (FR-5) | `{ "profile": {…}, "plan": {…}, "day_number": 1, "intensity": "hard", "body_states": ["sore"], "eating": "over" }` | `{ "plan": {…}, "safety_warning": null }` |

Giá trị cho feedback:

* `intensity`: `easy` (Nhẹ nhàng) / `moderate` (Vừa sức) / `hard` (Rất mệt)
* `body_states` (ít nhất 1): `normal`, `sore` (căng mỏi cơ), `joint_pain` (đau khớp), `fatigued` (uể oải, thiếu ngủ), `danger_sign` (chóng mặt, khó thở bất thường, đau ngực). Chọn `normal` cùng trạng thái khác thì `normal` bị bỏ qua.
* `eating`: `on_plan` / `over` (ăn nhiều hơn) / `under` (ăn ít hơn hoặc bỏ bữa)
* `day_number` 1–2 → điều chỉnh ngày kế tiếp trong plan; `day_number` 3 → trả plan 3 ngày mới với `plan_id` mới (FR-5.3).
* Có `danger_sign` → `safety_warning` = `{ "message": "…" }`; ngày kế tiếp (hoặc ngày 1 của plan mới) chỉ nghỉ hoặc đi bộ nhẹ. Không có → `safety_warning` = `null`.
````

### Task 8 — Mục 7

Thêm vào cuối NFR-1 (sau bullet hiệu ứng chờ):

```
   * Mỗi lần gọi Gemini có giới hạn thời gian (mặc định 15 giây, cấu hình qua `GEMINI_TIMEOUT_MS`). Hết giờ thì dùng ngay thực đơn mẫu, không gọi lại, để người dùng không phải chờ quá lâu.
```

Thay bullet thứ hai của NFR-2:

```
   * Cung cấp sẵn một file `sample_plan.json` dự phòng để phục vụ việc demo thuyết trình trơn tru ngay cả khi mạng trường bị yếu.
```

bằng:

```
   * Có sẵn thực đơn mẫu 3 ngày (`backend_api/src/plan/data/sample-plan.json`) để demo trơn tru ngay cả khi chưa có khoá Gemini hoặc mạng trường yếu. Response luôn có trường `source` (`gemini` / `sample`) để app biết đang hiển thị dữ liệu nào.
```

Thay toàn bộ NFR-4 bằng:

```
4. **Độ tin cậy dữ liệu dinh dưỡng (Nutrition Data Sanity Check):**
   * Gemini có thể "bịa" calo/macro không nhất quán. Mọi kết quả Gemini (và cả thực đơn mẫu) phải qua cùng một bộ kiểm tra trước khi trả cho Flutter:
     * đúng cấu trúc mục 6.2, kiểm bằng `class-validator` — giá trị ngoài danh sách mã cố định bị coi là sai, không được bỏ qua;
     * calo từng bữa trong khoảng hợp lý: Bữa sáng 250–600 kcal, Bữa trưa/tối 400–800 kcal;
     * calo khai báo lệch không quá 15% so với 4 × protein + 4 × carbs + 9 × fat;
     * không trùng tên món trong 3 ngày.
   * Không đạt thì gọi lại Gemini (tối đa 1 lần), sau đó dùng thực đơn mẫu, thay vì hiển thị số liệu sai cho người dùng.
```

Thêm sau NFR-6 (trước `---` của mục 8):

```
7. **Quyền riêng tư dữ liệu sức khoẻ (bổ sung bản 2.3.0):**
   * Dị ứng, chấn thương, tình trạng sức khoẻ là dữ liệu cá nhân nhạy cảm (Nghị định 13/2023/NĐ-CP). Chúng chỉ lưu trên máy người dùng, gửi kèm từng request rồi bỏ đi: backend không ghi vào database, không ghi log nội dung request hay nội dung Gemini trả về.
   * Plan lưu trong lịch sử (FR-7) không chứa các trường này.
8. **Chống prompt injection (bổ sung bản 2.3.0):** Văn bản tự do của người dùng được đặt trong một khối dữ liệu có thẻ phân cách, bỏ ký tự `<` `>` và xuống dòng, giới hạn 300 ký tự mỗi ô; prompt dặn Gemini coi khối này là dữ liệu, không phải chỉ dẫn. Đầu ra vẫn phải qua bộ kiểm tra ở NFR-4, nên dù bị chèn lệnh cũng không làm hỏng app.
9. **Khuyến cáo y tế (bổ sung bản 2.3.0):** Onboarding ghi rõ gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Khi người dùng có khai tình trạng sức khoẻ, hoặc khi calo mục tiêu phải nâng lên bằng BMR, response có câu giải thích trong `warnings` để app hiển thị.
```

### Task 9 — Kiểm tra

```bash
python3 -c "import re,json; blocks=re.findall(r'\`\`\`json\n(.*?)\n\`\`\`', open('BRD.md').read(), re.S); [json.loads(b) for b in blocks]; print(len(blocks), 'json blocks ok')"
grep -n "sample_plan.json\|\"allergies\": \[" BRD.md
```

Kết quả mong đợi: dòng đầu in `5 json blocks ok` (6.1: 1 khối, 6.2: 1 khối, 6.3: 3 khối; 6.4 dùng bảng); lệnh `grep` không in gì.
