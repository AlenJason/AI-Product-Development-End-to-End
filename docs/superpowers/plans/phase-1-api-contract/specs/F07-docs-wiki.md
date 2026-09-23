# F07 — Wiki, CLAUDE.md, hướng dẫn gắn khoá, Changelog, tiến độ

## Feature

Đưa tài liệu về khớp với code sau F01–F06:

- Viết lại các ràng buộc wiki bị hướng B làm thay đổi (#2, #6, #7) và thêm ràng buộc mới (#12–#16).
- Tạo bài wiki `plan-data-contract.md`. Brainstorm đã ghi đây là bài trigger thiếu quan trọng nhất.
- Cập nhật `CLAUDE.md` cho các AI agent sau.
- Sửa `SETUP_CREDENTIALS.md`: kiểm tra bằng trường `source` thay vì đọc log.
- Thêm Changelog v2.3.0 vào README cho giảng viên.
- Đánh dấu xong giai đoạn 1 trong `docs/PLAN.md` và chỉnh giai đoạn 2 cho khớp (một phần đã làm trong giai đoạn 1).

## Scope

Docs:

- `docs/knowledge/wiki/critical-constraints.md`
- `docs/knowledge/wiki/plan-data-contract.md` (mới)
- `docs/knowledge/wiki/wiki-triggers.md`, `docs/knowledge/wiki/INDEX.md`, `docs/knowledge/wiki/log.md`
- `CLAUDE.md`
- `docs/SETUP_CREDENTIALS.md`
- `README.md`
- `docs/PLAN.md`

## Implementation

### API Routes

Không sửa code.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

Feature này **là** nơi cập nhật ràng buộc: #2, #6, #7 viết lại; #12–#16 thêm mới. Nội dung chính xác ở Task 1.

## Definition of Done

- [ ] `critical-constraints.md` có #1–#16, các hàng #2, #6, #7 đúng văn bản mới
- [ ] `plan-data-contract.md` tồn tại và có trong `INDEX.md`
- [ ] `wiki-triggers.md` không còn nhắc `nutrition-sanity.util.ts` hay `interfaces/**`
- [ ] `CLAUDE.md` không còn nhắc `nutrition-sanity.util.ts`, `interfaces/plan.interface.ts`
- [ ] PLAN.md: 1.1–1.4 đánh dấu `[x]`, giai đoạn 1 ghi `· M`, giai đoạn 2 đã chỉnh
- [ ] README có mục `BRD v2.3.0`
- [x] All API routes complete within deployment timeout — không áp dụng
- [x] Auth check at top of each protected handler — không áp dụng

## Test Checklist

1. **@happy**: `grep -c 'plan-data-contract' docs/knowledge/wiki/INDEX.md` → `1`; `grep -c '^- \[x\] \*\*1\.' docs/PLAN.md` → `4`
2. **@auth**: không áp dụng
3. **@timeout**: không áp dụng
4. **@partial-fail**: `grep -rn "nutrition-sanity\|plan.interface" CLAUDE.md docs/knowledge/wiki/wiki-triggers.md` → không có kết quả (ràng buộc #2 cố ý nhắc tên file cũ để giải thích lý do, nên không đưa vào lệnh kiểm tra)
5. **@token**: không áp dụng
6. **@db**: không áp dụng

## Tasks

### Task 1 — `critical-constraints.md`

Đổi `last_updated` thành `2026-09-24`. Thay các hàng #2, #6, #7:

```
| 2 | Mọi plan — kết quả Gemini, thực đơn mẫu, và (giai đoạn 4) plan client gửi lên — phải qua `parsePlanContent()` trong `backend_api/src/plan/plan-validation.ts`: class-validator theo hợp đồng BRD 6.2, rồi `findPlanViolations()` (khoảng calo theo `MealType`: breakfast 250–600, lunch/dinner 400–800; calo lệch không quá 15% so với 4P+4C+9F; không trùng món). Mã ngoài danh sách (ví dụ `meal_type: "Bữa sáng"`) bị coi là sai — không bao giờ cho qua khi tra cứu không ra. | BRD NFR-4. Bản cũ (`nutrition-sanity.util.ts`, đã xoá) tra khoảng calo theo chuỗi tiếng Việt và cho qua khi không khớp, nên Gemini chỉ cần viết khác một chữ là lọt kiểm tra. Không đạt → gọi lại 1 lần → thực đơn mẫu. |
| 6 | Một kế hoạch 3 ngày không được lặp lại tên món (so sánh không phân biệt hoa thường, khoảng trắng). | BRD FR-2.1. Kiểm bằng code trong `findPlanViolations()`, không chỉ dặn trong prompt. |
| 7 | `grocery_list` luôn do server tính lại bằng `buildGroceryList()` (`backend_api/src/plan/plan-assembly.ts`) từ `ingredients` có cấu trúc của mọi món, gộp theo nhóm + tên + đơn vị. Không lấy danh sách đi chợ từ Gemini hay từ client. Đổi món / feedback = thay món rồi tính lại. | BRD FR-3.1, FR-4.1 (v2.3.0), quyết định Q1 giai đoạn 1. Thay cho quy tắc cũ cập nhật từng phần theo `source_meal_ids` — cách cũ để danh sách lệch thực đơn ngay từ khi Gemini tạo plan. |
```

Thêm sau hàng #11:

```
| 12 | Dị ứng, chấn thương, tình trạng sức khoẻ (`restrictions`) chỉ đi kèm từng request: **không** lưu vào DB (kể cả `PlanRecord` ở giai đoạn 3), **không** ghi log request body hay nội dung Gemini trả về. Log chỉ ghi thông báo lỗi và vi phạm hợp đồng. | BRD NFR-7 — dữ liệu cá nhân nhạy cảm theo Nghị định 13/2023/NĐ-CP. Thông báo lỗi của `JSON.parse` có trích nội dung đầu vào, nên `gemini.service.ts` thay bằng thông báo chung. |
| 13 | Calo mục tiêu = `max(TDEE + điều chỉnh, BMR)` (`computeDailyTarget()` trong `backend_api/src/plan/daily-target.ts`); điều chỉnh: cut −300, bulk +250. Mọi tính năng về sau (feedback, đổi món) cũng không được hạ calo xuống dưới BMR, và phải tự tính lại BMR từ `profile`, không tin số `bmr` client gửi lên. | BRD FR-1.3, FR-1.5, FR-5.2 (v2.3.0), quyết định D1 và Q4. Không có sàn thì người nhỏ con ít vận động bị đặt mục tiêu dưới BMR (ví dụ 1040 kcal khi BMR 1117). |
| 14 | Feedback có dấu hiệu nguy hiểm (`danger_sign`: chóng mặt, khó thở bất thường, đau ngực) → **không** áp các quy tắc điều chỉnh thông thường; trả `safety_warning` khuyên ngừng tập và hỏi ý kiến bác sĩ; ngày kế tiếp chỉ nghỉ hoặc đi bộ nhẹ. | BRD FR-5.2 (v2.3.0), quyết định D2. Chưa có code — làm ở giai đoạn 4, cần test riêng. |
| 15 | Mỗi lần gọi Gemini có timeout `GEMINI_TIMEOUT_MS` (mặc định 15 000 ms); hết giờ → dùng thực đơn mẫu ngay, không gọi lại. **Không** truyền `retryOptions` cho SDK `@google/genai`. | BRD NFR-1. SDK có cơ chế tự gọi lại (mặc định 5 lần, chờ tới 60 giây) nhưng chỉ bật khi có `retryOptions`; bật lên sẽ chồng lên lần gọi lại của `PlanService` và kéo request lên vài phút. |
| 16 | `plan_id` (UUID), `meal_id` (`m{ngày}_{thứ tự}`), `exercise_id` (`e{ngày}_{thứ tự}`) do server gán trong `assemblePlan()`. Gemini không sinh ID; nếu có thì bị bỏ. | BRD 6.2 (v2.3.0). ID do Gemini tự đặt không đảm bảo duy nhất, trong khi đổi món và lịch sử cần ID tin được. |
```

### Task 2 — Bài wiki mới `plan-data-contract.md`

`docs/knowledge/wiki/plan-data-contract.md`:

```markdown
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
```

### Task 3 — `wiki-triggers.md`, `INDEX.md`, `log.md`

`wiki-triggers.md`: đổi `last_updated` thành `2026-09-24`; thay hai hàng trigger theo đường dẫn file:

```
| `backend_api/src/plan/gemini.service.ts`, `ai_workspace/**` | `gemini-integration.md` |
| `backend_api/src/plan/dto/**`, `backend_api/src/plan/enums/**`, `backend_api/src/plan/data/**`, `backend_api/src/plan/plan-validation.ts`, `backend_api/src/plan/plan-assembly.ts`, `backend_api/src/plan/daily-target.ts`, `backend_api/src/plan/plan-warnings.ts`, `backend_api/src/plan/text.util.ts`, `backend_api/src/plan/plan.service.ts` | `plan-data-contract.md` |
```

`INDEX.md`: đổi dòng `_Cập nhật lần cuối: …_` thành `_Cập nhật lần cuối: 2026-09-24_` và thêm hàng sau `[[reference-materials]]`:

```
| [[plan-data-contract]]      | Hợp đồng dữ liệu plan: luồng generate-plan, hai lớp DTO, mã cố định, danh sách đi chợ |
```

`log.md`: thêm dòng cuối:

```
2026-09-24 — Giai đoạn 1 (PLAN.md): viết lại ràng buộc #2, #6, #7 theo hướng B; thêm #12–#16 (dữ liệu sức khoẻ, sàn BMR, dấu hiệu nguy hiểm, timeout Gemini, ID do server gán); thêm bài [[plan-data-contract]]; cập nhật wiki-triggers theo file mới trong `backend_api/src/plan/`
```

### Task 4 — `CLAUDE.md`

Trong mục "Repository layout and current state", thay câu:

```
Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to a bundled `sample-plan.json` when `GEMINI_API_KEY` is unset or the AI response fails the nutrition sanity check (BRD NFR-2, NFR-4).
```

bằng:

```
Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to the bundled 3-day `sample-plan.json` when `GEMINI_API_KEY` is unset, Gemini times out, or its output fails contract validation (BRD NFR-2, NFR-4) — the response's `source` field (`gemini` / `sample`) says which one was used.
```

Trong mục "Backend architecture", thay toàn bộ bullet `- \`src/plan/\` — …` cùng các bullet con của nó bằng:

```
- `src/plan/` — `POST /api/v1/generate-plan`. The contract is BRD.md §6 (v2.3.0); the wiki article `docs/knowledge/wiki/plan-data-contract.md` maps it to code. Flow:
  1. `dto/create-plan.dto.ts` validates the request. `dto/restrictions.dto.ts` holds three free-text fields (`allergies`, `injuries`, `health_conditions`, ≤300 chars, default `''`) — sensitive health data: never persist or log them (BRD NFR-7).
  2. `daily-target.ts` — pure `computeDailyTarget()`: BMI, BMR (Mifflin-St Jeor), TDEE, target = `max(TDEE + goal adjustment, BMR)` (cut −300, bulk +250), macros 25/45/30. Returns `flooredToBmr` so the service can add a warning.
  3. `gemini.service.ts` — `@google/genai` (`client.models.generateContent()`, result via the `response.text` property; the old `@google/generative-ai` SDK is deprecated — don't reintroduce it). `buildPlanPrompt()` puts user text inside a `<du_lieu_nguoi_dung>` block after `sanitizeUserText()` and reads the allowed codes and calorie bounds from the enums/`CALORIE_BOUNDS`. Per-call timeout `GEMINI_TIMEOUT_MS` (default 15000) → `GeminiTimeoutError`. Never pass `retryOptions` to the SDK (it would retry up to 5× with up to 60 s backoff).
  4. `plan-validation.ts` — `parsePlanContent()`: class-validator against `dto/plan-content.dto.ts`, then `findPlanViolations()` (calorie bounds per `MealType`, calories within 15% of 4P+4C+9F, no repeated dish). Unknown enum values must fail, never skip a check.
  5. `plan.service.ts` — orchestration: Gemini (retry once unless it timed out) → otherwise `data/sample-plan.json`, validated by the same function (`sample-plan.spec.ts` guards the file) → `plan-assembly.ts`. Warning texts live in `plan-warnings.ts`.
  6. `plan-assembly.ts` — `assemblePlan()` assigns `plan_id` (UUID) and `m{day}_{n}` / `e{day}_{n}` ids, orders meals, and `buildGroceryList()` recomputes the grocery list from structured ingredients. Grocery lists are never taken from Gemini or the client.
  - `dto/meal-plan-response.dto.ts` holds the response classes Swagger shows; `MealDto` / `ExerciseDto` extend the content DTOs with ids. `enums/` holds the fixed codes (meal type, ingredient category/unit, muscle group, exercise tags, plan source).
```

### Task 5 — `docs/SETUP_CREDENTIALS.md`

Trong mục 1.2, sau khối `.env`, thêm:

```
Tuỳ chọn: `GEMINI_TIMEOUT_MS=15000` — giới hạn thời gian mỗi lần gọi Gemini (ms). Hết giờ thì backend dùng thực đơn mẫu ngay.
```

Trong mục 1.3, thay bước 2 (từ `2. Gọi thử` tới hết hai gạch đầu dòng bên dưới) bằng:

```
2. Gọi thử `POST /api/v1/generate-plan` trên Swagger (`http://localhost:3000/docs`) và xem trường `source` trong kết quả:
   - `"source": "gemini"` → Gemini thật đã trả kết quả hợp lệ.
   - `"source": "sample"` → backend đã dùng thực đơn mẫu. Xem terminal đang chạy backend để biết lý do: dòng `Lỗi khi gọi Gemini (lần 1): …` (khoá sai, hết hạn mức, model sai, hết giờ) hoặc `Kết quả Gemini không đạt hợp đồng (lần 1): …` (Gemini trả sai định dạng hay số liệu; backend tự gọi lại một lần). App vẫn chạy bình thường vì backend tự dùng dữ liệu mẫu.
```

Trong bảng mục 1.5, thêm hai hàng cuối:

```
| Log báo `Gemini không phản hồi sau 15000 ms` | Mạng chậm hoặc model phản hồi chậm | Thử lại; nếu thường xuyên xảy ra, tăng `GEMINI_TIMEOUT_MS` trong `.env` rồi khởi động lại backend |
| Log báo `Kết quả Gemini không đạt hợp đồng` lặp lại nhiều lần | Prompt chưa đủ chặt với model đang dùng | Thử prompt bằng `ai_workspace/` (mục 1.4), chỉnh rồi chép sang `backend_api/src/plan/gemini.service.ts` |
```

### Task 6 — Changelog trong `README.md`

Thêm ngay dưới dòng mở đầu mục `## Nhật ký thay đổi (Changelog)` (trước `### BRD v2.2.0`):

```
### BRD v2.3.0 — 2026-09-24
- Chốt hợp đồng API (BRD mục 6) trước khi làm frontend. Nguyên liệu từng món có định lượng; danh sách đi chợ do server tự tính nên luôn khớp thực đơn. Bữa ăn, nhóm cơ, loại nguyên liệu dùng mã cố định. Server tự gán ID. Response có `source` (Gemini thật hay thực đơn mẫu) và `warnings`
- Hồ sơ: dị ứng, chấn thương, tình trạng sức khoẻ do người dùng tự nhập; chỉ lưu trên máy, backend không lưu và không ghi log. Calo mục tiêu không bao giờ thấp hơn BMR; mức điều chỉnh đổi thành −300 (giảm mỡ) / +250 (tăng cơ) theo thiết kế giao diện
- Feedback cuối ngày gồm 3 câu hỏi, có quy tắc riêng cho dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực); feedback ngày 3 tạo luôn plan mới. Thêm hợp đồng cho đổi món, đổi bài tập, feedback (BRD mục 6.4) — code làm ở giai đoạn 4
- Backend: mọi kết quả Gemini được kiểm tra theo hợp đồng trước khi trả về (trước đây Gemini chỉ cần viết tên bữa ăn khác đi là lọt bước kiểm tra calo); thực đơn mẫu đủ 3 ngày; mỗi lần gọi Gemini có giới hạn 15 giây; thêm 29 test
```

### Task 7 — `docs/PLAN.md`

- Đổi tiêu đề `## Giai đoạn 1 — Chốt hợp đồng API · S` thành `## Giai đoạn 1 — Chốt hợp đồng API · M`.
- Đổi `- [ ] **1.1**`, `**1.2**`, `**1.3**`, `**1.4**` thành `- [x]`.
- Thêm ngay dưới dòng `→ Sau giai đoạn này, BRD mục 6 là hợp đồng đầy đủ…`:

```
Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-1-api-contract.md` (hướng B, quyết định Q1–Q4), plan `docs/superpowers/plans/phase-1-api-contract/`.
```

- Thay bốn bước của giai đoạn 2 bằng:

```
- [ ] **2.1** Unit test `computeDailyTarget()` (`daily-target.ts`): mở rộng từ 3 ca đã có ở giai đoạn 1 ra đủ nam/nữ × 3 mức vận động × 3 mục tiêu (tiêu chí nghiệm thu tuần 5)
- [x] **2.2** ~~Unit test `isNutritionWithinBounds()`~~ — hàm này đã được thay bằng `findPlanViolations()` và có test ở giai đoạn 1 (`plan-validation.spec.ts`)
- [ ] **2.3** Unit test `PlanService.generatePlan()` với Gemini giả: kết quả hợp lệ → `source: gemini`; sai hợp đồng → gọi lại → thực đơn mẫu; hết giờ → không gọi lại; khoá sai → thực đơn mẫu (trường hợp không có khoá đã có test ở giai đoạn 1)
- [ ] **2.4** E2E `POST /api/v1/generate-plan`: payload đúng → 200, payload sai → 400, `restrictions` kiểu mảng cũ → 400 (test e2e cần bật `ValidationPipe` giống `main.ts`)
```

### Task 8 — Kiểm tra

```bash
grep -c 'plan-data-contract' docs/knowledge/wiki/INDEX.md
grep -c '^- \[x\] \*\*1\.' docs/PLAN.md
grep -rn "nutrition-sanity\|plan.interface" CLAUDE.md docs/knowledge/wiki/wiki-triggers.md || echo "sạch"
```

Mong đợi: `1`; `4`; `sạch`.
