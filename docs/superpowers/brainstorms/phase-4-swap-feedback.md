# Brainstorm: Giai đoạn 4 — Backend: Đổi món, đổi bài tập, feedback (FR-4, FR-5)
**Source:** `docs/PLAN.md` (giai đoạn 4, bước 4.1–4.6) + `BRD.md` v2.4.0 (FR-1.5, FR-4, FR-5, mục 6.2, 6.4, NFR-1, NFR-4, NFR-7, NFR-8, NFR-9)
**Date:** 2026-09-24

## 1. Phạm vi

- **4.1** Bộ khớp từ khoá dị ứng/chấn thương cho chế độ giả lập, nhận ra được cả chữ không dấu.
- **4.2** `POST /api/v1/meals/swap`: đổi một món, calo lệch ≤ ±10%, tránh hạn chế người dùng nhập, không trùng món trong plan.
- **4.3** `POST /api/v1/exercises/swap`: động tác nhẹ hơn, cùng nhóm cơ, tránh chấn thương đã khai.
- **4.4** `POST /api/v1/feedback`: 3 câu hỏi (D2), quy tắc cố định cho bài tập, cân đối món ăn, dấu hiệu nguy hiểm, feedback ngày 3 tạo plan mới (FR-5.3).
- **4.5** Test không cần khoá; dấu hiệu nguy hiểm có test riêng.
- **4.6** *(tuỳ chọn)* `responseSchema` của Gemini.

Cả ba endpoint không lưu trạng thái: nhận `{ profile, plan, … }`, trả plan mới (BRD 6.4).

## 2. Ngữ cảnh đã nạp

- **Wiki:** `INDEX.md`, `wiki-triggers.md`, `critical-constraints.md` (#1–#22), `plan-data-contract.md` (khớp từ khoá calo/BMR/macro), `gemini-integration.md` (Gemini/prompt), `auth-and-history.md` (lịch sử).
- **Điều kiện nạp ràng buộc:** **có** — endpoint mới, gọi Gemini, có thể ghi DB (lịch sử).
- **Ràng buộc liên quan trực tiếp:**
  - #2: mọi plan, kể cả plan client gửi lên, phải qua kiểm tra hợp đồng.
  - #5: file dữ liệu `.json` phải có trong asset.
  - #7: danh sách đi chợ luôn tính lại toàn bộ.
  - #12: không lưu, không log dữ liệu sức khoẻ.
  - #13: không hạ calo dưới BMR; tự tính lại BMR từ `profile`.
  - #14: dấu hiệu nguy hiểm.
  - #15: timeout Gemini, không truyền `retryOptions`.
  - #16: ID do server gán.
  - #17: test không gọi dịch vụ thật.
  - #20: smoke test bản build.
  - #22: mã lỗi 401/404.
- **Mâu thuẫn giữa tài liệu (cần sửa, không tự chọn bên nào):**
  - **PLAN 4.2 lệch ràng buộc #7 và BRD FR-4.1 (v2.3.0).** PLAN ghi "backend tự cập nhật `grocery_list` theo `source_meal_ids`". Quyết định Q1 của giai đoạn 1 và BRD đã đổi thành tính lại toàn bộ bằng `buildGroceryList()`. Đi theo #7; sửa câu này trong PLAN.
  - **PLAN 4.3 ngầm hiểu đổi bài tập dùng Gemini** ("Fallback: `data/swap-exercises.json`"). BRD FR-4.2 không yêu cầu AI; FR-4.1 (đổi món) thì có. Xem câu hỏi Q2.
  - **PLAN 4.4 và BRD FR-5.2** ghi cân đối món ăn "cần AI". Có một cách tất định làm được việc này mà không cần AI. Xem câu hỏi Q3.
- **Wiki đã cũ (sửa trong giai đoạn này):**
  - `gemini-integration.md` còn tả e2e tự ghim biến môi trường, trong khi từ giai đoạn 3 việc đó đã chuyển sang `createTestApp()`.
  - `plan-data-contract.md` ghi BRD v2.3.0.
  - `wiki-triggers.md` trỏ tới `api-routes.md`, một bài chưa tồn tại.

## 3. Phát hiện — kiểm chứng ngày 2026-09-24

| # | Phát hiện | Cách kiểm |
|---|---|---|
| F1 | **Tổng calo của plan không khớp mục tiêu, và có thể thấp hơn BMR.** (a) Khoảng calo từng bữa (NFR-4: sáng 250–600, trưa/tối 400–800) giới hạn tổng ngày tối đa **2200 kcal**. Trong khi đó **7/18** hồ sơ trong ma trận test có mục tiêu trên 2200, cao nhất 2806 kcal (nam, vận động nhiều, tăng cơ). Prompt yêu cầu Gemini cả mục tiêu lẫn khoảng calo từng bữa, tức một việc không thể làm đúng cả hai. (b) `findPlanViolations()` không kiểm **tổng calo của ngày**, nên plan thiếu xa mục tiêu vẫn được nhận. (c) Thực đơn mẫu có **1540–1595 kcal/ngày** bất kể hồ sơ, thấp hơn BMR (1649) của **9/18** hồ sơ (mọi hồ sơ nam), trong khi `daily_target` hiển thị ≥ 1679. Hệ quả: sàn BMR (FR-1.5, #13) chỉ đúng với con số hiển thị, không đúng với thực đơn thật | Tính từ `sample-plan.json` và bảng `MATRIX` trong `daily-target.spec.ts`; đọc `plan-validation.ts` |
| F2 | Trả lại phần hạn chế "không nhận ra" trong `warnings` (như PLAN 4.1 gợi ý) sẽ **đưa chữ người dùng nhập vào response**. Response này được lưu vào lịch sử khi đã đăng nhập, tức lưu dữ liệu sức khoẻ vào DB, vi phạm #12 và NFR-7. E2e của giai đoạn 2 cũng khoá rằng response không chứa văn bản sức khoẻ | Đọc `history.service.ts`, `generate-plan.e2e-spec.ts` |
| F3 | Bỏ dấu tiếng Việt bằng `normalize('NFD')` **không tách được `đ`/`Đ`**, phải thay tay. Người dùng gõ không dấu ("hai san", "dau goi") rất phổ biến | Chạy thử bằng Node |
| F4 | `ExerciseContentDto` không có trường độ khó, nên "nhẹ hơn" (FR-4.2) không đo được với động tác do Gemini sinh. Kho động tác soạn sẵn cần có `level` | Đọc `plan-content.dto.ts` |
| F5 | `MealPlanResponseDto` đã có đủ decorator `class-validator`, nên dùng lại được để kiểm plan client gửi lên. Nhưng `findPlanViolations()` nhận `PlanContentDto`; cần thêm bước kiểm `day_number`, `meal_id`, `exercise_id` đúng vị trí, vì ID quyết định món nào bị đổi | Đọc `meal-plan-response.dto.ts`, `plan-assembly.ts` |
| F6 | Endpoint không lưu trạng thái, nên **gửi feedback hai lần cho cùng một ngày sẽ cộng dồn điều chỉnh** (ví dụ −1 hiệp hai lần). Server không phát hiện được; app phải khoá nút sau khi gửi (giai đoạn 7) | Suy ra từ BRD 6.4 |
| F7 | Người dùng sửa hồ sơ (ví dụ đổi mục tiêu) rồi đổi món trên plan cũ: `daily_target` trong plan gửi lên khác với mục tiêu tính lại từ `profile`. Kiểm plan cũ theo mục tiêu mới có thể báo sai | Suy ra từ FR-1.6 + #13 |
| F8 | File dữ liệu mới đặt trong `src/plan/data/` được glob `plan/data/*.json` trong `nest-cli.json` copy sẵn; đặt ở thư mục khác thì phải thêm asset (#5). Smoke test hiện chỉ gọi `generate-plan`, nên không bắt được file dữ liệu của endpoint mới bị thiếu | Đọc `nest-cli.json`, `scripts/smoke-test.mjs` |
| F9 | Giới hạn DTO: `sets` 1–6, `duration_minutes` 5–60, 1–8 động tác. Quy tắc "+1 hiệp", "thêm giãn cơ", "đi bộ nhẹ" phải nằm trong các giới hạn này | Đọc `plan-content.dto.ts` |
| F10 | Plan khoảng 8 KB (đo ở smoke test giai đoạn 3); request `{profile, plan}` dưới 10 KB, dưới giới hạn body mặc định 100 KB của Express | Đo `length(plan_json)` |

## 4. Các hướng tiếp cận

### Hướng A — Gemini cho mọi thứ, kho soạn sẵn chỉ để dự phòng

Đổi món, đổi bài tập, cân đối món ăn sau feedback đều gọi Gemini; chỉ dấu hiệu nguy hiểm dùng quy tắc.

- **Ưu:** kết quả đa dạng.
- **Nhược:**
  - Mọi thao tác chậm 2–5 giây, tệ nhất 30 giây.
  - "Nhẹ hơn" không kiểm được (F4).
  - Chế độ giả lập gần như không có tác dụng.
  - Khó test.

### Hướng B — Quy tắc + kho soạn sẵn là chính, Gemini chỉ ở chỗ BRD yêu cầu *(khuyến nghị)*

- **Đổi món:** Gemini trước (FR-4.1 yêu cầu AI), kết quả kiểm chặt. Hỏng thì lấy từ kho món Việt `data/swap-meals.json`, lọc bằng bộ khớp từ khoá.
- **Đổi bài tập:** chỉ dùng kho `data/swap-exercises.json` (có `level`, `tags`, `muscle_group`) và quy tắc.
- **Bài tập sau feedback:** quy tắc cố định (FR-5.2 đã ghi "không cần AI").
- **Bộ khớp từ khoá dùng chung:** lọc kho khi đổi món/đổi bài, và lọc luôn thực đơn mẫu của `generate-plan` (đúng tinh thần D4: "chế độ giả lập: code khớp từ khoá").
- **Ưu:**
  - Nhanh (< 10 ms khi không cần Gemini).
  - Tất định, test được.
  - Chế độ giả lập dùng được thật.
  - "Nhẹ hơn" đo bằng `level`.
- **Nhược:** phải soạn hai kho dữ liệu (khoảng 20 món và 30 động tác) và giữ chúng đúng hợp đồng (có test như `sample-plan.spec.ts`).

### Hướng C — Không dùng Gemini ở giai đoạn 4

Mọi thứ lấy từ kho và quy tắc.

- **Ưu:** đơn giản nhất.
- **Nhược:** **vi phạm FR-4.1** ("Backend gọi AI sinh 1 món khác"). Có khoá Gemini mà đổi món chỉ xoay vòng trong kho nhỏ.

### Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| #2 kiểm mọi plan | ✓ (khó hơn: nhiều đầu ra AI) | ✓ — kết quả Gemini, kho, plan client đều qua kiểm tra; kho có test riêng | ✓ |
| #5 asset | ✓ | ✓ nếu đặt dữ liệu trong `src/plan/data/` | ✓ |
| #7 danh sách đi chợ | ✓ | ✓ tính lại toàn bộ sau mỗi thay đổi | ✓ |
| #12 dữ liệu sức khoẻ | rủi ro: nhiều prompt hơn, phải sanitize ở mọi chỗ | ✓ — cảnh báo chung, không nhắc lại chữ người dùng (F2) | ✓ |
| #13 sàn BMR | khó kiểm: phụ thuộc Gemini | ✓ kiểm bằng code | ✓ |
| #14 dấu hiệu nguy hiểm | ✓ | ✓ quy tắc riêng, ưu tiên cao nhất | ✓ |
| #15 timeout | 3 chỗ gọi Gemini | 1–2 chỗ | không gọi |
| #16 ID do server gán | ✓ | ✓ | ✓ |
| #17 test không gọi thật | ✓ nhưng cần kịch bản server giả cho mọi thao tác | ✓ | ✓ |
| BRD FR-4.1 (AI đổi món) | ✓ | ✓ | ✗ |

## 5. Thiết kế đề xuất (hướng B, để `/feature-plan` chi tiết hoá)

**Nhận plan từ client** (dùng chung cho 3 endpoint):

1. `ValidationPipe` kiểm `profile` theo `CreatePlanDto` và `plan` theo `MealPlanResponseDto`.
2. Kiểm thêm:
   - `day_number` = vị trí;
   - bữa đúng thứ tự sáng/trưa/tối;
   - `meal_id` = `m{ngày}_{thứ tự}`, `exercise_id` = `e{ngày}_{thứ tự}`;
   - `findPlanViolations()` (#2).
   Sai → 400.
3. Tính lại mục tiêu từ `profile` (#13).
4. Bỏ qua `daily_target`, `grocery_list`, `warnings` client gửi. Riêng `daily_target` dùng để so sánh: khác mục tiêu tính lại → **409** "Kế hoạch được tạo cho hồ sơ khác — hãy tạo kế hoạch mới" (F7).
5. Kết quả lắp lại bằng `assemblePlan()`:
   - giữ `plan_id`;
   - ID gán lại theo vị trí;
   - danh sách đi chợ tính lại (#7);
   - `warnings` tính lại từ `profile`.

**Bộ khớp từ khoá** (`data/restriction-keywords.json` + `restriction-matcher.ts`):

- Chuẩn hoá: bỏ dấu, `đ` → `d` (F3), chữ thường.
- Ánh xạ nhóm → từ khoá nguyên liệu. Ví dụ "hải sản" → tôm, cua, mực, cá, nghêu, sò, ốc, hến; "đậu phộng/lạc"; "sữa"; "trứng".
- Ánh xạ chấn thương → tag cần tránh: gối → `jumping`, `kneeling`; cổ tay → `wrist_load`; lưng → `back_load`; vai → `overhead`.
- Trả về: từ khoá nguyên liệu cần tránh, tag cần tránh, và **có hay không** phần không nhận ra.
- Có phần không nhận ra → một câu cảnh báo chung: "Chế độ mẫu chỉ nhận ra một số dị ứng, chấn thương phổ biến; hãy tự kiểm tra lại…". Câu này **không** trích lại chữ người dùng (F2).

**Đổi món** (`POST /api/v1/meals/swap`):

1. Có khoá → Gemini sinh **một** món. Kiểm:
   - `MealContentDto`, cùng `meal_type`;
   - calo trong ±10% món cũ và trong khoảng của bữa;
   - macro khớp calo;
   - tên không trùng món nào trong plan (kể cả món bị thay);
   - không chứa từ khoá dị ứng đã nhận ra (kiểm lại cả đầu ra Gemini).
2. Sai → gọi lại 1 lần (không gọi lại nếu hết giờ, #15) → kho.
3. Kho không còn món hợp lệ → **422** "Không tìm được món thay thế phù hợp". App giữ plan cũ.

**Đổi bài tập** (`POST /api/v1/exercises/swap`):

- Ứng viên: cùng `muscle_group`, `level` thấp hơn động tác bị thay, không có tag cần tránh, không trùng động tác trong ngày.
- Động tác không có trong kho (do Gemini sinh) → coi là mức khó nhất.
- Không có ứng viên → 422.

**Feedback** (`POST /api/v1/feedback`) — quy tắc cho buổi tập ngày kế tiếp, theo thứ tự ưu tiên:

| Điều kiện | Tác động |
|---|---|
| `danger_sign` | Thay cả buổi tập bằng "Nghỉ ngơi — đi bộ nhẹ 10–15 phút nếu thấy khoẻ". **Bỏ qua mọi quy tắc khác, kể cả ăn uống.** `safety_warning.message`: khuyên ngừng tập, hỏi ý kiến bác sĩ, gọi 115 nếu triệu chứng nặng |
| `joint_pain` | Bỏ động tác có tag `jumping`, `kneeling`; thay bằng động tác cùng nhóm cơ trong kho nếu có. Hết động tác → đi bộ nhẹ |
| `hard` hoặc `fatigued` | Mỗi động tác −1 hiệp (tối thiểu 1); thời lượng ×0,75 (tối thiểu 10 phút) |
| `sore` | Động tác cùng nhóm cơ với ngày vừa tập: −1 hiệp (không cộng dồn với dòng trên); thêm 1 động tác giãn cơ (tối đa 8 động tác, F9) |
| `easy`, không có trạng thái tiêu cực | Mỗi động tác +1 hiệp (tối đa 6) |
| Còn lại | Giữ nguyên |

Hai điểm chung:

- Chấn thương khai trong `profile` luôn được tôn trọng khi chọn động tác thay.
- `normal` đi cùng trạng thái khác thì bị bỏ qua (BRD 6.4).

Ăn uống: theo quyết định Q3. Ngày 3 → tạo plan mới bằng đúng đường `generate-plan` (Gemini kèm tóm tắt feedback trong prompt, hoặc thực đơn mẫu), rồi áp quy tắc trên cho ngày 1 của plan mới; `plan_id` mới (FR-5.3).

**Sửa F1 (nếu Q1 = sửa ngay):**

- Khoảng calo từng bữa tính **theo tỉ lệ mục tiêu** thay cho số cố định. Ví dụ sáng 20–35%, trưa/tối 30–45% của `target_calories` (plan chốt con số cụ thể).
- Tổng calo mỗi ngày trong khoảng [max(0,9 × mục tiêu, BMR); 1,1 × mục tiêu].
- Thực đơn mẫu và món trong kho được **nhân khẩu phần** (calo, macro, lượng nguyên liệu) cho khớp mục tiêu. Hàm `scaleMeal()` dùng chung, nhờ đó món trong kho luôn vừa ±10% khi đổi món.
- Đây là thay đổi NFR-4 → BRD lên v2.5.0.

**Độ trễ ước tính:**

| Endpoint | Độ trễ |
|---|---|
| Đổi món qua Gemini | 2–5 giây thường gặp, tệ nhất 30 giây (2 lần × 15 giây) |
| Đổi món qua kho | < 10 ms |
| Đổi bài tập | < 10 ms |
| Feedback ngày 1–2 | < 10 ms, hoặc bằng thời gian gọi Gemini nếu Q3 chọn Gemini |
| Feedback ngày 3 | bằng `generate-plan` |

**Test:**

- **Unit:**
  - bộ khớp từ khoá: có dấu, không dấu, `đ`, phần không nhận ra;
  - từng quy tắc feedback và thứ tự ưu tiên;
  - **dấu hiệu nguy hiểm test riêng** (#14);
  - kho dữ liệu đúng hợp đồng;
  - đổi món với `GeminiService` giả.
- **E2E:** ba endpoint ở chế độ giả lập; một đường đổi món qua SDK thật và server Gemini giả; response không chứa chữ người dùng nhập (#12).
- **Smoke test:** thêm đổi món, đổi bài tập, feedback, để bắt file dữ liệu thiếu trong `dist/` (F8, #20).

**4.6 `responseSchema`:** khuyến nghị **để sau**. Chưa có khoá thật để đo nó giảm lỗi bao nhiêu, còn server Gemini giả chỉ kiểm được request có gửi schema hay không. Bước kiểm hợp đồng hiện có vẫn phải giữ. Làm khi đo được bằng `ai_workspace/`.

## 6. Edge case

- **Plan client gửi lên:**
  - bị sửa tay (calo vô lý, trùng món, ID sai vị trí) → 400;
  - thiếu `restrictions` trong `profile` → mặc định rỗng như `generate-plan`.
- **ID không tồn tại:** `meal_id`/`exercise_id` không có trong plan → 400. `day_number` ngoài 1–3 → 400.
- **Hồ sơ đã đổi so với lúc tạo plan** → 409 (F7).
- **Đổi món nhiều lần liên tiếp:** không được quay về món vừa bị thay ngay lần sau nếu còn lựa chọn khác. Chọn ngẫu nhiên trong nhóm ứng viên, có thể cố định kết quả khi test.
- **Đổi món khi dị ứng loại hết món cùng bữa trong kho** → 422 với thông báo dễ hiểu.
- **Gemini sinh món chứa nguyên liệu dị ứng mà prompt đã dặn tránh** → bị loại nhờ kiểm lại bằng bộ khớp từ khoá. Chỉ bắt được từ khoá đã biết; phần còn lại dựa vào Gemini và cảnh báo chung.
- **Feedback:**
  - `body_states` rỗng → 400 (BRD: ít nhất 1);
  - trùng giá trị → bỏ trùng;
  - `normal` đi cùng trạng thái khác → bỏ `normal`;
  - `danger_sign` đi cùng bất kỳ gì → quy tắc nguy hiểm thắng (#14);
  - gửi hai lần cùng ngày → cộng dồn (F6, app phải khoá nút).
- **Plan có `source: sample` được đổi một món bằng Gemini:** `source` giữ theo plan (nguồn của phần lớn nội dung). Không thêm nguồn riêng cho từng món.
- **Hết giờ Gemini khi đổi món** → dùng kho ngay, không gọi lại (#15).
- **Lịch sử:** theo quyết định Q4. Nếu có ghi DB thì lỗi ghi → vẫn trả plan kèm cảnh báo `historyNotSaved`, như `generate-plan`.

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **F1 — tổng calo không khớp mục tiêu, thực đơn mẫu thấp hơn BMR:**
   - (a) sửa ngay trong giai đoạn 4: khoảng calo theo tỉ lệ mục tiêu, kiểm tổng calo ngày, nhân khẩu phần thực đơn mẫu và kho; BRD lên v2.5.0 *(khuyến nghị — đây là giai đoạn cuối của backend, và đổi món, feedback đều dựa trên tổng calo)*;
   - (b) ghi lại, để sau;
   - (c) chỉ nới khoảng calo cố định (thực đơn mẫu vẫn dưới BMR).
2. **Đổi bài tập:**
   - (a) chỉ dùng kho + quy tắc, không Gemini *(khuyến nghị; FR-4.2 không yêu cầu AI, "nhẹ hơn" đo được bằng `level`)*;
   - (b) Gemini trước, kho dự phòng (như PLAN 4.3 đang viết).
3. **Cân đối món ăn sau feedback "ăn nhiều hơn" / "ăn ít hơn":**
   - (a) tất định bằng nhân khẩu phần: ăn nhiều → ngày kế tiếp −10% (không dưới BMR); ăn ít → giữ nguyên, không ăn bù. Chạy được cả khi không có khoá *(khuyến nghị)*;
   - (b) Gemini sinh lại 3 món ngày kế tiếp; không có khoá thì giữ nguyên (như BRD/PLAN đang viết);
   - (c) như (a) nhưng ăn ít → +10% ngày kế tiếp.
4. **Lịch sử:**
   - (a) đã đăng nhập thì đổi món/đổi bài/feedback **cập nhật** plan đã lưu (nếu `plan_id` là của người đó), và plan mới từ feedback ngày 3 được **lưu mới**; guard tuỳ chọn như `generate-plan` *(khuyến nghị — đăng nhập thiết bị khác thấy bản mới nhất, đúng FR-7.3)*;
   - (b) chỉ lưu plan mới từ feedback ngày 3;
   - (c) không ghi gì — lịch sử chỉ gồm plan tạo bằng `generate-plan`.

## 8. Quyết định (2026-09-24)

| Câu hỏi | Quyết định | Hệ quả cho `/feature-plan` |
|---|---|---|
| Q1 | **Sửa ngay trong giai đoạn 4** | Khoảng calo từng bữa theo tỉ lệ mục tiêu; kiểm tổng calo ngày trong [max(0,9 × mục tiêu, BMR); 1,1 × mục tiêu]; nhân khẩu phần thực đơn mẫu và món trong kho cho khớp mục tiêu (`scaleMeal()`). Áp cho cả `generate-plan`. Đổi NFR-4 → **BRD v2.5.0**. Giai đoạn 4 thành cỡ **L** |
| Q2 | **Gemini trước, kho dự phòng** (như PLAN 4.3) | Không kiểm được "nhẹ hơn" về ngữ nghĩa, nên kết quả Gemini phải qua các điều kiện đo được: cùng `muscle_group`; số hiệp ≤ động tác bị thay; tag ⊆ tag của động tác bị thay (không thêm kiểu tải mới); không có tag cần tránh theo chấn thương; không trùng động tác trong ngày. Sai → gọi lại 1 lần (không gọi lại nếu hết giờ) → kho có `level` |
| Q3 | **Gemini sinh lại 3 món ngày kế tiếp**; không có khoá thì giữ nguyên món | Mức mục tiêu truyền cho Gemini (suy ra, plan ghi rõ để đổi được): ăn nhiều → max(0,9 × mục tiêu, BMR); ăn ít → giữ mục tiêu, không ăn bù; `on_plan` → không gọi Gemini. Kết quả phải đúng hợp đồng, đúng khoảng calo mới (Q1), không trùng món với các ngày khác, không chứa từ khoá dị ứng. Không có khoá, hoặc Gemini hỏng cả 2 lần → giữ món cũ, thêm câu cảnh báo "chưa cân đối lại món ăn" |
| Q4 | **Cập nhật + lưu plan mới** | Guard tuỳ chọn trên cả 3 endpoint. Đã đăng nhập: đổi món/đổi bài/feedback ngày 1–2 **cập nhật** `plan_json` nếu `plan_id` là của người đó (không phải của mình, hoặc không có trong lịch sử → bỏ qua, không báo lỗi); feedback ngày 3 **lưu mới**. Ghi lỗi → vẫn trả plan kèm `historyNotSaved`. BRD FR-7.1 và mục 6.3/6.4 ghi thêm |

Không hỏi, theo khuyến nghị (đổi được nếu muốn):

- Bộ khớp từ khoá lọc luôn thực đơn mẫu của `generate-plan` (D4).
- Không tìm được món/động tác thay → 422.
- Plan tạo cho hồ sơ khác → 409.
- 4.6 `responseSchema` để sau.

**Bước tiếp theo:** `/feature-plan phase-4-swap-feedback`.
