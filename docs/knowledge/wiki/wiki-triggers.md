---
type: meta
last_updated: 2026-09-22
---

# Wiki Triggers

Ánh xạ khu vực code và chủ đề sang bài wiki tương ứng. Được `commit`, `feature-explore`, và `feature-build` sử dụng.

Dự án không có `lib/auth/`, `middleware.ts`, hay thư mục database/ORM (không có auth phía server, không có DB — state phía client chỉ dùng `shared_preferences` theo BRD), nên không có trigger auth-flow hay database-schema ở đây. Thêm vào nếu sau này thay đổi.

## Trigger theo đường dẫn file

| File thay đổi | Bài wiki cần load / cập nhật |
| --- | --- |
| `backend_api/src/app.controller.ts`, `backend_api/src/app.service.ts`, `backend_api/src/plan/plan.controller.ts`, `backend_api/src/plan/plan.module.ts`, `backend_api/src/main.ts` | `api-routes.md` |
| `backend_api/src/plan/gemini.service.ts`, `backend_api/src/plan/nutrition-sanity.util.ts`, `ai_workspace/**` | `gemini-integration.md` |
| `backend_api/src/plan/dto/**`, `backend_api/src/plan/enums/**`, `backend_api/src/plan/interfaces/**`, `backend_api/src/plan/data/**`, `backend_api/src/plan/plan.service.ts` | `plan-data-contract.md` |
| `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
| `frontend_app/lib/models/**` | `flutter-ui.md` |
| `BRD.md` | `product-spec.md` |

Trigger bổ sung (bất kỳ thay đổi nào sau đây → bắt buộc cập nhật khi commit):

- Một ràng buộc thay đổi (khoảng calo, hệ số vận động, mức điều chỉnh calo theo mục tiêu — xem `critical-constraints.md`)
- Schema JSON request/response của Gemini thay đổi (BRD.md mục 6) mà `backend_api/src/plan/interfaces/` và `dto/` chưa cập nhật khớp theo
- Một đoạn tóm tắt trong wiki không còn đúng thực tế

## Trigger theo từ khóa chủ đề

| Từ khóa | Bài wiki cần load |
| --- | --- |
| BMR / TDEE / calo / macro / dinh dưỡng / mức vận động / Mifflin-St Jeor | `plan-data-contract.md` |
| gemini / prompt / structured output / JSON schema / ảo giác (hallucination) | `gemini-integration.md` |
| endpoint / controller / swagger / health / validation / DTO | `api-routes.md` |
| screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
| BRD / roadmap / rubric / phạm vi / FR- / NFR- | `product-spec.md` |
| tài liệu tham khảo / thư viện / SDK / phiên bản / deprecated | `reference-materials.md` |

Fallback: nếu không khớp từ khóa nào, load `project-architecture.md` làm baseline (tạo bài này khi cấu trúc dự án đã ổn định).

## Skill nào dùng bảng nào

| Skill | Bảng | Dùng trên input gì |
| --- | --- | --- |
| `commit` | Theo đường dẫn file | Các file trong diff |
| `feature-explore` | Theo từ khóa | Từ khóa trong yêu cầu |
| `feature-build` | Theo đường dẫn file | Danh sách file trong Scope của feature spec |
| `wiki-lookup` | Cả hai | Tham số truyền vào (đường dẫn file hoặc chủ đề) |
