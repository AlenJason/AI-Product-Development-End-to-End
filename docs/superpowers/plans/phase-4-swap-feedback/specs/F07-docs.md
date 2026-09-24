# F07 — BRD v2.5.0, wiki, CLAUDE.md, README, PLAN.md, SETUP_CREDENTIALS

## Feature

Ghi lại phạm vi mới và những gì học được ở giai đoạn 4:

- **BRD v2.5.0.** Quyết định Q1 đổi NFR-4 (khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày), nên đây là thay đổi phạm vi. Ghi chi tiết FR-1.4 (bộ khớp từ khoá), FR-1.5 (sàn BMR cho thực đơn thật), FR-4.1/4.2 (kho dự phòng, điều kiện "nhẹ hơn"), FR-5.2 (quy tắc cụ thể, cân đối món ăn), FR-7.1 (lịch sử cập nhật theo đổi món/feedback — Q4), mục 6.4 (mã lỗi, đăng nhập tuỳ chọn).
- **Wiki:**
  - bài mới `swap-and-feedback.md`;
  - sửa ràng buộc #2, #13, #14, #15; thêm #23–#25;
  - cập nhật `plan-data-contract.md`, `gemini-integration.md` (sửa câu đã cũ về cách ghim env ở e2e — brainstorm mục 2);
  - `wiki-triggers.md` bỏ trỏ tới `api-routes.md`, một bài chưa từng có.
- **PLAN.md:**
  - đánh dấu 4.1–4.5; sửa câu 4.2 đã cũ ("cập nhật theo `source_meal_ids`", mâu thuẫn #7);
  - 4.6 `responseSchema` để sau;
  - thêm 4.7 (Q1), 4.8 (Q4);
  - thêm vào giai đoạn 7 cách app xử lý 409/422 và khoá nút feedback (brainstorm F6).
- **SETUP_CREDENTIALS:** log đổi sang dạng `(lần N, <thao tác>)`.
- **README:** Changelog v2.5.0.
- **CLAUDE.md:** kiến trúc `src/plan/adjust/`, bộ khớp, kho, `npm run lint`.

## Scope

Docs:

- `BRD.md`, `README.md`, `CLAUDE.md`, `docs/PLAN.md`, `docs/SETUP_CREDENTIALS.md`
- `docs/knowledge/wiki/swap-and-feedback.md` (mới), `critical-constraints.md`, `plan-data-contract.md`, `gemini-integration.md`, `INDEX.md`, `wiki-triggers.md`, `log.md`
- `docs/knowledge/CLAUDE.md`

## Implementation

### API Routes

Không sửa code.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

Feature này sửa #2, #13, #14, #15 và thêm #23, #24, #25 trong `critical-constraints.md`.

## Definition of Done

- [ ] BRD ghi `**Phiên bản:** 2.5.0`; NFR-4 không còn "250–600"
- [ ] `critical-constraints.md` có #1–#25; `swap-and-feedback.md` có trong `INDEX.md`; mọi `[[link]]` trỏ tới file có thật; `wiki-triggers.md` không còn `api-routes.md`
- [ ] PLAN.md: 4.1–4.5, 4.7, 4.8 là `[x]`; 4.6 là `[ ]`
- [ ] README có mục Changelog `BRD v2.5.0`
- [x] All API routes complete within deployment timeout — không áp dụng
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: các lệnh ở Task 9 in đúng số mong đợi
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: mọi `[[link]]` trong wiki có file tương ứng
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — `BRD.md` → v2.5.0

1. `**Phiên bản:** 2.4.0 (…)` → `**Phiên bản:** 2.5.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)`.

2. FR-1.4 — thêm vào cuối gạch đầu dòng:

```markdown
 Ở chế độ giả lập (chưa có khoá Gemini), backend nhận ra các dị ứng, chấn thương phổ biến bằng từ khoá (gõ có dấu hay không dấu đều được) để lọc thực đơn mẫu; có phần không nhận ra thì app nhận một câu cảnh báo chung, không nhắc lại chữ người dùng đã nhập. *(bổ sung bản 2.5.0)*
```

3. FR-1.5 — thêm vào cuối gạch đầu dòng:

```markdown
 **Tổng calo thực đơn mỗi ngày** cũng phải nằm trong khoảng từ 85% mục tiêu (và không thấp hơn BMR) tới 110% mục tiêu; thực đơn mẫu được nhân khẩu phần cho khớp mục tiêu của từng người. *(bổ sung bản 2.5.0)*
```

4. FR-4.1 — thêm vào cuối gạch đầu dòng:

```markdown
 Không có khoá Gemini, hoặc AI trả kết quả không đạt → lấy món từ kho món Việt soạn sẵn, lọc theo từ khoá dị ứng, nhân khẩu phần về đúng calo món cũ. Không còn món phù hợp → báo lỗi, app giữ plan cũ. *(bổ sung bản 2.5.0)*
```

5. FR-4.2 — thêm vào cuối gạch đầu dòng:

```markdown
 Có khoá Gemini: AI đề xuất, backend kiểm các điều kiện đo được — cùng nhóm cơ, số hiệp không tăng, không thêm kiểu tải mới (bật nhảy, chống quỳ, chống tay…), không vướng chấn thương đã khai. Không đạt hoặc không có khoá → kho động tác soạn sẵn có mức khó 1–3, lấy động tác mức thấp hơn. Động tác đã ở mức nhẹ nhất → báo lỗi. *(bổ sung bản 2.5.0)*
```

6. FR-5.2 — thay hai gạch đầu dòng đầu (bài tập, món ăn) bằng:

```markdown
  * Bài tập theo quy tắc cố định (không cần AI): Nhẹ nhàng và cơ thể bình thường → mỗi động tác tăng 1 hiệp (tối đa 6); Rất mệt hoặc uể oải → mỗi động tác giảm 1 hiệp, buổi tập ngắn đi 25%; Căng mỏi cơ → giảm hiệp cho nhóm cơ vừa tập, thêm giãn cơ; Đau khớp → thay động tác bật nhảy, chống quỳ bằng động tác cùng nhóm cơ không có kiểu tải đó.
  * Món ăn cân đối lại theo câu trả lời về ăn uống (cần AI): ăn nhiều hơn → ngày kế tiếp nhẹ hơn (khoảng 90% mục tiêu); ăn ít hơn hoặc bỏ bữa → giữ mục tiêu, không ăn bù. Không bao giờ hạ calo xuống dưới BMR. Chế độ giả lập giữ nguyên món và báo cho người dùng biết. *(chi tiết hoá ở bản 2.5.0)*
```

7. FR-7.1 — thêm vào cuối gạch đầu dòng:

```markdown
 Khi đã đăng nhập, đổi món, đổi bài tập và feedback cũng cập nhật plan đã lưu; plan mới tạo từ feedback ngày 3 được lưu thành một mục mới. *(bổ sung bản 2.5.0)*
```

8. Mục 6.4 — thêm sau danh sách "Giá trị cho feedback" (trước `---`):

```markdown

**Chi tiết (bổ sung bản 2.5.0):**

* Đăng nhập tuỳ chọn như `generate-plan`: không gửi header `Authorization` → chạy như khách; token hợp lệ → cập nhật plan đã lưu (feedback ngày 3: lưu mới); token sai → 401.
* `plan_id` giữ nguyên, trừ feedback ngày 3.
* Lỗi: **400** — request sai, hoặc plan không còn đúng như server đã trả (ID sai vị trí, calo vô lý, trùng món); **409** — plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi), cần tạo plan mới; **422** — không còn món hoặc động tác thay thế phù hợp.
* `body_states` tối đa 5 giá trị; trùng thì bỏ trùng.
* Endpoint không lưu trạng thái, nên gửi feedback hai lần cho cùng một ngày sẽ điều chỉnh hai lần — app khoá nút sau khi gửi.
```

9. NFR-4 — thay dòng `* Gemini có thể "bịa" … phải qua cùng một bộ kiểm tra trước khi trả cho Flutter:` và dòng `* calo từng bữa trong khoảng hợp lý: …` bằng:

```markdown
   * Gemini có thể "bịa" calo/macro không nhất quán. Mọi kết quả Gemini (thực đơn, món thay thế, ngày cân đối lại), thực đơn mẫu và plan client gửi lại phải qua cùng một bộ kiểm tra trước khi trả cho Flutter:
```

```markdown
     * calo từng bữa theo tỉ lệ mục tiêu ngày: bữa sáng 15–35%, bữa trưa/tối 25–45%; tổng calo mỗi ngày từ 85% mục tiêu (không thấp hơn BMR) tới 110% mục tiêu *(bản 2.5.0 — khoảng cố định cũ sáng 250–600, trưa/tối 400–800 kcal chặn tổng ngày ở 2200 kcal, thấp hơn mục tiêu của nhiều người)*;
     * không chứa nguyên liệu người dùng dị ứng mà backend nhận ra được bằng từ khoá *(bản 2.5.0)*;
```

### Task 2 — `docs/SETUP_CREDENTIALS.md`

Mục 1.3, bước 2 — sửa hai dòng log thành `Lỗi khi gọi Gemini (lần 1, tạo kế hoạch): …` và `Kết quả Gemini không đạt hợp đồng (lần 1, tạo kế hoạch): …`. Thêm vào cuối bước 2:

```markdown
   Đổi món, đổi bài tập và cân đối món ăn sau feedback ghi log cùng dạng, với tên thao tác tương ứng (`đổi món`, `đổi bài tập`, `cân đối món ăn`). Khi Gemini không dùng được, đổi món và đổi bài tập lấy từ kho soạn sẵn; cân đối món ăn thì giữ nguyên món và app nhận một câu cảnh báo.
```

### Task 3 — Bài wiki `docs/knowledge/wiki/swap-and-feedback.md`

````markdown
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
````

### Task 4 — `docs/knowledge/wiki/critical-constraints.md`

Thay dòng #2, #13, #14, #15 và thêm #23–#25 sau #22:

```markdown
| 2 | Mọi plan — kết quả Gemini, thực đơn mẫu, plan client gửi lên — phải qua kiểm tra hợp đồng trong `backend_api/src/plan/plan-validation.ts`: class-validator theo hợp đồng BRD 6.2, rồi `findPlanViolations(plan, target)`: calo từng bữa theo tỉ lệ mục tiêu (`MEAL_CALORIE_SHARE`: sáng 15–35%, trưa/tối 25–45%), tổng calo ngày trong [max(85% mục tiêu, BMR); 110% mục tiêu] (`dayCalorieBounds()`), calo lệch không quá 15% so với 4P+4C+9F, không trùng món. Plan client gửi lên (đổi món, đổi bài, feedback) qua `readClientPlan()` (`src/plan/adjust/client-plan.ts`). Mã ngoài danh sách (ví dụ `meal_type: "Bữa sáng"`) bị coi là sai — không bao giờ cho qua khi tra cứu không ra. | BRD NFR-4 (v2.5.0). Bản cũ (`nutrition-sanity.util.ts`, đã xoá) tra khoảng calo theo chuỗi tiếng Việt và cho qua khi không khớp. Khoảng cố định sau đó (sáng 250–600, trưa/tối 400–800) chặn tổng ngày ở 2200 kcal — thấp hơn mục tiêu của 7/18 hồ sơ trong ma trận test — và tổng ngày không được kiểm (phát hiện giai đoạn 4). Không đạt → gọi lại 1 lần → dữ liệu soạn sẵn. |
| 13 | Calo mục tiêu = `max(TDEE + điều chỉnh, BMR)` (`computeDailyTarget()` trong `backend_api/src/plan/daily-target.ts`); điều chỉnh: cut −300, bulk +250. Sàn BMR áp cho cả **thực đơn thật**: tổng calo mỗi ngày ≥ BMR được kiểm trong `findPlanViolations()`; thực đơn mẫu và món trong kho được nhân khẩu phần (`meal-scaling.ts`) cho khớp mục tiêu; feedback "ăn nhiều hơn" chỉ hạ ngày kế tiếp xuống max(90% mục tiêu, BMR). Mọi tính năng tự tính lại BMR từ `profile`, không tin số `bmr` client gửi lên. | BRD FR-1.3, FR-1.5, FR-5.2 (v2.5.0), quyết định D1, Q4 (giai đoạn 1) và Q1, Q3 (giai đoạn 4). Không có sàn thì người nhỏ con ít vận động bị đặt mục tiêu dưới BMR (ví dụ 1040 kcal khi BMR 1117). Thực đơn mẫu cố định ~1550 kcal/ngày từng thấp hơn BMR của mọi hồ sơ nam trong ma trận test. |
| 14 | Feedback có dấu hiệu nguy hiểm (`danger_sign`: chóng mặt, khó thở bất thường, đau ngực) → **không** áp các quy tắc điều chỉnh thông thường, kể cả cân đối món ăn; trả `safety_warning` khuyên ngừng tập, hỏi ý kiến bác sĩ, gọi 115 nếu nặng; ngày kế tiếp (hoặc ngày 1 của plan mới) chỉ nghỉ hoặc đi bộ nhẹ. | BRD FR-5.2, quyết định D2. Có code từ giai đoạn 4: `adjustWorkout()` (`src/plan/adjust/workout-rules.ts`) trả `REST_WORKOUT` trước mọi quy tắc khác; `FeedbackService` không gọi Gemini khi có dấu hiệu này. Test riêng trong `workout-rules.spec.ts` và `feedback.service.spec.ts`. |
| 15 | Mỗi lần gọi Gemini có timeout `GEMINI_TIMEOUT_MS` (mặc định 15 000 ms). Mọi chỗ gọi Gemini đi qua `generateWithRetry()` (`backend_api/src/plan/gemini-retry.ts`): lỗi hoặc sai hợp đồng → gọi lại đúng 1 lần; hết giờ → không gọi lại, dùng ngay dữ liệu soạn sẵn (thực đơn mẫu, kho món/động tác) hoặc giữ món cũ. **Không** truyền `retryOptions` cho SDK `@google/genai`. | BRD NFR-1. SDK có cơ chế tự gọi lại (mặc định 5 lần, chờ tới 60 giây) nhưng chỉ bật khi có `retryOptions`; bật lên sẽ chồng lên lần gọi lại của backend và kéo request lên vài phút. Đã kiểm bằng SDK thật: lỗi 500 → đúng 1 request; `gemini.service.spec.ts` khoá hành vi này. |
```

```markdown
| 23 | Bộ khớp từ khoá (`restriction-matcher.ts`, `data/restriction-keywords.json`): tên nguyên liệu luôn so **có dấu**; chữ người dùng gõ có dấu thì so có dấu, gõ không dấu mới so không dấu (bỏ dấu phải thay tay `đ` → `d`, NFD không tách chữ này). Kết quả chỉ gồm từ khoá cần tránh, tag cần tránh và cờ `hasUnrecognized` — **không** giữ lại chữ người dùng. Cảnh báo và thông báo vi phạm (được ghi log) không nêu từ khoá hay tag. Mọi kết quả Gemini được kiểm lại bằng bộ khớp. | Bỏ dấu hết thì "cà chua" thành "cá", "bơ" thành "bò" (phát hiện khi viết code giai đoạn 4). Từ khoá dị ứng suy ra từ dữ liệu sức khoẻ, và plan có thể được lưu vào lịch sử (#12). |
| 24 | Endpoint nhận plan từ client (BRD 6.4) luôn qua `readClientPlan()` trước khi sửa: mục tiêu calo tính lại từ `profile`, khác `daily_target` của plan → **409**; ID sai vị trí hoặc vi phạm hợp đồng → **400**. Lắp lại bằng `rebuildPlan()`: giữ `plan_id` (trừ feedback ngày 3), gán lại ID, tính lại danh sách đi chợ và cảnh báo — không dùng `grocery_list`/`warnings` client gửi. Trường object lồng nhau bắt buộc trong DTO phải có `@IsDefined()`. | Quyết định giai đoạn 4 (brainstorm F5, F7). Thiếu hẳn trường thì `@ValidateNested()` bỏ qua không kiểm, service nhận `undefined` và trả 500 — e2e bắt được khi lập plan. |
| 25 | Kho soạn sẵn `data/swap-meals.json`, `data/swap-exercises.json` nạp và kiểm hợp đồng lúc khởi động (`swap-pools.ts`); file hỏng → backend không lên. Thêm món/động tác phải qua `swap-pools.spec.ts`: macro khớp calo cả sau khi nhân khẩu phần, không trùng tên món với `sample-plan.json`, mỗi nhóm cơ có động tác mức 1, mọi động tác của `sample-plan.json` có trong kho (để biết mức khó). Chọn món/động tác thay thế dùng `RandomSource` (test thay bằng giá trị cố định); lọc thực đơn mẫu thì tất định. | Quyết định Q2 giai đoạn 4: "nhẹ hơn" đo bằng `level`. Món trong kho được nhân khẩu phần về đúng calo món cũ nên luôn vừa ±10% (BRD FR-4.1). |
```

### Task 5 — `plan-data-contract.md`, `gemini-integration.md`

`docs/knowledge/wiki/plan-data-contract.md`:

- `Hợp đồng gốc là BRD.md mục 6 (v2.3.0)` → `Hợp đồng gốc là BRD.md mục 6 (v2.5.0)`; câu liên kết ràng buộc thêm `, #23` và `Đổi món, đổi bài, feedback: [[swap-and-feedback]].`
- Luồng, bước 3–6 — thay bằng:

```markdown
3. Có `GEMINI_API_KEY` → `GeminiService.generatePlanContent()` trả JSON thô (chỉ `days`). Không có → bỏ qua bước này.
4. `parsePlanContent(raw, target)` (`plan-validation.ts`) → class-validator + `findPlanViolations()`; rồi `findRestrictionViolations()` (có nguyên liệu dị ứng đã nhận ra → sai hợp đồng). Sai → `generateWithRetry()` gọi lại 1 lần (trừ khi hết giờ) → thực đơn mẫu `data/sample-plan.json`: lọc theo hạn chế nhận ra (`filterPlanByRestrictions()`), nhân khẩu phần từng ngày cho khớp mục tiêu (`scaleMealsToTotal()`), rồi qua đúng bước kiểm tra này.
5. `assemblePlan()` (`plan-assembly.ts`) → `plan_id` (hoặc giữ `plan_id` cũ khi đổi món/feedback), ID món và động tác, sắp bữa, `buildGroceryList()`.
6. `warnings` (`plan-warnings.ts`): sàn BMR, khuyến cáo y tế, thực đơn mẫu chỉ lọc theo từ khoá, hạn chế chưa nhận ra hết. Không câu nào nhắc lại chữ người dùng nhập.
```

- Mục "Hai lớp DTO", cuối dòng `meal-plan-response.dto.ts`: `Giai đoạn 4 dùng chính các lớp này để validate plan client gửi lên.` → `Cũng dùng để validate plan client gửi lên khi đổi món, đổi bài, feedback (`AdjustPlanDto`, [[swap-and-feedback]]).`
- Thêm mục mới trước "## Mã cố định":

```markdown
## Khoảng calo (BRD NFR-4, v2.5.0)

| Kiểm | Khoảng |
|---|---|
| Bữa sáng | 15–35% `target_calories` |
| Bữa trưa, bữa tối | 25–45% `target_calories` |
| Tổng một ngày | max(85% `target_calories`, BMR) – 110% `target_calories` |

`mealCalorieBounds()`, `dayCalorieBounds()` tính các khoảng này; prompt Gemini đọc cùng hàm. Thực đơn mẫu (soạn cho ~1550 kcal/ngày) và món trong kho được nhân khẩu phần bằng `meal-scaling.ts` — calo, macro, lượng nguyên liệu cùng một hệ số, nên calo vẫn khớp 4P+4C+9F.
```

`docs/knowledge/wiki/gemini-integration.md`:

- Câu mở đầu, sau `ở đúng một chỗ: `GeminiService` (`backend_api/src/plan/gemini.service.ts`).` thêm: ` `generateJson(prompt)` dùng chung cho tạo plan, đổi món, đổi bài tập, cân đối món ăn; vòng gọi lại chung là `generateWithRetry()` (`gemini-retry.ts`).`
- Gạch đầu dòng `test/generate-plan.e2e-spec.ts` — thay bằng:

```markdown
- `test/generate-plan.e2e-spec.ts`, `test/adjust.e2e-spec.ts` — trọn đường HTTP → service → `GeminiService` → SDK → server giả. App tạo bằng `createTestApp()` (`test/test-app.ts`), hàm này ghim `GEMINI_*` (cùng DB và chế độ đăng nhập) **trước** khi nạp `AppModule`, vì máy dev có thể có khoá thật trong `.env`.
```

- Câu `Tầng `PlanService` (…) dùng object `GeminiService` giả bằng `vi.fn()` để test logic gọi lại cho nhanh.` → thêm ` Các service của giai đoạn 4 dùng `geminiAnswering()` trong `test/plan-fixtures.ts` (giả `generateJson()`).`
- Mục "Thử prompt với Gemini thật" — thêm câu cuối: `Prompt của đổi món, đổi bài tập, cân đối món ăn (`src/plan/adjust/adjust-prompts.ts`) chưa có bản trong `ai_workspace/`.`

### Task 6 — `INDEX.md`, `wiki-triggers.md`, `log.md`, `docs/knowledge/CLAUDE.md`

`INDEX.md` — thêm trước `[[log]]`:

```markdown
| [[swap-and-feedback]]       | Đổi món, đổi bài tập, feedback cuối ngày; bộ khớp từ khoá dị ứng/chấn thương; kho món và động tác soạn sẵn |
```

`wiki-triggers.md`:

- Dòng trigger đường dẫn của `app.controller.ts`… `main.ts`: `api-routes.md` → `plan-data-contract.md`, `auth-and-history.md`.
- Thêm dòng:

```markdown
| `backend_api/src/plan/adjust/**`, `backend_api/src/plan/restriction-matcher.ts`, `backend_api/src/plan/restriction-filter.ts`, `backend_api/src/plan/swap-pools.ts`, `backend_api/src/plan/meal-scaling.ts`, `backend_api/src/plan/exercise-presets.ts`, `backend_api/src/plan/data/swap-*.json`, `backend_api/src/plan/data/restriction-keywords.json`, `backend_api/test/plan-fixtures.ts`, `backend_api/test/adjust.e2e-spec.ts` | `swap-and-feedback.md` |
```

- `flutter-ui.md` → `flutter-ui.md` *(chưa có — tạo ở giai đoạn 5)*; `product-spec.md` → `product-spec.md` *(chưa có — đọc thẳng BRD.md)* (cả bảng đường dẫn và bảng từ khoá).
- Dòng từ khoá `endpoint / controller / swagger / health / validation / DTO`: `api-routes.md` → `plan-data-contract.md`, `auth-and-history.md`, `swap-and-feedback.md`.
- Thêm dòng từ khoá:

```markdown
| đổi món / đổi bài / swap / feedback / dị ứng / chấn thương / từ khoá / kho món / kho động tác / dấu hiệu nguy hiểm / khẩu phần | `swap-and-feedback.md` |
```

`log.md` — thêm cuối file:

```
2026-09-24 — Giai đoạn 4 (PLAN.md): thêm bài [[swap-and-feedback]]; sửa #2 (khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày), #13 (sàn BMR áp cho thực đơn thật), #14 (có code, test riêng), #15 (`generateWithRetry()` dùng chung); thêm #23 (bộ khớp từ khoá), #24 (nhận plan từ client), #25 (kho soạn sẵn); cập nhật [[plan-data-contract]], [[gemini-integration]] (bỏ câu cũ về cách ghim env ở e2e); wiki-triggers không còn trỏ tới bài chưa có
```

`docs/knowledge/CLAUDE.md` — thêm mảng trọng tâm:

```markdown
6. Đổi món, đổi bài tập, feedback cuối ngày (BRD FR-4, FR-5) — có code từ giai đoạn 4, xem [[swap-and-feedback]]
```

### Task 7 — `CLAUDE.md` (gốc repo)

1. Gạch đầu dòng `backend_api/`: sau câu `Accounts (Google Sign-In, …) … are built (BRD FR-6, FR-7; PLAN.md phase 3).` thêm ` Meal/exercise swap and end-of-day feedback (BRD §6.4) are built too (PLAN.md phase 4): stateless endpoints that take `{ profile, plan, … }` and return the whole new plan.`
2. Khối lệnh Backend — thêm sau dòng `npm test`:

```bash
npm run typecheck               # tsc --noEmit over src/ and test/ incl. specs (build and vitest both skip type-checking tests)
npm run lint                    # oxlint (type-aware); typescript/no-misused-spread is off on purpose — DTOs are data-only
```

   (Dòng `typecheck` đã có từ commit sửa lỗi sau giai đoạn 3 thì giữ nguyên, chỉ thêm dòng `lint`.)

3. Mục "Backend architecture", gạch đầu dòng `src/plan/`: `The contract is BRD.md §6 (v2.4.0)` → `(v2.5.0)`; bước 4 thay bằng:

```markdown
  4. `plan-validation.ts` — `parsePlanContent(raw, target)`: class-validator against `dto/plan-content.dto.ts`, then `findPlanViolations(plan, target)`: meal calories as a share of the daily target (`MEAL_CALORIE_SHARE`: breakfast 15–35 %, lunch/dinner 25–45 %), each day's total within [max(85 % target, BMR); 110 % target], calories within 15 % of 4P+4C+9F, no repeated dish. The old fixed bounds (250–600 / 400–800) capped a day at 2200 kcal, below many users' targets, and the day total was never checked. Unknown enum values must fail, never skip a check.
```

   Bước 5 thay bằng:

```markdown
  5. `plan.service.ts` — orchestration: Gemini through `generateWithRetry()` (`gemini-retry.ts`: retry once, never after a timeout), output also rejected if it contains a recognised allergen → otherwise `data/sample-plan.json`, filtered by `filterPlanByRestrictions()` and scaled per day to the target by `meal-scaling.ts` (the file is written for ~1550 kcal/day), then validated by the same function. Warning texts live in `plan-warnings.ts` and never quote user text.
```

   Thêm hai gạch đầu dòng sau gạch đầu dòng `src/plan/` (trước `src/database/`):

```markdown
- `src/plan/restriction-matcher.ts` + `data/restriction-keywords.json` — keyword matcher for allergies/injuries (mock mode, D4) and for re-checking every Gemini result. Ingredient names are always compared with Vietnamese accents ("cá" fish ≠ "cà" tomato, "bò" ≠ "bơ"); user text is compared accent-insensitively only when typed without accents (NFD does not split "đ" — replaced by hand). It returns keywords/tags and a `hasUnrecognized` flag, never the user's text. `swap-pools.ts` loads and validates `data/swap-meals.json` (21 dishes) and `data/swap-exercises.json` (39 exercises with `level` 1–3) at boot; every exercise in `sample-plan.json` must be in the pool so its level is known.
- `src/plan/adjust/` — `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD §6.4) behind `OptionalJwtAuthGuard`. `readClientPlan()` recomputes the target from `profile` (mismatch with the plan's `daily_target` → 409) and checks ids/positions + `findPlanViolations()` (→ 400); `rebuildPlan()` keeps `plan_id`/`source` and recomputes ids, grocery list and warnings. Meal swap: Gemini first (±10 % calories, same meal type, no repeat, no allergen), then the pool scaled to the old meal's calories, else 422. Exercise swap: Gemini first, accepted only if same muscle group, sets ≤ old, tags ⊆ old tags, no injury tag; then a lower-`level` pool exercise, else 422. Feedback: fixed rules in `workout-rules.ts` (danger sign → rest day and `safety_warning`, skipping everything else), meals re-planned by Gemini on over/under-eating (never below BMR; no key → unchanged + warning), day 3 → a new plan via `PlanService.generatePlan(profile, { feedbackNote })`. Logged in: swap/feedback update the saved plan (`HistoryService.update()`), day-3 plans are saved as new. `test/plan-fixtures.ts` holds the shared fixtures (`samplePlan()`, `geminiAnswering()`, `firstPick`).
```

### Task 8 — `README.md`, `docs/PLAN.md`

`README.md`:

- Cấu trúc thư mục, dòng `backend_api/` → `backend_api/     API NestJS — generate-plan (Gemini hoặc thực đơn mẫu), đổi món, đổi bài tập, feedback, đăng nhập Google, lịch sử (SQLite)`
- Changelog — thêm trên `### BRD v2.4.0`:

```markdown
### BRD v2.5.0 — 2026-09-24
- Giai đoạn 4 — đổi món, đổi bài tập, feedback cuối ngày: `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD mục 6.4), chạy được cả khi chưa có khoá nhờ kho 21 món Việt và 39 động tác có mức độ khó. Có khoá thì Gemini đề xuất trước, backend kiểm lại: calo ±10%, cùng nhóm cơ, không nặng hơn, tránh dị ứng và chấn thương
- Feedback: quy tắc cố định cho buổi tập ngày kế tiếp; dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực) → ngày nghỉ kèm khuyến cáo ngừng tập, hỏi ý kiến bác sĩ, gọi 115; feedback ngày 3 tạo plan mới. Đã đăng nhập thì các thao tác này cập nhật lịch sử
- Sửa lỗi dinh dưỡng: trước đây tổng calo thực đơn mỗi ngày không được kiểm, còn thực đơn mẫu cố định khoảng 1550 kcal/ngày — thấp hơn mức chuyển hoá cơ bản (BMR) của mọi hồ sơ nam trong bộ test. Nay khoảng calo tính theo mục tiêu của từng người và thực đơn mẫu được nhân khẩu phần cho khớp (BRD NFR-4)
- Chế độ giả lập nhận ra dị ứng, chấn thương phổ biến (gõ có dấu hay không dấu) để lọc thực đơn mẫu; kết quả Gemini có nguyên liệu người dùng dị ứng bị loại. Kiểm thử: thêm 114 unit test và 22 e2e; smoke test gọi thêm 3 endpoint mới trên bản build
```

`docs/PLAN.md`:

1. Dòng đầu `(v2.4.0)` → `(v2.5.0)`; "Hiện trạng": `BRD v2.4.0` → `BRD v2.5.0`, dòng Backend thêm `, đổi món, đổi bài tập, feedback` trước `, đăng nhập Google`.
2. Tiêu đề giai đoạn 4: `· M` → `· L`. Thay các bước 4.1–4.6 bằng:

```markdown
- [x] **4.1** Bộ khớp từ khoá cho chế độ giả lập (`data/restriction-keywords.json`, `restriction-matcher.ts`): nhận ra dị ứng/chấn thương phổ biến, gõ có dấu hay không dấu; phần không nhận ra → cảnh báo chung, không nhắc lại chữ người dùng (D4). Lọc luôn thực đơn mẫu của `generate-plan` và kiểm lại mọi kết quả Gemini
- [x] **4.2** `POST /api/v1/meals/swap`: Gemini sinh món thay thế lệch không quá ±10% calo, tránh các hạn chế người dùng nhập, không trùng món đã có trong plan; backend tính lại toàn bộ `grocery_list` (#7). Fallback: kho món Việt `data/swap-meals.json` lọc bằng bộ khớp từ khoá, nhân khẩu phần về đúng calo món cũ; hết món phù hợp → 422
- [x] **4.3** `POST /api/v1/exercises/swap` *(quyết định Q2: Gemini trước)*: động tác nhẹ hơn, cùng nhóm cơ, tránh chấn thương — kết quả Gemini phải qua điều kiện đo được (số hiệp không tăng, không thêm kiểu tải). Fallback: `data/swap-exercises.json` có mức khó 1–3; đã nhẹ nhất → 422
- [x] **4.4** `POST /api/v1/feedback` theo D2: bài tập điều chỉnh bằng quy tắc cố định; món ăn nhờ Gemini *(quyết định Q3)* — ăn nhiều → ngày kế tiếp ~90% mục tiêu, ăn ít → giữ mục tiêu, không có key thì giữ nguyên món kèm cảnh báo. Dấu hiệu nguy hiểm → `safety_warning` và ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ. **Không bao giờ hạ calo mục tiêu xuống dưới BMR.** Ngày 3 → plan mới
- [x] **4.5** Test cả 4 phần trên, chạy được khi không có key; dấu hiệu nguy hiểm có test riêng. E2E qua HTTP thật, một đường qua SDK Gemini thật + server giả; smoke test gọi 3 endpoint trên bản build
- [ ] **4.6** *(Tuỳ chọn, để sau)* Dùng `responseSchema` của Gemini để ép JSON đúng cấu trúc ngay từ API — cần khoá thật để đo nó giảm lỗi bao nhiêu (thử bằng `ai_workspace/`); bước kiểm hợp đồng vẫn phải giữ
- [x] **4.7** *(bổ sung, quyết định Q1)* Khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày (≥ BMR), nhân khẩu phần thực đơn mẫu cho khớp mục tiêu — sửa lỗi thực đơn thấp hơn BMR của nhiều người (BRD NFR-4, v2.5.0)
- [x] **4.8** *(bổ sung, quyết định Q4)* Đã đăng nhập: đổi món, đổi bài, feedback cập nhật plan đã lưu; plan từ feedback ngày 3 lưu mới

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-4-swap-feedback.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-4-swap-feedback/`.
```

3. Giai đoạn 7 — thay 7.1 và 7.3 bằng:

```markdown
- [ ] **7.1** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp
```

```markdown
- [ ] **7.3** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa
```

### Task 9 — Cổng kiểm tra F07

```bash
grep -c 'Phiên bản:\*\* 2.5.0' BRD.md                                         # 1
grep -c '250–600' BRD.md                                                        # 1 (chỉ còn trong ghi chú lịch sử của NFR-4)
grep -cE '^\| (23|24|25) \|' docs/knowledge/wiki/critical-constraints.md        # 3
grep -c 'swap-and-feedback' docs/knowledge/wiki/INDEX.md                         # 1
grep -c 'api-routes' docs/knowledge/wiki/wiki-triggers.md                        # 0
grep -cE '^- \[x\] \*\*4\.[1-5,7,8]' docs/PLAN.md                               # 7
grep -c '^- \[ \] \*\*4\.6' docs/PLAN.md                                        # 1
for name in $(grep -oh '\[\[[a-z-]*\]\]' docs/knowledge/wiki/*.md | sort -u | tr -d '[]'); do
  [ -f "docs/knowledge/wiki/$name.md" ] || echo "THIẾU: $name"
done                                                                            # không in gì
```
