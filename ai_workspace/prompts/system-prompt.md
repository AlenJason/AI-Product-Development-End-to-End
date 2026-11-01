# System prompt — SmartFit AI dùng Groq

Cập nhật 26/10/2026. Groq là nhà cung cấp mặc định cho tạo kế hoạch, đổi món, đổi bài và cân đối bữa ăn sau feedback. Không duy trì bản prompt sao chép ở Markdown hoặc script thử nghiệm.

## Nguồn prompt dùng thật

- `backend_api/src/plan/gemini.service.ts`: `buildPlanPrompt()` và các hàm dùng chung. Tên file giữ tương thích; trong chế độ Groq, prompt này được gửi tới Groq, không gọi Google.
- `backend_api/src/plan/adjust/adjust-prompts.ts`: prompt đổi món, đổi bài và cân đối ba bữa cho ngày tiếp theo.
- `backend_api/src/plan/groq-plan.service.ts`: gọi Groq với JSON mode và giới hạn thời gian. Chưa dùng strict JSON Schema; backend kiểm cấu trúc và nghiệp vụ trước khi chấp nhận.

## Yêu cầu được dựng từ code

Kế hoạch có đúng ba ngày, mỗi ngày ba bữa breakfast/lunch/dinner và một buổi tập. Khoảng calo tính từ mục tiêu cá nhân và BMR; macro kiểm theo 4P+4C+9F. Các mã nguyên liệu, đơn vị, nhóm cơ và tags lấy từ enum.

Dị ứng, chấn thương và bệnh nền được đặt trong khối dữ liệu riêng, bỏ dấu phân cách có thể phá thẻ. Tuổi, vận động và thai kỳ quyết định mức bài tập tối đa. Prompt yêu cầu tên buổi tập/động tác tiếng Việt, không ghế/chai nước/tạ; yêu cầu ngôn ngữ và dụng cụ hiện chưa có validator ngữ nghĩa độc lập.

Model chỉ sinh nội dung. Backend gán IDs, daily_target, danh sách đi chợ, source và warnings. Kết quả sai validation bị loại; sau tối đa hai lần thử trong budget thì dùng dữ liệu mẫu/kho dự phòng. Dấu hiệu nguy hiểm trong feedback được xử lý bằng luật an toàn, không gửi cho model để tự quyết định.

## Thử prompt

Điền `GROQ_API_KEY` trong backend_api/.env, không đưa khóa vào client hoặc tài liệu. Build backend rồi chạy:

```powershell
cd backend_api
npm.cmd run build
node --env-file=.env scripts/test-groq-plan.mjs
node --env-file=.env scripts/test-groq-adjustments.mjs
```

Hoặc từ ai_workspace chạy `npm run experiment` để thử tạo kế hoạch bằng cùng pipeline. Script Gemini cũ chỉ dành cho lựa chọn tương thích `experiment:gemini:legacy`.

Chi tiết cấu hình và giới hạn: [GROQ_TRIAL.md](../../backend_api/GROQ_TRIAL.md). Tiến độ dự án: [PLAN.md](../../docs/PLAN.md).
