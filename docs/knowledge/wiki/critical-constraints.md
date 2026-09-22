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
| 10 | Từ BRD v2.2.0: xác thực **chỉ** qua Google Sign-In (`google-auth-library` verify ID Token phía backend → phát JWT riêng qua `@nestjs/jwt`). Backend **không được tự lưu hoặc xử lý mật khẩu** người dùng dưới bất kỳ hình thức nào. Lưu trữ dùng SQLite qua `@nestjs/typeorm`, file `database.sqlite` phải nằm trong `.gitignore`. | Quyết định 2026-09-22 (BRD mục 4, FR-6, FR-7, NFR mục 7.5) — chưa có code, chỉ mới là quyết định kiến trúc. Tự lưu mật khẩu là rủi ro bảo mật không cần thiết khi Google đã lo phần đó. |
| 11 | `database.sqlite` nằm trên **máy chạy `backend_api/`**, không phải trên điện thoại người dùng. Lịch sử kế hoạch (FR-7) xem xuyên thiết bị được là nhờ mọi thiết bị cùng gọi vào một backend, một file DB — khác hẳn `shared_preferences` (luôn cục bộ theo máy). Muốn demo/nộp bài ổn định với nhiều thiết bị thật, cần deploy `backend_api/` lên nơi chạy liên tục (không chỉ chạy tạm trên localhost), yêu cầu này đúng với bất kỳ DB nào, không riêng SQLite. | Làm rõ 2026-09-22 sau khi có nhầm lẫn rằng SQLite "lưu cục bộ trên thiết bị" giống `shared_preferences` (BRD.md mục 7.6). |

_File này được feature-explore và feature-build load khi phát hiện công việc liên quan tới ràng buộc._
