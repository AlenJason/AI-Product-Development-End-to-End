# Tích hợp Gemini (Hợp đồng, Lỗi & SDK Hành vi)

Backend kết nối Gemini (Gemini 3.8 Flash) bằng SDK chính thức `@google/genai` để sinh thực đơn.

## Hành vi thật của SDK (đã kiểm chứng)

- **Gọi lại**: SDK có cơ chế tự gọi lại (mặc định 5 lần, chờ tới 60 giây) nếu bật `retryOptions`. **KHÔNG BẬT** tuỳ chọn này, vì nó sẽ chồng lên vòng lặp gọi lại của `PlanService`, kéo thời gian chờ của người dùng lên vài phút. Đã kiểm chứng: lỗi 500, SDK không bật `retryOptions` chỉ gọi đúng 1 request.
- **Hết giờ**: Nếu Google không phản hồi trước `timeout`, SDK ném lỗi `AbortError` (mã HTTP thường thấy phía dưới là 504 Deadline Exceeded). Backend bọc thành `GeminiTimeoutError`.
- **Lỗi khoá / hạn mức**: Trả về `ApiError` 400 (khoá sai) hoặc 429 (hết token).
- **JSON rác**: Nếu người dùng chèn câu lệnh độc hại khiến Gemini lờ `responseMimeType: application/json` và trả về chuỗi văn bản thường (có thể lặp lại dữ liệu sức khoẻ), lỗi sẽ văng ở `JSON.parse`. Trình xử lý chỉ báo "không phải JSON hợp lệ", **tuyệt đối không trích xuất văn bản đó ra ngoài** (NFR-7, #12).

## Môi trường test không tốn token

Vì test tự động (nhất là CI) không có khoá thật, và nếu chạy thật sẽ tốn thời gian + dễ bị flaky:

- E2E và test `GeminiService` dán chặt vào **server Gemini giả cục bộ** (`backend_api/test/fake-gemini-server.ts`).
- Server này lập lên một máy chủ HTTP đơn giản, lắng nghe trên `127.0.0.1`.
- SDK thật được trỏ về máy chủ này qua `GEMINI_BASE_URL`. Trả lời như Google thật: `candidates[0].content.parts[0].text`.
- Có thể ép server giả treo (timeout), trả rác, lỗi 500, lỗi 400 để test các đường rẽ nhánh của `PlanService`.
- Khi deploy thật, chỉ cần để trống `GEMINI_BASE_URL` trong `.env`.

Tầng `PlanService` (`src/plan/plan.service.spec.ts`) dùng object `GeminiService` giả bằng `vi.fn()` để test logic gọi lại cho nhanh.

## Thử prompt với Gemini thật

`ai_workspace/` (`npm run experiment`) chép y nguyên prompt của `buildPlanPrompt()` và in thời gian phản hồi. Khi sửa prompt ở backend, sửa cả bản trong `ai_workspace/generate-plan-experiment.ts`.
