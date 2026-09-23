---
last_updated: 2026-09-24
tags: [gemini, sdk, kiem-thu]
---

# Tích hợp Gemini

Backend gọi Gemini qua SDK `@google/genai` ở đúng một chỗ: `GeminiService` (`backend_api/src/plan/gemini.service.ts`). Bài này ghi hành vi thật của SDK — đã kiểm ngày 2026-09-24 bằng SDK 2.24 chạy với server Gemini giả cục bộ, không cần khoá — và cách test phần này mà không bao giờ gọi Google. Ràng buộc liên quan: [[critical-constraints]] #8, #9, #12, #15, #17. Hợp đồng dữ liệu: [[plan-data-contract]].

## Hành vi SDK đã kiểm chứng

| Tình huống | SDK làm gì | `GeminiService` xử lý |
|---|---|---|
| Thành công | `POST {baseUrl}/v1beta/models/{model}:generateContent`, body có prompt và `generationConfig.responseMimeType`; đọc `candidates[0].content.parts[].text` thành `response.text` | `JSON.parse` → trả JSON thô cho `PlanService` kiểm hợp đồng |
| Hết `httpOptions.timeout` | Ném `DOMException` tên `AbortError` (là `instanceof Error`), đúng lúc hết giờ | Đổi thành `GeminiTimeoutError` → `PlanService` không gọi lại |
| HTTP 4xx/5xx (ví dụ khoá sai: 400) | Ném `ApiError`, có `status`; `message` là nguyên văn JSON lỗi của Google | Ném tiếp → `PlanService` log thông báo, gọi lại 1 lần, rồi dùng thực đơn mẫu |
| HTTP 500 khi **không** truyền `retryOptions` | Gửi đúng **1** request, không tự gọi lại | — |
| HTTP 500 khi **có** `retryOptions` | Tự gọi lại tới 5 lần, chờ tới 60 giây giữa các lần | Cấm dùng (#15) |
| `response.text` không phải JSON | — | Ném lỗi chung "không phải JSON hợp lệ", không đính kèm lỗi gốc của `JSON.parse` vì nó trích nội dung (#12) |

## Cấu hình

`GEMINI_API_KEY` (bắt buộc để dùng AI thật), `GEMINI_MODEL` (mặc định `gemini-3.8-flash`), `GEMINI_TIMEOUT_MS` (mặc định 15 000), `GEMINI_BASE_URL` (chỉ dùng khi test — để trống là gọi Google thật). Khoá tạo trên AI Studio trước 28/05/2026 là loại Standard và bị từ chối từ tháng 9/2026 — xem [[reference-materials]] mục 1.4.

## Test không cần khoá

`backend_api/test/fake-gemini-server.ts` dựng server HTTP cục bộ trả phản hồi đúng định dạng Gemini, đếm và lưu request, có chế độ trả JSON / văn bản / lỗi HTTP / không trả lời. SDK thật được trỏ vào đó qua `GEMINI_BASE_URL`:

- `src/plan/gemini.service.spec.ts` — hành vi bảng trên, gồm cả đếm request khi lỗi 500.
- `test/generate-plan.e2e-spec.ts` — trọn đường HTTP → `PlanService` → `GeminiService` → SDK → server giả. Ghim biến môi trường **trước** khi nạp `AppModule` vì máy dev có thể có khoá thật trong `.env`.

Tầng `PlanService` (`src/plan/plan.service.spec.ts`) dùng object `GeminiService` giả bằng `vi.fn()` để test logic gọi lại cho nhanh.

## Thử prompt với Gemini thật

`ai_workspace/` (`npm run experiment`) chép y nguyên prompt của `buildPlanPrompt()` và in thời gian phản hồi. Khi sửa prompt ở backend, sửa cả bản trong `ai_workspace/generate-plan-experiment.ts`.
