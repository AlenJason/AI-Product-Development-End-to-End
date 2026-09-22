---
last_updated: 2026-09-22
---

# Ràng buộc cứng của dự án

Các quy tắc bắt buộc phải biết trước khi đụng vào `backend_api/src/plan/`, prompt Gemini, hoặc hợp đồng request/response. Được bổ sung dần khi phát hiện thêm ràng buộc trong quá trình phát triển.

## Danh sách quy tắc

| # | Quy tắc | Lý do |
|---|---|---|
| 1 | TDEE = BMR (công thức Mifflin-St Jeor) × hệ số vận động. Hệ số cố định: ít vận động 1.2, vận động nhẹ 1.375, vận động nhiều 1.55 (`ACTIVITY_MULTIPLIER` trong `backend_api/src/plan/enums/activity-level.enum.ts`). | BRD FR-1.5. Form onboarding luôn phải thu thập `activity_level` — thiếu trường này thì TDEE sai hẳn, không chỉ là kém chính xác. |
| 2 | Khoảng calo hợp lý theo bữa: Bữa sáng 250–600 kcal, Bữa trưa/Bữa tối 400–800 kcal (`CALORIE_BOUNDS` trong `backend_api/src/plan/nutrition-sanity.util.ts`). | BRD NFR-4. Gemini có thể "bịa" số liệu calo không nhất quán giữa các lần gọi; số liệu ngoài khoảng này phải retry (tối đa 1 lần) rồi fallback, không được hiển thị thẳng cho người dùng. |
| 3 | `GEMINI_API_KEY` đọc qua `@nestjs/config` từ file `.env`, không hardcode. `.env` đã được gitignore ở cả `backend_api/` và `ai_workspace/`. | BRD mục 4 (Backend NestJS). Lộ key trong repo sinh viên là sự cố thực tế rất hay gặp. |
| 4 | `backend_api/` là package ESM (`"type": "module"` trong `package.json`) — import tương đối phải có đuôi `.js` dù file nguồn là `.ts` (ví dụ `from './app.service.js'`). | Cơ chế resolve module ESM của Node yêu cầu vậy; thiếu đuôi file có thể build qua `tsc` nhưng lỗi lúc chạy — rất dễ bỏ sót. |
| 5 | Mọi file không phải `.ts` nằm dưới `backend_api/src/` mà cần tồn tại lúc chạy (ví dụ `plan/data/sample-plan.json`) phải được khai báo trong `compilerOptions.assets` của `nest-cli.json`. | `nest build` mặc định chỉ compile `.ts`. Lỗ hổng này từng gây lỗi `ENOENT` (500) khi gọi `/api/v1/generate-plan` lúc mới dựng khung — đã fix, tránh lặp lại. |
| 6 | Một kế hoạch 3 ngày không được lặp lại tên món giữa các ngày. | BRD FR-2.1 — hiện ràng buộc qua chỉ dẫn trong prompt Gemini, chưa có validate ở tầng code. |
| 7 | Khi đổi món (FR-4.1), phải cập nhật lại danh sách đi chợ qua `GroceryItem.source_meal_ids`: chỉ bỏ nguyên liệu khi `source_meal_ids` của nó rỗng sau khi gỡ id món bị đổi, ngược lại chỉ gỡ id món đó khỏi mảng. | BRD FR-4.1. Schema (`backend_api/src/plan/interfaces/plan.interface.ts`) đã mô hình hóa `source_meal_ids`; endpoint đổi món bản thân nó chưa được cài đặt. |
| 8 | SDK Gemini dùng trong `backend_api/src/plan/gemini.service.ts` và `ai_workspace/generate-plan-experiment.ts` phải là `@google/genai` (`GoogleGenAI`, gọi qua `client.models.generateContent()`, đọc kết quả qua property `response.text`). Không dùng lại `@google/generative-ai` — SDK đó đã bị Google khai tử. | Phát hiện + đã migrate 2026-09-22 (xem [[reference-materials]]). Dùng SDK cũ sẽ không còn được Google hỗ trợ/cập nhật. |
| 9 | Model Gemini mặc định là `gemini-3.8-flash` (`.env.example` của `backend_api/` và `ai_workspace/`, BRD.md mục 4). | Đã cập nhật 2026-09-22, thay cho `gemini-2.5-flash` đã lỗi thời (xem [[reference-materials]]). |

_File này được feature-explore và feature-build load khi phát hiện công việc liên quan tới ràng buộc._
