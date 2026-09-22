---
last_updated: 2026-09-22
tags: [gemini, nestjs, flutter, dinh-duong, tham-khao]
---

# Tài liệu tham khảo cho SmartFit AI

Tổng hợp tài liệu chính thức và công nghệ liên quan tới ba mảng của dự án (AI Engine, Backend NestJS, Frontend Flutter), thu thập qua nghiên cứu ngày 2026-09-22. Xem [[critical-constraints]] mục 8–9 cho hai phát hiện cần hành động ngay.

## 1. Gemini API / AI Engine

### 1.1. SDK Node.js — đã migrate (2026-09-22)

`backend_api/src/plan/gemini.service.ts` và `ai_workspace/generate-plan-experiment.ts` từng dùng gói **`@google/generative-ai`** — gói này **đã bị Google khai tử** (repo chính thức chuyển thành [`google-gemini/deprecated-generative-ai-js`](https://github.com/google-gemini/deprecated-generative-ai-js)). Đã migrate sang gói kế nhiệm **[`@google/genai`](https://www.npmjs.com/package/@google/genai)** (v2.24.0), SDK thống nhất cho mọi model GenAI của Google (Gemini, Veo, Imagen...).

Hướng dẫn migrate chính thức: [Migrate to the Google GenAI SDK](https://ai.google.dev/gemini-api/docs/migrate)

Khác biệt chính:
- Import: `import { GoogleGenAI } from "@google/genai"` (thay vì `GoogleGenerativeAI`)
- Khởi tạo: `new GoogleGenAI({ apiKey })` — client tập trung, không tạo instance model riêng
- Gọi sinh nội dung: `ai.models.generateContent({ model, contents, config: { responseMimeType, responseSchema } })` (thay vì `client.getGenerativeModel({...}).generateContent(prompt)`)
- Đọc kết quả: `response.text` (property, không phải `response.text()` như SDK cũ)

### 1.2. Structured Output — có thể làm chặt hơn

Tài liệu chính thức: [Structured outputs | Gemini API](https://ai.google.dev/gemini-api/docs/structured-output)

Hiện `gemini.service.ts` chỉ dùng `responseMimeType: 'application/json'` và mô tả schema bằng văn xuôi trong prompt. Gemini hỗ trợ thêm tham số `responseSchema` (tập con của OpenAPI 3.0 Schema, có `propertyOrdering`) để ép cấu trúc JSON ở tầng API thay vì chỉ dựa vào prompt — đáng cân nhắc áp dụng để giảm rủi ro JSON sai schema, đặc biệt hữu ích kết hợp với thư viện Zod ở phía Node.

### 1.3. Model — đã cập nhật (2026-09-22)

Model mặc định từng là `gemini-2.5-flash` (đã cũ). Theo [Models | Gemini API](https://ai.google.dev/gemini-api/docs/models), model workhorse hiện tại (09/2026) là **`gemini-3.8-flash`** (GA từ 02/09/2026, cửa sổ input ~1M token, hỗ trợ computer use/file search/grounding). Đã cập nhật làm giá trị mặc định ở `backend_api/.env.example`, `ai_workspace/.env.example`, `gemini.service.ts`, `generate-plan-experiment.ts`, và BRD.md mục 4.

## 2. Backend NestJS

Setup hiện tại (`ValidationPipe` toàn cục + `class-validator`/`class-transformer` trên DTO + `@nestjs/swagger`) khớp đúng pattern chính thức:

- [Validation | NestJS Techniques](https://docs.nestjs.com/techniques/validation) — `ValidationPipe`, decorator `class-validator`, kết hợp `class-transformer` để transform payload thành instance DTO.
- `@nestjs/swagger` dùng chung decorator với `class-validator` để vừa validate runtime vừa tự sinh OpenAPI schema — không cần viết OpenAPI schema tay riêng.

Không phát hiện gì cần đổi ở phần này; ghi lại để tra cứu nhanh khi mở rộng thêm module (ví dụ module đổi món FR-4.1).

## 3. Frontend Flutter

Ba package BRD.md đề xuất (mục 4) đều còn được duy trì tích cực tính tới 09/2026, không có lựa chọn thay thế cấp thiết nào cần biết trước:

- [`http`](https://pub.dev/packages/http) — gọi REST API, package chính thức của dart.dev.
- [`provider`](https://pub.dev/packages/provider) — state management dựa trên `InheritedWidget`.
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — lưu trữ cục bộ key-value, bản mới nhất (2.5.5) yêu cầu Flutter 3.35+/Dart 3.9+ (kiểm tra khớp với `frontend_app/pubspec.yaml` — hiện SDK constraint là `^3.13.1`, cần nâng nếu thêm `shared_preferences` bản mới).

## 4. Dinh dưỡng — dữ liệu tham chiếu cho NFR-4

Liên quan trực tiếp tới lỗ hổng đã nêu trước đây (Gemini có thể "bịa" calo món ăn): **Bảng thành phần thực phẩm Việt Nam** do Viện Dinh dưỡng Quốc gia (Bộ Y tế) biên soạn là nguồn dữ liệu chính thống nhất — hơn 600 thực phẩm phổ biến, 86 thành phần dinh dưỡng mỗi 100g, cập nhật gần nhất khoảng 2016–2017.

- Trang chính thức: [viendinhduong.vn](https://viendinhduong.vn/)
- Bản PDF công khai (bản 2007, do FAO lưu trữ): [VTN_FCT_2007.pdf](https://www.fao.org/fileadmin/templates/food_composition/documents/pdf/VTN_FCT_2007.pdf)

Có thể dùng làm nguồn build một bảng tra cứu calo/macro cơ bản cho các món Việt phổ biến trong BRD (phở, bún thịt nạc, canh rau ngót...), đối chiếu với số liệu Gemini trả về thay vì chỉ giới hạn khoảng calo chung chung như `nutrition-sanity.util.ts` hiện tại.

## 5. Công thức BMR — đã đối chiếu, khớp đúng

Công thức Mifflin-St Jeor cài trong `backend_api/src/plan/plan.service.ts` (`computeDailyTarget()`) đã đối chiếu với nguồn tham khảo và **khớp chính xác**:

- Nam: `BMR = 10×cân nặng(kg) + 6.25×chiều cao(cm) − 5×tuổi + 5`
- Nữ: `BMR = 10×cân nặng(kg) + 6.25×chiều cao(cm) − 5×tuổi − 161`

Nguồn: công thức gốc Mifflin MD, St Jeor ST et al. — được nhiều nguồn y khoa xác nhận là công thước ước lượng BMR chính xác nhất hiện có (sai số trong khoảng 10% so với đo thực tế).
