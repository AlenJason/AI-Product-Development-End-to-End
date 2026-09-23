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
backend_api/     API NestJS — khung dự án đã dựng, endpoint /health + /api/v1/generate-plan (fallback demo)
ai_workspace/    Script Node/TS thử nghiệm prompt & schema Gemini, độc lập với backend
docs/            Kế hoạch triển khai, hướng dẫn gắn khoá, wiki nội bộ
BRD.md           Tài liệu đặc tả yêu cầu (nguồn spec chính thức)
```

Dự án chạy được ngay khi chưa có khoá nào (chế độ giả lập, dùng dữ liệu mẫu). Muốn dùng Gemini thật: xem [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md).

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
cp .env.example .env   # để trống GEMINI_API_KEY = chạy giả lập; điền key = dùng Gemini thật
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

## Nhật ký thay đổi (Changelog)

Đối chiếu theo phiên bản BRD (mục "Phiên bản" trong [BRD.md](BRD.md)), để giảng viên/trợ giảng theo dõi tiến độ trực tiếp trên repo mà không cần đọc từng commit.

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
