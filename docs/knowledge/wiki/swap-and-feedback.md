---
last_updated: 2026-09-24
tags: [doi-mon, doi-bai-tap, feedback, di-ung, kho-soan-san]
---

# Đổi món, đổi bài tập, feedback

Ba endpoint của BRD mục 6.4 — `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` — xây ở giai đoạn 4. Chúng không lưu trạng thái: nhận `{ profile, plan, … }`, trả cả plan mới. Bài này ghi luồng xử lý, quy tắc, dữ liệu soạn sẵn và những điều đã kiểm chứng. Ràng buộc liên quan: [[critical-constraints]] #2, #7, #12–#16, #22–#25. Hợp đồng plan: [[plan-data-contract]]. Gọi Gemini: [[gemini-integration]]. Lịch sử: [[auth-and-history]].

## Luồng chung

1. `ValidationPipe` kiểm `AdjustPlanDto` (`profile` + `plan`, cả hai `@IsDefined()`).
2. `readClientPlan()` (`src/plan/adjust/client-plan.ts`):
   - tính lại mục tiêu từ `profile`; khác `daily_target` của plan → 409;
   - ID sai vị trí hoặc vi phạm `findPlanViolations()` → 400.
3. Service sửa plan. Kết quả Gemini luôn được kiểm; hỏng thì dùng kho soạn sẵn.
4. `rebuildPlan()`:
   - giữ `plan_id` (trừ feedback ngày 3) và `source`;
   - gán lại ID, tính lại danh sách đi chợ;
   - `warnings` tính lại từ hồ sơ.
5. `PlanAdjustController`: đã đăng nhập → `HistoryService.update()` (ngày 3: `save()`); lỗi ghi → cảnh báo `historyNotSaved`.

## Đổi món (`MealSwapService`)

- **Gemini:** một món cùng bữa, calo trong `[max(90% món cũ, cận dưới bữa); min(110% món cũ, cận trên bữa)]`, không trùng món trong plan, không dị ứng, plan sau khi thay vẫn hợp lệ.
- **Kho:** `data/swap-meals.json` (21 món), nhân khẩu phần về đúng calo món cũ, chọn ngẫu nhiên (`RandomSource`).
- **Không còn món** → 422.

## Đổi bài tập (`ExerciseSwapService`)

- **Gemini** (quyết định Q2). Điều kiện đo được thay cho "nhẹ hơn":
  - cùng nhóm cơ;
  - `sets` ≤ cũ;
  - `tags` ⊆ tag cũ;
  - không vướng chấn thương;
  - không trùng động tác trong buổi.
- **Kho:** `data/swap-exercises.json` (39 động tác, `level` 1–3), lấy mức thấp hơn động tác cũ, gần mức cũ nhất. Động tác không có trong kho coi như khó nhất.
- **Đã nhẹ nhất** → 422.

## Feedback (`FeedbackService`, `workout-rules.ts`)

| Điều kiện | Buổi tập ngày kế tiếp |
|---|---|
| `danger_sign` | Ngày nghỉ (`REST_WORKOUT`), bỏ qua mọi quy tắc khác kể cả ăn uống; `safety_warning` (#14) |
| `joint_pain` | Thay động tác `jumping`/`kneeling` bằng động tác cùng nhóm cơ trong kho |
| `hard` hoặc `fatigued` | −1 hiệp mỗi động tác, thời lượng ×0,75 (≥ 10 phút) |
| `sore` | −1 hiệp cho nhóm cơ vừa tập (không cộng dồn), thêm giãn cơ |
| `easy`, chỉ `normal` | +1 hiệp (≤ 6) |

**Ăn uống** (quyết định Q3):

- Gemini lập lại 3 bữa ngày kế tiếp: ăn nhiều → nhắm max(90% mục tiêu, BMR) và không vượt mục tiêu; ăn ít → giữ mục tiêu.
- Không có khoá hoặc Gemini hỏng → giữ món, cảnh báo `mealsNotRebalanced`.

**Ngày 3:** `PlanService.generatePlan(profile, { feedbackNote })`, rồi áp quy tắc bài tập cho ngày 1 của plan mới.

**Gửi hai lần cho cùng một ngày sẽ điều chỉnh hai lần** — server không biết, app phải khoá nút.

## Bộ khớp từ khoá (`restriction-matcher.ts`)

- `data/restriction-keywords.json`: nhóm dị ứng → từ khoá nguyên liệu cần tránh; nhóm chấn thương → tag cần tránh; các cách nói "không có".
- Tách chữ người dùng nhập theo dấu phẩy, chấm phẩy, "và", "hoặc"…
- Đoạn gõ có dấu thì so có dấu, gõ không dấu mới so không dấu. Tên nguyên liệu luôn so có dấu.
- Kết quả chỉ gồm từ khoá, tag và cờ `hasUnrecognized`; không giữ chữ người dùng (#12).

Dùng ở bốn chỗ:

- lọc thực đơn mẫu của `generate-plan` (`filterPlanByRestrictions()`, tất định);
- lọc kho khi đổi món, đổi bài;
- kiểm lại mọi kết quả Gemini (`findRestrictionViolations()`);
- chọn động tác thay khi đau khớp.

## Đã kiểm chứng khi lập plan (2026-09-24)

| Điều | Hệ quả |
|---|---|
| Khoảng calo cố định cũ (tổng ngày ≤ 2200) thấp hơn mục tiêu của 7/18 hồ sơ; thực đơn mẫu ~1550 kcal/ngày thấp hơn BMR của 9/18 | Khoảng theo tỉ lệ mục tiêu, kiểm tổng calo ngày, nhân khẩu phần thực đơn mẫu (BRD v2.5.0) |
| `normalize('NFD')` không tách `đ`; bỏ dấu hết thì "cà" = "cá", "bơ" = "bò" | Bỏ dấu thay tay `đ`; chỉ bỏ dấu khi người dùng gõ không dấu |
| Thiếu hẳn `plan` trong request → `@ValidateNested()` bỏ qua → 500 | `@IsDefined()` cho `profile`, `plan` |
| Thực đơn mẫu có "Nước mắm" | Người dị ứng hải sản/cá: kết quả Gemini giống thực đơn mẫu bị loại, món đó trong thực đơn mẫu được thay |

## Test

- **Unit** (`src/plan/adjust/*.spec.ts`, `restriction-*.spec.ts`, `swap-pools.spec.ts`, `meal-scaling.spec.ts`):
  - Gemini giả qua `geminiAnswering()` trong `test/plan-fixtures.ts`;
  - plan mẫu do chính server tạo (`samplePlan()`);
  - chọn ngẫu nhiên cố định (`firstPick`, `lastPick`);
  - dấu hiệu nguy hiểm có `describe` riêng.
- **E2E** `test/adjust.e2e-spec.ts`: ba endpoint, 400/409/422/401, lịch sử, #12, Swagger, và đổi món qua SDK thật + server Gemini giả.
- **Smoke** (`npm run test:smoke`): gọi cả ba endpoint trên bản build, nên file JSON thiếu trong `dist/` sẽ bị bắt.
