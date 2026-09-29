# Giai đoạn 1 — Chốt hợp đồng API — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-1-api-contract.md` (hướng B, quyết định Q1–Q4 ở mục 10)
**Executor:** thực thi trực tiếp theo spec. `/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js, không dùng được cho `backend_api/` (NestJS).
**Commit:** một commit + push cho cả giai đoạn sau F07, lên nhánh đang làm việc (hiện là `Thien-Source`).

## Features

| ID | Tên | Phạm vi |
|---|---|---|
| F01 | BRD v2.3.0 — hợp đồng API | Docs |
| F02 | Kiểu dữ liệu plan và bộ kiểm tra hợp đồng | API |
| F03 | Mục tiêu calo: D1, sàn BMR, BMI | API |
| F04 | Ghép plan phía server: ID và danh sách đi chợ | API |
| F05 | Thực đơn mẫu 3 ngày theo hợp đồng mới | API |
| F06 | Luồng `generate-plan`: văn bản tự do, prompt mới, timeout, kiểm tra, fallback | API |
| F07 | Wiki, CLAUDE.md, hướng dẫn gắn khoá, Changelog, tiến độ | Docs |

## Thứ tự thực hiện

F01 → F02 → F03, F04 (độc lập với nhau) → F05 → F06 → F07

F02–F05 **chỉ thêm file mới**, không đụng `plan.service.ts` / `gemini.service.ts` hiện tại, nên sau mỗi feature build và test vẫn xanh. F06 mới chuyển luồng chạy sang code mới và xoá file cũ (`interfaces/plan.interface.ts`, `nutrition-sanity.util.ts`).

Giữa F05 và F06 có một trạng thái trung gian: `sample-plan.json` đã sang định dạng mới trong khi `PlanService` cũ vẫn đọc theo định dạng cũ, nên `curl` lúc đó trả plan thiếu trường. Không sao vì chỉ commit sau F07; cổng kiểm tra của F05 chỉ gồm build và test.

## Ràng buộc từ wiki và các chỗ mâu thuẫn

Ràng buộc trong `docs/knowledge/wiki/critical-constraints.md` được ghi vào từng spec (mục "Ràng buộc áp dụng"). Các chỗ mâu thuẫn phát hiện khi lập plan — **không tự ý bỏ qua bên nào**:

| Mâu thuẫn | Cách xử lý |
|---|---|
| Ràng buộc #7 (đồng bộ danh sách đi chợ bằng cách cập nhật từng phần theo `source_meal_ids`) ↔ hướng B (server tính lại toàn bộ) | Hướng B đã được chọn ở Q1. F07 viết lại ràng buộc #7 |
| Ràng buộc #2 muốn chặn calo sai ↔ code `nutrition-sanity.util.ts` cho qua khi `meal_type` lạ (`return true`) | F02 sửa: mã lạ bị coi là sai. F07 viết lại ràng buộc #2 |
| BRD sơ đồ mục 4 ghi "class-validator kiểm tra JSON" ↔ code chỉ `JSON.parse` + ép kiểu | F02 + F06 làm đúng như BRD |
| BRD FR-1.5 ghi backend tính BMI ↔ code không tính BMI ở đâu | F03 thêm `bmi` vào `daily_target` |
| BRD NFR-2 gọi file mẫu là `sample_plan.json` ↔ file thật `sample-plan.json` | F01 sửa BRD |

Phát hiện thêm khi đọc SDK `@google/genai` 2.24: SDK có sẵn cơ chế tự retry (mặc định 5 lần, chờ tối đa 60 giây) nhưng **chỉ bật khi truyền `retryOptions`**. Code hiện không truyền và F06 giữ nguyên như vậy; F07 ghi thành ràng buộc để không ai vô tình bật lên (sẽ nhân thời gian chờ lên nhiều lần).

## Danh sách file

- `specs/F01-brd-contract.md`
- `specs/F02-plan-types-validation.md`
- `specs/F03-daily-target.md`
- `specs/F04-plan-assembly.md`
- `specs/F05-sample-plan.md`
- `specs/F06-generate-plan-pipeline.md`
- `specs/F07-docs-wiki.md`
- `project.json`
- `README.md`

## Kết quả khi xong giai đoạn

- BRD mục 6 là hợp đồng đầy đủ cho mọi endpoint (kể cả 3 endpoint giai đoạn 4 làm).
- `POST /api/v1/generate-plan` trả plan theo hợp đồng mới ở cả hai chế độ (Gemini thật / thực đơn mẫu), Swagger hiện schema response.
- 8 file test (khoảng 30 test) chạy không cần khoá Gemini.
