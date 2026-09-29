---
last_updated: 2026-09-27
tags: [hop-dong-api, backend, dinh-duong]
---

# Hợp đồng dữ liệu plan

Plan 3 ngày đi qua một đường duy nhất trong `backend_api/src/plan/`. Gemini (hoặc thực đơn mẫu) chỉ sinh nội dung món ăn và bài tập; server kiểm tra nội dung đó theo hợp đồng, tự tính mục tiêu calo, gán ID và tính danh sách đi chợ. Hợp đồng gốc là BRD.md mục 6 (v2.5.0); bài này ghi code nằm ở đâu và vì sao được chia như vậy. Ràng buộc liên quan: [[critical-constraints]] #2, #6, #7, #12, #13, #15, #16, #23. Đổi món, đổi bài, feedback: [[swap-and-feedback]].

## Luồng `POST /api/v1/generate-plan`

1. `CreatePlanDto` (`dto/create-plan.dto.ts`) validate request. `restrictions` là ba chuỗi tự do tối đa 300 ký tự, mặc định rỗng. Từ v2.6.0: tuổi 18–100, `pregnant_or_breastfeeding` (chỉ nữ), và `goal = cut` bị từ chối khi thiếu cân hoặc mang thai (mục "Hồ sơ an toàn" dưới).
2. `computeDailyTarget()` (`daily-target.ts`) → BMI, BMR, TDEE, mục tiêu calo có sàn BMR, macro 25/45/30.
3. Có `GEMINI_API_KEY` → `GeminiService.generatePlanContent()` trả JSON thô (chỉ `days`). Không có → bỏ qua bước này.
4. `parsePlanContent(raw, target)` (`plan-validation.ts`) → class-validator + `findPlanViolations()`; rồi `findRestrictionViolations()` (có nguyên liệu dị ứng đã nhận ra → sai hợp đồng). Sai → `generateWithRetry()` gọi lại 1 lần (trừ khi hết giờ) → thực đơn mẫu `data/sample-plan.json`: lọc theo hạn chế nhận ra (`filterPlanByRestrictions()`), nhân khẩu phần từng ngày cho khớp mục tiêu (`scaleMealsToTotal()`), rồi qua đúng bước kiểm tra này. Cuối cùng hạ mức động tác theo hồ sơ (`capWorkoutLevel()`) — cho cả kết quả Gemini (không gọi lại) lẫn thực đơn mẫu.
5. `assemblePlan()` (`plan-assembly.ts`) → `plan_id` (hoặc giữ `plan_id` cũ khi đổi món/feedback), ID món và động tác, sắp bữa, `buildGroceryList()`.
6. `warnings` (`plan-warnings.ts`): sàn BMR, khuyến cáo y tế, mang thai / cho con bú, thực đơn mẫu chỉ lọc theo từ khoá, hạn chế chưa nhận ra hết. Không câu nào nhắc lại chữ người dùng nhập.

## Hồ sơ an toàn và mức động tác (BRD v2.6.0)

| Luật | Code |
|---|---|
| Tuổi 18–100 | `MIN_AGE`, `MAX_AGE` trong `profile-safety.ts`, dùng ở `@Min`/`@Max` của `CreatePlanDto` |
| `goal = cut` bị từ chối khi BMI **chưa làm tròn** < 18,5 hoặc `pregnant_or_breastfeeding` | `cutBlockReason()` (`profile-safety.ts`) qua `SafeGoalConstraint` (`dto/profile-safety.validator.ts`) — 400 kèm câu tiếng Việt |
| `pregnant_or_breastfeeding = true` chỉ khi `gender = female` | `PregnancyNeedsFemaleConstraint` |
| Mức động tác tối đa: ≥ 60 tuổi, ≥ 45 + ít vận động, mang thai → 1; vận động nhiều + < 45 → 3; còn lại → 2 | `maxExerciseLevel()` (`exercise-level.ts`) |

Validator nằm trên `CreatePlanDto` nên áp cho cả 4 endpoint nhận hồ sơ (`generate-plan` và ba endpoint của [[swap-and-feedback]]). App khoá lựa chọn theo đúng các ngưỡng này (`frontend_app/lib/models/profile_rules.dart`, [[flutter-ui]]). Ràng buộc: [[critical-constraints]] #30, #31.

`capWorkoutLevel(plan, maxLevel, avoidTags)` thay động tác vượt mức bằng động tác trong kho cùng nhóm cơ, mức ≤ giới hạn, không vướng chấn thương, giữ số hiệp — tất định. Động tác không có trong kho (Gemini tự đặt) chỉ bị coi là vượt mức khi giới hạn là 1 và có tag `jumping`. Nhóm cơ nào cũng có động tác mức 1 không tag (`exercise-level.spec.ts` kiểm), nên hạ mức không làm rỗng buổi tập. Prompt ghi luật bằng `exerciseLevelRule()`, dựng từ chính kho.

## Hai lớp DTO

| File | Dùng cho |
|---|---|
| `dto/plan-content.dto.ts` | Nội dung Gemini / thực đơn mẫu sinh ra: `PlanContentDto` → `DayContentDto` → `MealContentDto`, `IngredientDto`, `WorkoutContentDto`, `ExerciseContentDto`. Không có ID, không có danh sách đi chợ. |
| `dto/meal-plan-response.dto.ts` | Plan hoàn chỉnh server trả về, Swagger hiển thị: `MealPlanResponseDto`. `MealDto` và `ExerciseDto` kế thừa lớp nội dung và thêm ID. Cũng dùng để validate plan client gửi lên khi đổi món, đổi bài, feedback (`AdjustPlanDto`, [[swap-and-feedback]]). |

Tách hai lớp vì Gemini càng phải viết ít trường thì càng ít chỗ để sai: ID và danh sách đi chợ server tự làm được, nên không bắt Gemini sinh.

## Khoảng calo (BRD NFR-4, v2.5.0)

| Kiểm | Khoảng |
|---|---|
| Bữa sáng | 15–35% `target_calories` |
| Bữa trưa, bữa tối | 25–45% `target_calories` |
| Tổng một ngày | max(85% `target_calories`, BMR) – 110% `target_calories` |

`mealCalorieBounds()`, `dayCalorieBounds()` tính các khoảng này; prompt Gemini đọc cùng hàm. Thực đơn mẫu (soạn cho ~1550 kcal/ngày) và món trong kho được nhân khẩu phần bằng `meal-scaling.ts` — calo, macro, lượng nguyên liệu cùng một hệ số, nên calo vẫn khớp 4P+4C+9F và tỉ lệ đạm/tinh bột/béo của món không đổi. Macro của từng món ước từ nguyên liệu sống (giá trị dinh dưỡng phổ biến trên 100 g, làm tròn — chưa đối chiếu Bảng thành phần thực phẩm Việt Nam), khẩu phần cơm/đạm/dầu chỉnh để cả ngày gần 25/45/30 (sửa ngày 2026-09-27; trước đó ~24/53/23).

## Mã cố định (`enums/`)

`meal-type.enum.ts` (breakfast, lunch, dinner) · `ingredient.enum.ts` (nhóm protein / produce / pantry; đơn vị g, ml, piece, tbsp, tsp) · `exercise.enum.ts` (nhóm cơ; tag jumping, kneeling, knee_bend — từ v2.7.0, wrist_load, back_load, overhead; tag suy từ tên động tác luôn được thêm — #34) · `plan-source.enum.ts` (gemini, sample). Prompt Gemini đọc danh sách mã từ các enum này, nên thêm mã ở enum thì prompt tự cập nhật theo.

## Danh sách đi chợ

Gộp theo nhóm + tên (không phân biệt hoa thường, khoảng trắng — `normalizeKey()` trong `text.util.ts`) + đơn vị. Khác đơn vị thì thành hai dòng. `quantity` là chuỗi hiển thị (`540g`, `×4`, `3 muỗng canh`).

## Test

Mỗi file có `*.spec.ts` đặt cạnh trong `src/plan/`; chạy `cd backend_api && npm test`. `sample-plan.spec.ts` bảo đảm thực đơn mẫu luôn đúng hợp đồng và mỗi ngày gần tỉ lệ năng lượng 25/45/30 (lệch ≤ 3 điểm, cả khi món vướng dị ứng được thay — #33).
