# Brainstorm: Giai đoạn 1 — Chốt hợp đồng API
**Source:** `docs/PLAN.md` (giai đoạn 1, bước 1.1–1.4) + `BRD.md` v2.2.0 (nguồn yêu cầu gốc)
**Date:** 2026-09-24

## 1. Phạm vi

Giai đoạn 1 phải đưa ra một hợp đồng API đầy đủ trong BRD mục 6, để frontend (giai đoạn 5–8) chỉ việc bám theo:

- Áp dụng D1–D4 vào BRD, nâng lên v2.3.0 (bước 1.1)
- Thêm BRD mục 6.4 cho đổi món, đổi bài tập, feedback (bước 1.2)
- Sửa backend cho khớp: DTO, interface, `GOAL_CALORIE_ADJUSTMENT`, prompt, `sample-plan.json` đủ 3 ngày (bước 1.3)
- Thêm ràng buộc mới vào wiki (bước 1.4)

**Đây là thời điểm rẻ nhất để đổi hợp đồng:** Flutter chưa có lớp gọi mạng nào (`pubspec.yaml` chưa có `http`), nên đổi schema bây giờ không làm hỏng client nào.

## 2. Ngữ cảnh đã nạp

- Wiki: `INDEX.md`, `wiki-triggers.md`, `critical-constraints.md` (đủ 11 ràng buộc), `reference-materials.md`.
- Điều kiện nạp ràng buộc: **có** — yêu cầu sửa endpoint và prompt gửi tới Gemini (dịch vụ bên ngoài).
- **Lỗ hổng wiki:** từ khoá trong yêu cầu khớp 5 bài `plan-data-contract.md`, `gemini-integration.md`, `api-routes.md`, `flutter-ui.md`, `product-spec.md`, nhưng cả 5 bài và bài dự phòng `project-architecture.md` đều chưa tồn tại. Không chặn giai đoạn này, nhưng nên viết ít nhất `plan-data-contract.md` ngay sau khi hợp đồng chốt, vì nó chính là nội dung giai đoạn 1 tạo ra.
- Code: `create-plan.dto.ts`, `restrictions.dto.ts`, `goal.enum.ts`, `plan.interface.ts`, `nutrition-sanity.util.ts`, `gemini.service.ts` (`buildPrompt`), `plan.service.ts`; phía Flutter: `dashboard_screen.dart`, `grocery_screen.dart`, `onboarding_screen.dart`, `widget_test.dart`.

## 3. Phát hiện từ code và tài liệu

| # | Phát hiện | Nguồn |
|---|---|---|
| F1 | **Mâu thuẫn BRD ↔ code.** Sơ đồ BRD mục 4 ghi "class-validator kiểm tra tính hợp lệ JSON" với kết quả Gemini, nhưng code chỉ làm `JSON.parse(text) as MealPlanResponse` rồi kiểm khoảng calo. Kết quả thiếu trường hay sai kiểu vẫn đi thẳng tới Flutter. | `gemini.service.ts`, `plan.service.ts` |
| F2 | **Kiểm tra calo bị bỏ qua âm thầm.** `CALORIE_BOUNDS` tra theo chuỗi `'Bữa sáng'`, `'Bữa trưa'`, `'Bữa tối'`. Nếu Gemini trả `"Sáng"` hay `"bữa sáng"` thì `if (!bounds) return true` cho qua luôn — trái với ý định của ràng buộc #2. | `nutrition-sanity.util.ts` |
| F3 | **Chế độ giả lập bỏ qua dị ứng.** Fallback trả plan mẫu cố định bất kể người dùng khai gì: người dị ứng hải sản vẫn nhận "Cá hấp hành gừng". App không nhận được tín hiệu nào để cảnh báo. | `plan.service.ts` `loadSamplePlan()` |
| F4 | **Calo mục tiêu có thể thấp hơn BMR ngay cả với D1.** Nữ, 45 kg, 150 cm, 22 tuổi, ít vận động: BMR ≈ 1117, TDEE ≈ 1340, giảm mỡ −300 → 1040 kcal < BMR. Quy tắc "không dưới BMR" hiện mới chỉ ghi cho feedback (PLAN 4.4). | `computeDailyTarget()` |
| F5 | `plan_id`, `meal_id`, `exercise_id` do Gemini tự đặt, không có gì đảm bảo duy nhất; `source_meal_ids` có thể trỏ tới id không tồn tại. Lịch sử (FR-7) cần `plan_id` do server cấp. | `plan.interface.ts`, prompt |
| F6 | **`grocery_list` và nguyên liệu từng món do Gemini sinh riêng rẽ**, nên có thể lệch nhau ngay từ khi tạo plan, chưa cần tới đổi món. | prompt, BRD 6.2 |
| F7 | Tên nhóm nguyên liệu có 3 phiên bản khác nhau: BRD FR-3.1 (Rau củ / Thịt trứng / Gia vị), BRD 6.2 (Thịt & Thủy hải sản / Rau củ quả / Lương thực & Gia vị), Flutter (THỊT & THỦY HẢI SẢN / RAU CỦ QUẢ / GIA VỊ & NGUYÊN LIỆU KHÁC — gạo nằm trong nhóm gia vị). | BRD, `grocery_screen.dart` |
| F8 | Món ăn chỉ có `calories` và `protein_g`. FR-2.3 yêu cầu phân bổ Protein/Carbs/Fat theo ngày, nên cần thêm `carbs_g`, `fat_g`; có đủ thì còn kiểm tra chéo được `calories ≈ 4P + 4C + 9F` để bắt số liệu bịa. | `plan.interface.ts`, BRD FR-2.3 |
| F9 | `target_muscle` là văn bản tự do ("Đùi & Mông"). Quy tắc D2 (căng mỏi cơ → giảm hiệp nhóm cơ đó; đau khớp → bỏ bật nhảy, chống quỳ) và đổi bài "cùng nhóm cơ" (FR-4.2) không so khớp được bằng code. | `plan.interface.ts` |
| F10 | Swagger không hiển thị schema response, vì `MealPlanResponse` là interface TypeScript (không có metadata lúc chạy). Frontend sẽ phải đọc BRD thay vì Swagger. | `plan.controller.ts` |
| F11 | *(Ngoài phạm vi)* `frontend_app/test/widget_test.dart` **đang fail sẵn**: test tìm chữ "MỤC TIÊU HÔM NAY" không còn trong giao diện sau commit 445864b. Widget `MacroRing` có nhưng không được dùng ở đâu. Xử lý ở PLAN 5.6. | `flutter test` |
| F12 | BRD NFR-2 gọi file dự phòng là `sample_plan.json`; file thật tên `sample-plan.json`. | BRD mục 7 |

## 4. Ràng buộc liên quan (từ `critical-constraints.md`)

| # | Ràng buộc | Tác động lên giai đoạn 1 |
|---|---|---|
| 1 | Hệ số vận động 1.2 / 1.375 / 1.55 | Giữ nguyên |
| 2 | Khoảng calo theo bữa, retry 1 lần rồi fallback | F2 phải sửa: khoá tra cứu phải là mã cố định, giá trị lạ phải **không đạt** thay vì cho qua |
| 4 | ESM — import tương đối phải có đuôi `.js` | Mọi file DTO mới |
| 5 | File không phải `.ts` dưới `src/` phải khai báo trong `nest-cli.json` | `sample-plan.json` đã có; nếu thêm file JSON mới phải khai báo |
| 6 | Không lặp tên món trong 3 ngày | Plan mẫu 3 ngày phải tuân thủ; nên kiểm bằng code thay vì chỉ dặn trong prompt |
| 7 | Đồng bộ danh sách đi chợ theo `source_meal_ids` khi đổi món | Nếu chọn hướng B (mục 5), quy tắc cập nhật từng phần này được thay bằng "tính lại toàn bộ" — cần viết lại ràng buộc #7 |
| 8, 9 | SDK `@google/genai`, model `gemini-3.8-flash` | Giữ nguyên |

Ràng buộc #3, #10, #11 không thuộc giai đoạn này.

## 5. Các hướng tiếp cận

### Hướng A — Áp dụng đúng chữ D1–D4, giữ cấu trúc hiện tại

Đổi hằng số calo, `restrictions` thành 3 chuỗi, thêm `quantity` và nhóm cố định cho nguyên liệu đi chợ; Gemini vẫn tự sinh `grocery_list`; thêm schema mục 6.4.

- **Ưu:** nhanh, đúng kích thước S như plan.
- **Nhược:** không giải quyết F1–F10. Kiểm tra calo vẫn bị bỏ qua được (vi phạm ý định ràng buộc #2), danh sách đi chợ vẫn có thể lệch món, và giai đoạn 4 thiếu dữ liệu có cấu trúc để viết quy tắc feedback và đổi bài bằng code — sẽ phải sửa hợp đồng lần nữa.

### Hướng B — Server làm chủ dữ liệu có cấu trúc *(khuyến nghị)*

- **Nguyên liệu từng món có cấu trúc:** `{ name, amount, unit, category }`, với `category` ∈ `protein | produce | pantry`.
- **`grocery_list` do server tính** từ nguyên liệu mọi món: gộp theo nhóm + tên + đơn vị, cộng `amount`; `source_meal_ids` là các món dùng nguyên liệu đó; `quantity` hiển thị = amount + unit (đúng D3). Gemini không sinh `grocery_list` nữa.
- **Đổi món / feedback:** thay món rồi tính lại `grocery_list`, nên danh sách luôn khớp thực đơn. Quy tắc cập nhật từng phần ở ràng buộc #7 được thay bằng một hàm tính lại.
- **Mã cố định cho mọi trường mà code dựa vào:** `meal_type` ∈ `breakfast | lunch | dinner`; `muscle_group` ∈ `legs | chest | back | core | shoulders | arms | full_body | cardio`; `tags` của động tác (ví dụ `jumping`, `kneeling`, `wrist_load`). Nhãn tiếng Việt do Flutter hiển thị.
- **Món có thêm `carbs_g`, `fat_g`;** kiểm tra chéo `calories ≈ 4P + 4C + 9F` (lệch quá 15% coi như số liệu sai → retry).
- **Server cấp `plan_id` (UUID)** và chuẩn hoá `meal_id` / `exercise_id` theo mẫu `m{ngày}_{thứ tự}`.
- **Response có `source` (`"gemini" | "sample"`) và `warnings`.** Ví dụ khi fallback: "Dữ liệu mẫu chưa được lọc theo dị ứng của bạn" (F3).
- **`daily_target` có thêm `bmr`, `tdee`;** `target_calories = max(TDEE + điều chỉnh, BMR)` (F4). Các endpoint sau đọc `bmr` từ plan để giữ sàn calo mà không cần gửi lại hồ sơ sức khoẻ.
- **Response là class DTO có `class-validator`.** Cùng một bộ validator kiểm cả kết quả Gemini lẫn `sample-plan.json`, và Swagger hiện được schema (F1, F10).
- **Mọi endpoint làm thay đổi plan** (đổi món, đổi bài, feedback) nhận **toàn bộ plan hiện tại** + id cần đổi + `restrictions`, và trả về **toàn bộ plan mới**. Flutter chỉ việc thay plan đang lưu; backend vẫn stateless.

- **Ưu:** giải quyết F1–F10. Giai đoạn 4 có đủ trường có cấu trúc để viết quy tắc feedback và đổi bài bằng code, nên chế độ giả lập vẫn đổi bài/feedback đúng mà không cần Gemini.
- **Nhược:**
  - Giai đoạn 1 lớn lên từ S thành M.
  - Gemini phải trả thêm trường có cấu trúc (`amount`, `unit`, `tags`…), prompt dài hơn và nhiều chỗ để sai hơn. Nhưng sai thì validator bắt được → retry/fallback, không lọt tới app.
  - Cộng khối lượng chỉ chính xác khi cùng đơn vị: "1 quả trứng" và "100 g trứng" sẽ thành hai dòng.

### Hướng C — Dùng Zod/JSON Schema làm nguồn hợp đồng duy nhất

Như hướng B, nhưng định nghĩa schema bằng Zod, từ đó sinh `responseSchema` cho Gemini, dùng để validate, và (qua thư viện) sinh Swagger.

- **Ưu:** một nguồn schema; Gemini bị ép đúng cấu trúc ngay từ API nên ít phải retry.
- **Nhược:** lệch lựa chọn `class-validator` trong BRD mục 4; thêm thư viện; request dùng `class-validator` còn response dùng Zod — hai kiểu validate song song trong cùng dự án, khó cho sinh viên. `responseSchema` vẫn thêm được ở bước 4.6 mà không cần đổi nguồn schema.

## 6. Khuyến nghị: Hướng B

Frontend chưa gọi API nào, nên đổi hợp đồng bây giờ không tốn gì phía client. Còn nếu chọn hướng A, giai đoạn 4 (quy tắc feedback D2, đổi bài theo nhóm cơ, đổi món trong chế độ giả lập) sẽ buộc phải sửa hợp đồng lần hai, lúc đó BRD mục 6 phải viết lại. Hướng C mang lại lợi ích thật (Gemini bị ép cấu trúc) nhưng giá là hai hệ validate song song; phần lợi ích đó lấy được ở bước 4.6 mà không phải trả giá này.

## 7. Phác thảo hợp đồng theo hướng B

Để `/feature-plan` chi tiết hoá. Số liệu dưới đây tính đúng theo `computeDailyTarget()` với D1: nữ, 22 tuổi, 168 cm, 62 kg, vận động nhẹ, giảm mỡ.

`POST /api/v1/generate-plan` — request:

```json
{
  "age": 22, "gender": "female", "height_cm": 168, "weight_kg": 62,
  "activity_level": "light", "goal": "cut",
  "restrictions": { "allergies": "Hải sản", "injuries": "Đau gối", "health_conditions": "" }
}
```

Response (rút gọn — 1 món, 1 động tác):

```json
{
  "plan_id": "3f1c…-uuid",
  "source": "gemini",
  "warnings": [],
  "daily_target": { "bmr": 1399, "tdee": 1924, "target_calories": 1624, "protein_g": 102, "carbs_g": 183, "fat_g": 54 },
  "days": [
    {
      "day_number": 1,
      "meals": [
        {
          "meal_id": "m1_1", "meal_type": "breakfast", "name": "Bún thịt bò nạc", "portion": "1 tô vừa",
          "calories": 420, "protein_g": 25, "carbs_g": 55, "fat_g": 10,
          "ingredients": [
            { "name": "Bún tươi", "amount": 150, "unit": "g", "category": "pantry" },
            { "name": "Thịt bò nạc", "amount": 70, "unit": "g", "category": "protein" }
          ]
        }
      ],
      "workout": {
        "title": "Vận động toàn thân tại nhà", "duration_minutes": 20,
        "exercises": [
          { "exercise_id": "e1_1", "name": "Squat tay không", "sets": 3, "reps_or_duration": "12-15 lần", "muscle_group": "legs", "tags": [] }
        ]
      }
    }
  ],
  "grocery_list": [
    { "category": "protein", "items": [ { "name": "Thịt bò nạc", "quantity": "70g", "source_meal_ids": ["m1_1"] } ] }
  ]
}
```

Kiểm tra chéo món mẫu: 4×25 + 4×55 + 9×10 = 410 kcal, so với 420 kcal khai báo lệch 2,4% → đạt.

`day_name` bị bỏ vì Flutter tự hiển thị "Ngày {day_number}" được — bớt một trường để Gemini làm sai.

Mục 6.4 — các endpoint làm thay đổi plan:

| Endpoint | Request | Response |
|---|---|---|
| `POST /api/v1/meals/swap` | `{ plan, meal_id, restrictions }` | `{ plan }` |
| `POST /api/v1/exercises/swap` | `{ plan, exercise_id, restrictions }` | `{ plan }` |
| `POST /api/v1/feedback` | `{ plan, day_number, intensity: "easy" \| "moderate" \| "hard", body_states: ("normal" \| "sore" \| "joint_pain" \| "fatigued" \| "danger_sign")[], eating: "on_plan" \| "over" \| "under", restrictions }` | `{ plan, safety_warning: null \| { message } }` |

## 8. Edge case

- **Kết quả Gemini sai hợp đồng** (thiếu trường, mã ngoài danh sách, không đủ 3 ngày, calo lệch khi kiểm chéo) → retry 1 lần → dùng plan mẫu, như luồng NFR-4 hiện tại nhưng kiểm rộng hơn.
- **Chính `sample-plan.json` lệch hợp đồng** sau này → cần unit test chạy cùng validator trên file mẫu.
- **Prompt injection qua ô nhập tự do:** bọc văn bản trong một khối dữ liệu có dấu phân cách, xoá dấu phân cách nếu người dùng tự gõ vào, giới hạn 300 ký tự. Validate cấu trúc đầu ra giới hạn thiệt hại tệ nhất ở mức "món ăn kỳ lạ", không làm hỏng app.
- **Ô nhập rỗng hoặc chỉ có khoảng trắng** → coi như "không có".
- **Dữ liệu sức khoẻ:** không ghi log request body; plan trả về không chứa `restrictions`, nên khi làm lịch sử (giai đoạn 3) `PlanRecord` chỉ lưu plan, không vô tình lưu thông tin sức khoẻ.
- **Feedback:**
  - Chọn "normal" cùng trạng thái khác → bỏ qua "normal".
  - `danger_sign` được ưu tiên hơn mọi quy tắc khác.
  - Mức "easy" chỉ tăng tối đa +1 hiệp và có trần số hiệp.
- **Feedback cho ngày 3** (không còn ngày kế tiếp) → xem câu hỏi mở Q2.
- **Client gửi lên plan đã bị sửa tay** (ví dụ `bmr` thấp đi) → chỉ ảnh hưởng chính người đó (không có dữ liệu của người khác), nhưng server vẫn chạy validator trên plan đầu vào.
- **Gemini treo:** hiện chưa đặt timeout cho lời gọi Gemini; một lần retry có thể kéo request lên >12 giây. Nên đặt timeout cho mỗi lần gọi khi sửa `gemini.service.ts`.

## 9. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **Chọn hướng B?** (khuyến nghị) Giai đoạn 1 sẽ lớn lên từ S thành M.
2. **Feedback ngày 3** — (a) chỉ ghi nhận, gợi ý người dùng tạo plan mới; hay (b) tự tạo plan 3 ngày mới có tính tới feedback (cuốn chiếu đúng nghĩa)?
3. **3 nhóm nguyên liệu:** `protein` (thịt, cá, trứng, đậu phụ, sữa) / `produce` (rau, củ, quả) / `pantry` (gạo, bún, mì, gia vị, dầu ăn) — đồng ý?
4. **Sàn BMR** áp cho cả `generate-plan` (F4), không chỉ feedback?

## 10. Quyết định (2026-09-24)

| Câu hỏi | Quyết định |
|---|---|
| Q1 | **Hướng B.** Giai đoạn 1 nâng từ S lên M. |
| Q2 | **Feedback ngày 3 tự tạo plan 3 ngày mới**, có tính tới feedback. Nếu có dấu hiệu nguy hiểm, ngày 1 của plan mới chỉ nghỉ hoặc đi bộ nhẹ, kèm `safety_warning`. Ở chế độ giả lập, plan mới lấy từ dữ liệu mẫu (có thể trùng món chu kỳ trước — ghi vào `warnings`) nhưng quy tắc điều chỉnh bài tập vẫn áp dụng. |
| Q3 | **`protein` / `produce` / `pantry`** như đề xuất. |
| Q4 | **Áp sàn BMR cho cả `generate-plan`:** `target_calories = max(TDEE + điều chỉnh, BMR)`; khi sàn được áp, thêm một dòng vào `warnings` để app giải thích. |

**Điều chỉnh hợp đồng kéo theo Q2:** feedback ngày 3 cần hồ sơ người dùng để tạo plan mới, nên cả ba endpoint làm thay đổi plan đều nhận `profile` — cùng cấu trúc với request của `generate-plan` (gồm cả `restrictions`) — thay cho `restrictions` riêng lẻ:

| Endpoint | Request | Response |
|---|---|---|
| `POST /api/v1/meals/swap` | `{ profile, plan, meal_id }` | `{ plan }` |
| `POST /api/v1/exercises/swap` | `{ profile, plan, exercise_id }` | `{ plan }` |
| `POST /api/v1/feedback` | `{ profile, plan, day_number, intensity, body_states, eating }` | `{ plan, safety_warning }` |

Server luôn tự tính lại BMR từ `profile`; trường `daily_target.bmr` trong plan chỉ để hiển thị, không được tin khi áp sàn calo. Hồ sơ vẫn chỉ gửi kèm từng request, không lưu ở server (D4).

**Bước tiếp theo:** `/feature-plan phase-1-api-contract`.
