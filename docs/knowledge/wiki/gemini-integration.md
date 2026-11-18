# Tích hợp Gemini (Hợp đồng, Lỗi & SDK Hành vi)

Backend kết nối Gemini (mặc định `gemini-3.5-flash`) bằng SDK chính thức `@google/genai`. Các luồng tạo plan, đổi món, đổi bài và cân đối món ăn dùng `GeminiService.generateJson()`; kiểm tra hợp đồng và fallback thuộc service gọi nó.

## Hành vi thật của SDK (đã kiểm chứng)

- **Gọi lại**: SDK có cơ chế tự gọi lại (mặc định 5 lần, chờ tới 60 giây) nếu bật `retryOptions`. **KHÔNG BẬT** tuỳ chọn này. Các service đi qua `generateWithRetry()` (`src/plan/gemini-retry.ts`): gọi lại tối đa một lần khi lỗi hoặc đầu ra sai hợp đồng, chỉ khi còn ít nhất 5 giây trong ngân sách tổng.
- **Hết giờ**: Ngân sách mặc định là 20 giây mỗi lần gọi và 40 giây tổng. SDK có thể ném `AbortError`; Google cũng có thể trả `ApiError` 504 `DEADLINE_EXCEEDED` trước khi SDK tự ngắt. Cả hai được nhận diện là timeout và không gọi lại; caller dùng kho dự phòng hoặc giữ nguyên món, tuỳ luồng.
- **Lỗi khoá / hạn mức**: Trả về `ApiError` 400 (khoá sai) hoặc 429 (hết token).
- **JSON rác**: Nếu người dùng chèn câu lệnh độc hại khiến Gemini lờ `responseMimeType: application/json` và trả về chuỗi văn bản thường (có thể lặp lại dữ liệu sức khoẻ), lỗi sẽ văng ở `JSON.parse`. Trình xử lý chỉ báo "không phải JSON hợp lệ", **tuyệt đối không trích xuất văn bản đó ra ngoài** (NFR-7, #12).

## Môi trường test không tốn token

Vì test tự động (nhất là CI) không có khoá thật, và nếu chạy thật sẽ tốn thời gian + dễ bị flaky:

- E2E và test `GeminiService` dùng **server Gemini giả cục bộ** (`backend_api/test/fake-gemini-server.ts`).
- Server này lập lên một máy chủ HTTP đơn giản, lắng nghe trên `127.0.0.1`.
- SDK thật được trỏ về máy chủ này qua `GEMINI_BASE_URL`. Trả lời như Google thật: `candidates[0].content.parts[0].text`.
- Có thể ép server giả treo (timeout), trả rác, lỗi 500, lỗi 400 để test các đường rẽ nhánh của `PlanService`.
- Khi deploy thật, chỉ cần để trống `GEMINI_BASE_URL` trong `.env`.

Unit test dùng `GeminiService` giả hoặc `geminiAnswering()` trong `backend_api/test/plan-fixtures.ts`; E2E có luồng qua SDK thật tới server giả. `createTestApp()` ghim các biến môi trường test trước khi nạp `AppModule`, nên test không dùng key hoặc DB thật của máy phát triển.

## Thử prompt với Gemini thật

`ai_workspace/` (`npm run experiment`) thử prompt tạo plan; các prompt đổi món, đổi bài tập và cân đối món ăn hiện nằm trong `backend_api/src/plan/adjust/adjust-prompts.ts` và chưa có bản tương ứng trong `ai_workspace/`. `npm run measure:gemini` gọi API thật, tốn quota và chỉ chạy thủ công, không chạy trong test/CI.
