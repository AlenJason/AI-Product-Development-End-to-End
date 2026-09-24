# SmartFit AI – Adaptive Meal & Workout Planner

Đồ án môn **AI Product Development End-to-End** — Trường Đại học Công nghệ Thông tin và Truyền thông Việt - Hàn (VKU).

Ứng dụng di động gợi ý và tự động điều chỉnh thực đơn (món Việt) cùng lịch tập tại nhà theo chu kỳ **3 ngày cuốn chiếu**, dựa trên thể trạng và phản hồi hằng ngày của người dùng. Xem đầy đủ bài toán, kiến trúc hệ thống, JSON schema và roadmap tại **[BRD.md](BRD.md)**.

## Tech stack

| Thành phần | Công nghệ |
|---|---|
| Frontend | Flutter (mobile + web) |
| Backend | NestJS (TypeScript) |
| AI Engine | Google Gemini API (Structured Output JSON) |

## Cấu trúc thư mục

```
frontend_app/    Ứng dụng Flutter (đang phát triển UI, dùng dữ liệu mẫu)
backend_api/     API NestJS — generate-plan (Gemini hoặc thực đơn mẫu), đổi món, đổi bài tập, feedback, đăng nhập Google, lịch sử (SQLite)
ai_workspace/    Script Node/TS thử nghiệm prompt & schema Gemini, độc lập với backend
docs/            Kế hoạch triển khai, hướng dẫn gắn khoá, wiki nội bộ
BRD.md           Tài liệu đặc tả yêu cầu (nguồn spec chính thức)
```

Dự án chạy được ngay khi chưa có khoá nào (chế độ giả lập: thực đơn mẫu thay cho Gemini, đăng nhập bằng `mock:<email>` thay cho Google). Muốn dùng Gemini hay Google Sign-In thật: xem [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md).

## Bắt đầu

### Frontend (Flutter)

```bash
cd frontend_app
flutter pub get
flutter run -d chrome   # hoặc flutter run cho thiết bị/máy ảo
```

### Backend (NestJS)

```bash
cd backend_api
npm install
cp .env.example .env   # để nguyên = chạy giả lập (thực đơn mẫu, đăng nhập giả lập); điền khoá = dùng thật
npm run start:dev      # http://localhost:3000, Swagger UI tại /docs, /health báo đang dùng Gemini hay dữ liệu mẫu
```

### AI Workspace (thử nghiệm prompt Gemini)

```bash
cd ai_workspace
npm install
cp .env.example .env   # điền GEMINI_API_KEY
npm run experiment
```

## Trạng thái dự án

Tiến độ từng bước (có checkbox) theo dõi tại **[docs/PLAN.md](docs/PLAN.md)**. Tiêu chí nghiệm thu gốc ở [BRD.md mục 9](BRD.md#9-tiêu-chí-nghiệm-thu-môn-học-rubric-checklist).

Kết quả build và test tự động của từng commit: tab [Actions](https://github.com/AlenJason/AI-Product-Development-End-to-End/actions) trên GitHub.

## Nhật ký thay đổi (Changelog)

Đối chiếu theo phiên bản BRD (mục "Phiên bản" trong [BRD.md](BRD.md)), để giảng viên/trợ giảng theo dõi tiến độ trực tiếp trên repo mà không cần đọc từng commit.

### BRD v2.5.0 — 2026-09-24
- Giai đoạn 4 — đổi món, đổi bài tập, feedback cuối ngày: `POST /api/v1/meals/swap`, `/exercises/swap`, `/feedback` (BRD mục 6.4), chạy được cả khi chưa có khoá nhờ kho 21 món Việt và 39 động tác có mức độ khó. Có khoá thì Gemini đề xuất trước, backend kiểm lại: calo ±10%, cùng nhóm cơ, không nặng hơn, tránh dị ứng và chấn thương
- Feedback: quy tắc cố định cho buổi tập ngày kế tiếp; dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực) → ngày nghỉ kèm khuyến cáo ngừng tập, hỏi ý kiến bác sĩ, gọi 115; feedback ngày 3 tạo plan mới. Đã đăng nhập thì các thao tác này cập nhật lịch sử
- Sửa lỗi dinh dưỡng: trước đây tổng calo thực đơn mỗi ngày không được kiểm, còn thực đơn mẫu cố định khoảng 1550 kcal/ngày — thấp hơn mức chuyển hoá cơ bản (BMR) của mọi hồ sơ nam trong bộ test. Nay khoảng calo tính theo mục tiêu của từng người và thực đơn mẫu được nhân khẩu phần cho khớp (BRD NFR-4)
- Chế độ giả lập nhận ra dị ứng, chấn thương phổ biến (gõ có dấu hay không dấu) để lọc thực đơn mẫu; kết quả Gemini có nguyên liệu người dùng dị ứng bị loại. Kiểm thử: thêm 114 unit test và 22 e2e; smoke test gọi thêm 3 endpoint mới trên bản build

### BRD v2.4.0 — 2026-09-24
- Giai đoạn 3 — tài khoản & lịch sử: đăng nhập Google (`POST /api/v1/auth/google`), JWT hết hạn sau 7 ngày, lịch sử 50 kế hoạch mới nhất xem lại được trên mọi thiết bị (`GET /api/v1/plans/history`, `/:id`), dữ liệu lưu bằng SQLite + TypeORM với migration. Mặc định chạy chế độ đăng nhập giả lập (`mock:<email>`), không cần tài khoản Google Cloud; cách gắn Client ID thật ở [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md) mục 2
- Tạo kế hoạch khi đã đăng nhập thì tự lưu vào lịch sử; lưu lỗi vẫn trả kế hoạch kèm cảnh báo. Kế hoạch trong lịch sử không chứa dị ứng, chấn thương hay tình trạng sức khoẻ (có test kiểm thẳng trong DB). Xem kế hoạch của tài khoản khác → 404
- Thêm `DELETE /api/v1/me` (FR-6.4): xoá tài khoản cùng toàn bộ lịch sử. Backend không khởi động nếu deploy (`NODE_ENV=production`) mà vẫn để đăng nhập giả lập, trừ khi bật cờ `ALLOW_MOCK_AUTH=true` có chủ đích
- Kiểm thử: thêm 65 unit test và 24 e2e (không test nào gọi Google hay ghi file DB thật); thêm smoke test chạy bản build như server thật trong CI, bắt được một lỗi khởi động mà toàn bộ unit test và e2e không thấy

### BRD v2.3.0 — 2026-09-24
- Chốt hợp đồng API (BRD mục 6) trước khi làm frontend. Nguyên liệu từng món có định lượng; danh sách đi chợ do server tự tính nên luôn khớp thực đơn. Bữa ăn, nhóm cơ, loại nguyên liệu dùng mã cố định. Server tự gán ID. Response có `source` (Gemini thật hay thực đơn mẫu) và `warnings`
- Hồ sơ: dị ứng, chấn thương, tình trạng sức khoẻ do người dùng tự nhập; chỉ lưu trên máy, backend không lưu và không ghi log. Calo mục tiêu không bao giờ thấp hơn BMR; mức điều chỉnh đổi thành −300 (giảm mỡ) / +250 (tăng cơ) theo thiết kế giao diện
- Feedback cuối ngày gồm 3 câu hỏi, có quy tắc riêng cho dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực); feedback ngày 3 tạo luôn plan mới. Thêm hợp đồng cho đổi món, đổi bài tập, feedback (BRD mục 6.4) — code làm ở giai đoạn 4
- Backend: mọi kết quả Gemini được kiểm tra theo hợp đồng trước khi trả về (trước đây Gemini chỉ cần viết tên bữa ăn khác đi là lọt bước kiểm tra calo); thực đơn mẫu đủ 3 ngày; mỗi lần gọi Gemini có giới hạn 15 giây; thêm 29 test
- Giai đoạn 2 — kiểm thử backend: ma trận 18 trường hợp BMR/TDEE (tính độc lập để đối chiếu), test phần gọi Gemini bằng SDK thật với server Gemini giả (hết giờ, khoá sai, không tự gọi lại), e2e toàn luồng `generate-plan`; GitHub Actions chạy build + test mỗi lần push (Node 24 và 26), không cần khoá

### BRD v2.2.0 — 2026-09-22 → 2026-09-24
- Chốt thêm tài khoản người dùng (đăng nhập Google) và lịch sử kế hoạch xem được trên nhiều thiết bị (FR-6, FR-7); backend sẽ dùng SQLite + TypeORM. Đã có trong BRD, chưa có code
- Lập kế hoạch triển khai toàn dự án [docs/PLAN.md](docs/PLAN.md) (giai đoạn 0–9); chốt 4 điểm lệch giữa giao diện Flutter và backend (mức điều chỉnh calo, feedback cuối ngày, dữ liệu đi chợ, thông tin sức khoẻ do người dùng tự nhập)
- Giai đoạn 0: `/health` báo backend đang dùng Gemini thật hay dữ liệu mẫu; `POST /api/v1/generate-plan` trả HTTP 200 đúng như BRD; thêm hướng dẫn gắn khoá [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md)
- Sửa BRD mục 7.6: host dùng SQLite phải có ổ lưu trữ bền (Render bản free xoá file DB khi service ngủ/restart)

### BRD v2.1.0 — 2026-09-22
- Chuyển tech stack backend từ FastAPI/Python sang **NestJS/TypeScript** (BRD mục 4, 6, 7, 8, 9)
- Bổ sung yêu cầu còn thiếu trong BRD: mức độ vận động để tính TDEE (FR-1.2), kiểm tra hợp lý dữ liệu dinh dưỡng AI trả về (NFR-4), không lặp tên món trong 3 ngày (FR-2.1), đồng bộ danh sách đi chợ khi đổi món (FR-4.1), quản lý API key qua `.env` (mục 4)
- Cập nhật JSON request/response schema (BRD mục 6) — thêm `activity_level`, tách schema request/response, thêm `source_meal_ids` cho từng nguyên liệu
- Dựng khung dự án `backend_api/` (NestJS): endpoint `GET /health`, `POST /api/v1/generate-plan`, validate DTO bằng `class-validator`, tính BMI/BMR/TDEE, tích hợp Gemini kèm fallback dữ liệu mẫu khi thiếu API key hoặc dữ liệu AI bất thường, Swagger UI tại `/docs`
- Dựng khung dự án `ai_workspace/`: script Node/TypeScript độc lập để thử nghiệm prompt Gemini trước khi đưa vào backend
- Khởi tạo knowledge base nội bộ `docs/knowledge/` (wiki tiếng Việt phục vụ AI agent làm việc trên dự án)
- Migrate SDK Gemini từ `@google/generative-ai` (đã bị Google khai tử) sang `@google/genai`; nâng model mặc định từ `gemini-2.5-flash` lên `gemini-3.8-flash`

### BRD v2.0.0 — 2026-09-13
- Phê duyệt BRD gốc: Flutter + FastAPI, phạm vi MVP (FR-1 → FR-3) và tính năng nâng cao (FR-4, FR-5)

### 2026-09-20
- Dựng giao diện Flutter MVP (`frontend_app/lib/screens`, `widgets`, `models`): onboarding, dashboard, grocery, loading — dùng dữ liệu mẫu, chưa nối API

### 2026-08-26 → 2026-09-12
- Khởi tạo repo, cấu trúc thư mục dự án, và tài liệu BRD ban đầu
