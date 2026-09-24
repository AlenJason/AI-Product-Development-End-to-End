---
last_updated: 2026-09-24
tags: [gemini, sdk, kiem-thu]
---

# Tích hợp Gemini

Backend gọi Gemini qua SDK `@google/genai` ở đúng một chỗ: `GeminiService` (`backend_api/src/plan/gemini.service.ts`). `generateJson(prompt)` dùng chung cho tạo plan, đổi món, đổi bài tập, cân đối món ăn; vòng gọi lại chung là `generateWithRetry()` (`gemini-retry.ts`). Bài này ghi hành vi thật của SDK — đã kiểm ngày 2026-09-24 bằng SDK 2.24 chạy với server Gemini giả cục bộ, không cần khoá — và cách test phần này mà không bao giờ gọi Google. Ràng buộc liên quan: [[critical-constraints]] #8, #9, #12, #15, #17. Hợp đồng dữ liệu: [[plan-data-contract]].

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

`GEMINI_API_KEY` (bắt buộc để dùng AI thật), `GEMINI_MODEL` (mặc định `gemini-3.5-flash`), `GEMINI_THINKING` (`off` | `low` | `default`, mặc định `off`), `GEMINI_TIMEOUT_MS` (mỗi lần gọi, mặc định 20 000), `GEMINI_TOTAL_TIMEOUT_MS` (cả lần gọi lại, mặc định 40 000), `GEMINI_BASE_URL` (chỉ dùng khi test — để trống là gọi Google thật). `GEMINI_THINKING` sai giá trị → backend không khởi động. Khoá tạo trên AI Studio trước 28/05/2026 là loại Standard và bị từ chối từ tháng 9/2026 — xem [[reference-materials]] mục 1.4.

## Đo với Gemini thật (2026-09-24)

`npm run build && npm run measure:gemini` (`backend_api/scripts/measure-gemini.mjs`) chạy bản build với **đúng** prompt và bước kiểm của backend, ghi thời gian, số token suy nghĩ, kết quả kiểm. Tốn hạn mức — chỉ chạy tay (#17). Kết quả với khoá gói miễn phí, 3 hồ sơ (dị ứng hải sản + đau gối; nam 2806 kcal; đậu phộng + sữa + đau lưng + tiểu đường) và 1 lần đổi món mỗi cấu hình:

| `gemini-3.5-flash` | Tạo plan | Đạt | Đổi món |
|---|---|---|---|
| suy nghĩ mặc định (~7000 token suy nghĩ) | 37–42 s | 3/3 | 13 s |
| `GEMINI_THINKING=low` | 18–27 s | 2/3 | 8 s |
| `GEMINI_THINKING=off` | 8–13 s | 2/3 (1 JSON bị cắt giữa chừng) | 3 s |

Qua backend thật (`off`, HTTP): `generate-plan` 14,3 s, `source: gemini`; đổi món 2,8 s.

| Điều đã thấy | Hệ quả |
|---|---|
| Phần lớn thời gian là "suy nghĩ" trước khi trả lời, không phải do project hay mạng | Mặc định `GEMINI_THINKING=off`, timeout 20 s/lần, tổng 40 s (#15) |
| Tắt suy nghĩ mà prompt chỉ có chữ người dùng nhập → Gemini cho cá nước ngọt khi dị ứng "hải sản", chống đẩy quỳ gối khi đau gối | Prompt ghi rõ danh sách backend sẽ kiểm (`ingredientAvoidRule()`, `exerciseAvoidRule()`, #23) |
| `gemini-3.8-flash` liên tục 503 "high demand"; không nhận `thinkingLevel: MINIMAL` (400) | Mặc định đổi sang `gemini-3.5-flash` (#9) |
| Gói miễn phí: **20 lần gọi/ngày cho mỗi model** (429 `GenerateRequestsPerDayPerProjectPerModel-FreeTier`); cũng có giới hạn theo phút | Hết thì backend dùng dữ liệu soạn sẵn; đổi `GEMINI_MODEL` để có hạn mức riêng của model khác |
| Lỗi của SDK chứa nguyên khối JSON của Google (dài, có mảng `details`) | `describeGeminiError()` chỉ log mã lỗi + thông báo chính |

## Test không cần khoá

`backend_api/test/fake-gemini-server.ts` dựng server HTTP cục bộ trả phản hồi đúng định dạng Gemini, đếm và lưu request, có chế độ trả JSON / văn bản / lỗi HTTP / không trả lời. SDK thật được trỏ vào đó qua `GEMINI_BASE_URL`:

- `src/plan/gemini.service.spec.ts` — hành vi bảng trên, gồm cả đếm request khi lỗi 500.
- `test/generate-plan.e2e-spec.ts`, `test/adjust.e2e-spec.ts` — trọn đường HTTP → service → `GeminiService` → SDK → server giả. App tạo bằng `createTestApp()` (`test/test-app.ts`), hàm này ghim `GEMINI_*` (cùng DB và chế độ đăng nhập) **trước** khi nạp `AppModule`, vì máy dev có thể có khoá thật trong `.env`.

Tầng `PlanService` (`src/plan/plan.service.spec.ts`) dùng object `GeminiService` giả bằng `vi.fn()` để test logic gọi lại cho nhanh. Các service của giai đoạn 4 dùng `geminiAnswering()` trong `test/plan-fixtures.ts` (giả `generateJson()`).

## Thử prompt với Gemini thật

`ai_workspace/` (`npm run experiment`) chép y nguyên prompt của `buildPlanPrompt()` và in thời gian phản hồi. Khi sửa prompt ở backend, sửa cả bản trong `ai_workspace/generate-plan-experiment.ts`. Prompt của đổi món, đổi bài tập, cân đối món ăn (`src/plan/adjust/adjust-prompts.ts`) chưa có bản trong `ai_workspace/`.
