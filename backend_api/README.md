# SmartFit AI — Backend API (NestJS)

Backend cho đồ án SmartFit AI. Xem đặc tả đầy đủ tại [`../BRD.md`](../BRD.md) (mục 4, 6, 7 liên quan trực tiếp tới backend).

## Cài đặt

```bash
npm install
cp .env.example .env   # rồi điền GEMINI_API_KEY
```

## Chạy

```bash
npm run start:dev   # http://localhost:3000, tự reload khi sửa code
```

Swagger UI: http://localhost:3000/docs

## Endpoints

- `GET /health` — health check.
- `POST /api/v1/generate-plan` — sinh kế hoạch 3 ngày (request/response schema ở BRD.md mục 6). Nếu chưa cấu hình `GEMINI_API_KEY`, hoặc Gemini trả về dữ liệu dinh dưỡng bất thường sau khi retry, endpoint tự động rơi về `src/plan/data/sample-plan.json` (BRD NFR-2, NFR-4).

## Cấu trúc

```
src/
  app.controller.ts     # GET /health
  plan/
    plan.controller.ts  # POST /api/v1/generate-plan
    plan.service.ts     # tính BMI/BMR/TDEE (FR-1.5) + orchestration + nutrition sanity check (NFR-4)
    gemini.service.ts   # gọi Gemini Structured Output JSON Mode
    dto/                # CreatePlanDto khớp BRD mục 6.1
    enums/               # ActivityLevel, Goal, Gender + hệ số tính toán
    interfaces/          # kiểu response khớp BRD mục 6.2
    data/sample-plan.json # dữ liệu fallback demo (1 ngày, theo đúng ví dụ BRD mục 6.2)
```

## Test

```bash
npm test          # unit test
npm run test:e2e  # e2e test
```
