---
last_updated: 2026-09-24
tags: [hop-dong-api, backend, dinh-duong]
---

# Hợp đồng dữ liệu plan

Plan 3 ngày đi qua một đường duy nhất trong `backend_api/src/plan/`. Gemini (hoặc thực đơn mẫu) chỉ sinh nội dung món ăn và bài tập; server kiểm tra nội dung đó theo hợp đồng, tự tính mục tiêu calo, gán ID và tính danh sách đi chợ. Hợp đồng gốc là BRD.md mục 6 (v2.3.0); bài này ghi code nằm ở đâu và vì sao được chia như vậy. Ràng buộc liên quan: [[critical-constraints]] #2, #6, #7, #12, #13, #15, #16.

## Luồng `POST /api/v1/generate-plan`

1. `CreatePlanDto` (`dto/create-plan.dto.ts`) validate request. `restrictions` là ba chuỗi tự do tối đa 300 ký tự, mặc định rỗng.
2. `computeDailyTarget()` (`daily-target.ts`) → BMI, BMR, TDEE, mục tiêu calo có sàn BMR, macro 25/45/30.
3. Có `GEMINI_API_KEY` → `GeminiService.generatePlanContent()` trả JSON thô (chỉ `days`). Không có → bỏ qua bước này.
4. `parsePlanContent()` (`plan-validation.ts`) → class-validator + `findPlanViolations()`. Sai → gọi lại 1 lần (trừ khi hết giờ) → thực đơn mẫu `data/sample-plan.json`, cũng qua đúng bước kiểm tra này.
5. `assemblePlan()` (`plan-assembly.ts`) → `plan_id`, ID món và động tác, sắp bữa, `buildGroceryList()`.
6. `warnings` (`plan-warnings.ts`): sàn BMR, khuyến cáo y tế, thực đơn mẫu chưa lọc hạn chế.

## Hai lớp DTO

| File | Dùng cho |
|---|---|
| `dto/plan-content.dto.ts` | Nội dung Gemini / thực đơn mẫu sinh ra: `PlanContentDto` → `DayContentDto` → `MealContentDto`, `IngredientDto`, `WorkoutContentDto`, `ExerciseContentDto`. Không có ID, không có danh sách đi chợ. |
| `dto/meal-plan-response.dto.ts` | Plan hoàn chỉnh server trả về, Swagger hiển thị: `MealPlanResponseDto`. `MealDto` và `ExerciseDto` kế thừa lớp nội dung và thêm ID. Giai đoạn 4 dùng chính các lớp này để validate plan client gửi lên. |

Tách hai lớp vì Gemini càng phải viết ít trường thì càng ít chỗ để sai: ID và danh sách đi chợ server tự làm được, nên không bắt Gemini sinh.

## Mã cố định (`enums/`)

`meal-type.enum.ts` (breakfast, lunch, dinner) · `ingredient.enum.ts` (nhóm protein / produce / pantry; đơn vị g, ml, piece, tbsp, tsp) · `exercise.enum.ts` (nhóm cơ; tag jumping, kneeling, wrist_load, back_load, overhead) · `plan-source.enum.ts` (gemini, sample). Prompt Gemini đọc danh sách mã từ các enum này, nên thêm mã ở enum thì prompt tự cập nhật theo.

## Danh sách đi chợ

Gộp theo nhóm + tên (không phân biệt hoa thường, khoảng trắng — `normalizeKey()` trong `text.util.ts`) + đơn vị. Khác đơn vị thì thành hai dòng. `quantity` là chuỗi hiển thị (`540g`, `×4`, `3 muỗng canh`).

## Test

Mỗi file có `*.spec.ts` đặt cạnh trong `src/plan/`; chạy `cd backend_api && npm test`. `sample-plan.spec.ts` bảo đảm thực đơn mẫu luôn đúng hợp đồng.
