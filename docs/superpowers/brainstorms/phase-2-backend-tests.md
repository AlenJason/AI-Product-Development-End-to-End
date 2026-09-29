# Brainstorm: Giai đoạn 2 — Backend: kiểm thử nền
**Source:** `docs/PLAN.md` (giai đoạn 2, bước 2.1, 2.3, 2.4; 2.2 đã xong ở giai đoạn 1) + `BRD.md` v2.3.0 (FR-1.3, FR-1.5, NFR-1, NFR-2, NFR-4, NFR-7, mục 6.1–6.2)
**Date:** 2026-09-24

## 1. Phạm vi

- **2.1** Ma trận test `computeDailyTarget()`: nam/nữ × 3 mức vận động × 3 mục tiêu — tiêu chí nghiệm thu "tính đúng công thức BMR/TDEE".
- **2.3** `PlanService.generatePlan()` với Gemini giả: hợp lệ → `source: gemini`; sai hợp đồng → gọi lại → thực đơn mẫu; hết giờ → không gọi lại; khoá sai → thực đơn mẫu.
- **2.4** E2E `POST /api/v1/generate-plan` với `ValidationPipe` giống `main.ts`: 200 / 400 / `restrictions` kiểu mảng cũ → 400.

Giai đoạn 1 để lại một khoảng trống lớn: **`GeminiService` chưa có test nào**. Timeout, lỗi JSON và cấu hình gọi SDK mới chỉ được viết theo tài liệu. Brainstorm này đề xuất đưa phần đó vào giai đoạn 2.

## 2. Ngữ cảnh đã nạp

- Wiki: `INDEX.md`, `wiki-triggers.md`, `critical-constraints.md` (#1–#16), `plan-data-contract.md` (khớp từ khoá BMR/TDEE/calo). Từ khoá "gemini" và "endpoint/validation" trỏ tới `gemini-integration.md` và `api-routes.md` — **vẫn chưa tồn tại** (lỗ hổng đã ghi ở giai đoạn 1).
- Điều kiện nạp ràng buộc: **có** — test gọi endpoint và gọi dịch vụ bên ngoài (Gemini). Liên quan trực tiếp: #3 (khoá chỉ qua `.env`/`ConfigService`), #4 (ESM `.js`), #12 (không ghi log dữ liệu sức khoẻ), #13 (sàn BMR), #15 (timeout, không truyền `retryOptions`), #16 (ID do server gán).
- Code: `daily-target.ts`, `plan.service.ts`, `gemini.service.ts`, `main.ts`, `test/app.e2e-spec.ts`, `vitest.config*.ts`, `tsconfig.build.json`.

## 3. Phát hiện — kiểm chứng bằng SDK `@google/genai` 2.24 thật, server giả cục bộ, không cần khoá

| # | Phát hiện | Cách kiểm |
|---|---|---|
| F1 | **Hết giờ:** SDK ném `DOMException` tên `AbortError` (là `instanceof Error`) đúng lúc hết `httpOptions.timeout` (đo 310 ms với timeout 300 ms). Cách nhận diện ở `gemini.service.ts` (giai đoạn 1) **đúng**. | Server không bao giờ trả lời |
| F2 | **Khoá sai (HTTP 400):** SDK ném `ApiError`, `status: 400`, `message` là nguyên văn JSON lỗi của Google. `PlanService` ghi message này vào log — chấp nhận được vì lỗi của Google không chứa nội dung prompt. | Server trả 400 như Google |
| F3 | **HTTP 500: đúng 1 request**, SDK không tự gọi lại khi không truyền `retryOptions`. Ràng buộc #15 đúng — nhưng `package.json` khai `^2.24.0`, lần `npm install` sau có thể kéo bản 2.x mới hơn; cần test khoá hành vi này. | Server trả 500, đếm request |
| F4 | SDK gửi `POST /v1beta/models/{model}:generateContent`, body chứa prompt và `responseMimeType`; đọc `candidates[0].content.parts[].text` thành `response.text`. Đủ để dựng server Gemini giả trả đúng định dạng. | Server trả 200 |
| F5 | **E2E hiện không dùng cấu hình của `main.ts`** (`ValidationPipe`, Swagger), nên không test được 400. Chép lại cấu hình vào test sẽ lệch dần với `main.ts`. | Đọc `test/app.e2e-spec.ts` |
| F6 | **Test đọc `.env` thật của máy dev** (`ConfigModule.forRoot()`). Nếu máy có `GEMINI_API_KEY` thật, test e2e sẽ gọi Gemini thật: chậm, tốn hạn mức, kết quả không cố định. | Đọc `app.module.ts` |
| F7 | `GeminiService` tự tạo `GoogleGenAI` bên trong, không có chỗ nào để trỏ sang server giả. | Đọc `gemini.service.ts` |
| F8 | Chưa có test nào cho: nhánh gọi lại / hết giờ / khoá sai của `PlanService`, toàn bộ `GeminiService`, và ràng buộc #12 (log không chứa dữ liệu sức khoẻ). | `npm test` hiện có 31 test |

## 4. Các hướng tiếp cận

### Hướng A — Đúng phạm vi PLAN, giả ở ranh giới `GeminiService`

Ma trận 2.1; `PlanService` với object `GeminiService` giả; e2e thay `GeminiService` bằng bản giả qua `overrideProvider`.

- **Ưu:** ít việc nhất, không đụng code chính.
- **Nhược:** `GeminiService` vẫn không có test (F8); không có gì chặn SDK đổi hành vi khi nâng phiên bản (F3); e2e không chạy qua code gọi Gemini thật.

### Hướng B — Giả module SDK bằng `vi.mock('@google/genai')`

Như A, cộng test `GeminiService` với SDK bị thay bằng class giả; e2e cũng dùng SDK giả nên chạy qua `GeminiService` thật.

- **Ưu:** không cần sửa code chính; test `GeminiService` được.
- **Nhược:** class giả do mình tự viết theo hiểu biết về SDK — nếu SDK đổi cách trả `response.text` hay cách báo lỗi, test vẫn xanh (không bắt được F3). Mock module ESM trong vitest thêm một lớp "phép màu" khó đọc với sinh viên.

### Hướng C — SDK thật + server Gemini giả cục bộ *(khuyến nghị)*

- Thêm biến tuỳ chọn `GEMINI_BASE_URL` (để trống = Google thật) — `GeminiService` truyền vào `httpOptions.baseUrl` của SDK. Một dòng code.
- Helper `test/fake-gemini-server.ts`: server HTTP cục bộ trả phản hồi đúng định dạng Gemini (F4), đếm request, lưu body; có chế độ trả kết quả hợp lệ / JSON sai hợp đồng / 400 / 500 / không trả lời.
- `GeminiService` test với SDK thật trỏ vào server giả: hết giờ → `GeminiTimeoutError`; 500 → đúng 1 request (#15); văn bản không phải JSON → lỗi chung không chứa nội dung (#12); prompt có khối `<du_lieu_nguoi_dung>`.
- `PlanService` test với object `GeminiService` giả (logic gọi lại / fallback / cảnh báo, chạy nhanh) + kiểm log không chứa dữ liệu sức khoẻ (#12).
- E2E dựng app bằng đúng cấu hình của `main.ts` (tách thành `configureApp()` dùng chung, F5), ghim `GEMINI_API_KEY`/`GEMINI_BASE_URL`/`GEMINI_TIMEOUT_MS` vào server giả trước khi tạo app (F6) → chạy trọn đường HTTP → validate → `PlanService` → `GeminiService` → SDK thật → server giả.
- Ma trận 2.1 với bảng số liệu tính độc lập (không tính lại bằng chính công thức trong code).

- **Ưu:** kiểm cả hành vi thật của SDK (F1–F4), bắt được thay đổi khi nâng phiên bản; e2e đúng nghĩa; không mock module.
- **Nhược:** thêm một biến môi trường vào code chính (dù để trống là như cũ); test hết giờ phải chờ thật (đặt timeout 200 ms nên vẫn nhanh).

## 5. Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| #3 khoá chỉ qua `.env`/`ConfigService` | ✓ | ✓ | ✓ — test dùng khoá giả, không bao giờ cần khoá thật |
| #12 không log dữ liệu sức khoẻ | chỉ kiểm ở `PlanService` | kiểm được | kiểm được ở cả `PlanService` và luồng e2e |
| #15 không `retryOptions` | không kiểm | không kiểm được (SDK giả) | **kiểm bằng số request thật** |
| F6 không gọi Gemini thật khi chạy test | ✓ (override) | ✓ (mock) | ✓ (ghim env về server giả) |

## 6. Khuyến nghị: Hướng C

Hai lỗi đáng sợ nhất ở giai đoạn này đều nằm ở ranh giới với SDK: hết giờ bị nhận diện sai sẽ khiến backend gọi lại và người dùng chờ gấp đôi; SDK âm thầm bật tự gọi lại sau một lần nâng phiên bản sẽ khiến request kéo dài vài phút. Chỉ hướng C kiểm được hai điều đó bằng SDK thật. Cái giá là một biến môi trường tuỳ chọn, để trống thì hành vi y như cũ.

## 7. Edge case cho chính bộ test

- Máy dev có `.env` chứa khoá thật → test phải ghim biến môi trường **trước** khi tạo app; `@nestjs/config` ưu tiên biến môi trường có sẵn hơn file `.env`.
- Mỗi file test chạy trong worker riêng của vitest, nên sửa `process.env` trong e2e không lan sang file khác; vẫn khôi phục lại sau khi chạy.
- Server giả nghe cổng ngẫu nhiên (`listen(0)`), đóng trong `afterAll`, để chạy song song không đụng cổng.
- Test hết giờ dùng `GEMINI_TIMEOUT_MS=200` để cả bộ test vẫn chạy trong vài giây.
- Ma trận 2.1: số liệu mong đợi tính bằng một cách độc lập (script Python), ghi cứng vào test; test tính lại bằng chính công thức trong code thì luôn xanh và không chứng minh được gì.
- Log của Nest trong test: tắt ở e2e để đầu ra gọn; riêng test #12 bật và theo dõi `Logger`.

## 8. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **Chọn hướng C?** Kéo theo thêm biến tuỳ chọn `GEMINI_BASE_URL` vào `.env.example` (để trống = Google thật).
2. **Thêm GitHub Actions chạy build + test backend mỗi lần push?** Không có trong PLAN. Lợi: giảng viên thấy dấu ✓/✗ ngay trên GitHub cho từng commit. Chi phí: một file workflow, dùng phút chạy miễn phí của GitHub; chạm vào CI nên cần bạn đồng ý.

## 9. Quyết định (2026-09-24)

| Câu hỏi | Quyết định |
|---|---|
| Q1 | **Hướng C** — SDK thật + server Gemini giả; thêm biến tuỳ chọn `GEMINI_BASE_URL`. |
| Q2 | **Có GitHub Actions**: build + unit test + e2e của `backend_api/` và kiểm kiểu `ai_workspace/` mỗi lần push. Chưa đưa Flutter vào CI vì widget test Flutter đang fail sẵn (sửa ở PLAN 5.6). CI không cần khoá nào vì toàn bộ test dùng server Gemini giả. |

**Bước tiếp theo:** `/feature-plan phase-2-backend-tests`.
