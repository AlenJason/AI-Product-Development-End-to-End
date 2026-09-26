---
type: meta
last_updated: 2026-09-26
---

# Wiki Triggers

Ánh xạ khu vực code và chủ đề sang bài wiki tương ứng. Được `commit`, `feature-explore`, và `feature-build` sử dụng.

Auth và database của backend nằm ở `backend_api/src/auth/`, `src/database/`, `src/history/` (từ giai đoạn 3) — trigger ở bảng dưới. Flutter lưu JWT, hồ sơ và plan hiện tại trên máy bằng `shared_preferences` (`frontend_app/lib/providers/`, từ giai đoạn 5).

## Trigger theo đường dẫn file

| File thay đổi | Bài wiki cần load / cập nhật |
| --- | --- |
| `backend_api/src/app.controller.ts`, `backend_api/src/app.service.ts`, `backend_api/src/app.setup.ts`, `backend_api/src/plan/plan.controller.ts`, `backend_api/src/plan/plan.module.ts`, `backend_api/src/main.ts` | `plan-data-contract.md`, `auth-and-history.md` |
| `backend_api/src/plan/adjust/**`, `backend_api/src/plan/restriction-matcher.ts`, `backend_api/src/plan/restriction-filter.ts`, `backend_api/src/plan/swap-pools.ts`, `backend_api/src/plan/meal-scaling.ts`, `backend_api/src/plan/exercise-presets.ts`, `backend_api/src/plan/data/swap-*.json`, `backend_api/src/plan/data/restriction-keywords.json`, `backend_api/test/plan-fixtures.ts`, `backend_api/test/adjust.e2e-spec.ts` | `swap-and-feedback.md` |
| `backend_api/src/plan/gemini.service.ts`, `backend_api/test/fake-gemini-server.ts`, `ai_workspace/**` | `gemini-integration.md` |
| `backend_api/src/plan/dto/**`, `backend_api/src/plan/enums/**`, `backend_api/src/plan/data/**`, `backend_api/src/plan/plan-validation.ts`, `backend_api/src/plan/plan-assembly.ts`, `backend_api/src/plan/daily-target.ts`, `backend_api/src/plan/plan-warnings.ts`, `backend_api/src/plan/text.util.ts`, `backend_api/src/plan/plan.service.ts` | `plan-data-contract.md` |
| `backend_api/src/auth/**`, `backend_api/src/database/**`, `backend_api/src/history/**`, `backend_api/test/test-app.ts`, `backend_api/test/memory-data-source.ts`, `backend_api/scripts/smoke-test.mjs` | `auth-and-history.md` |
| `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
| `frontend_app/lib/models/**`, `frontend_app/lib/services/**`, `frontend_app/lib/providers/**`, `frontend_app/lib/config/**`, `frontend_app/test/**` | `flutter-ui.md`, `critical-constraints.md` (#26, #28) |
| `backend_api/src/cors-options.ts`, `backend_api/test/cors.e2e-spec.ts`, `backend_api/test/contract-fixtures.e2e-spec.ts` | `flutter-ui.md`, `critical-constraints.md` (#26, #27) |
| `frontend_app/pubspec.yaml`, `frontend_app/android/**/AndroidManifest.xml`, `frontend_app/ios/Runner/Info.plist`, `frontend_app/macos/Runner/*.entitlements`, `.github/workflows/frontend.yml` | `flutter-ui.md`, `critical-constraints.md` (#29) |
| `BRD.md` | `product-spec.md` *(chưa có — đọc thẳng BRD.md)* |

Trigger bổ sung (bất kỳ thay đổi nào sau đây → bắt buộc cập nhật khi commit):

- Một ràng buộc thay đổi (khoảng calo, hệ số vận động, mức điều chỉnh calo theo mục tiêu — xem `critical-constraints.md`)
- Hợp đồng request/response (BRD.md mục 6) thay đổi mà `backend_api/src/plan/dto/`, `enums/`, `data/sample-plan.json`, fixture `frontend_app/test/fixtures/` (`npm run fixtures:update`) và model `frontend_app/lib/models/api/` chưa cập nhật khớp theo
- Một đoạn tóm tắt trong wiki không còn đúng thực tế
- Thêm hoặc sửa entity trong `backend_api/src/database/entities/` (phải kèm migration — `critical-constraints.md` #19)

## Trigger theo từ khóa chủ đề

| Từ khóa | Bài wiki cần load |
| --- | --- |
| BMR / TDEE / calo / macro / dinh dưỡng / mức vận động / Mifflin-St Jeor | `plan-data-contract.md` |
| gemini / prompt / structured output / JSON schema / ảo giác (hallucination) | `gemini-integration.md` |
| endpoint / controller / swagger / health / validation / DTO | `plan-data-contract.md`, `auth-and-history.md`, `swap-and-feedback.md` |
| đổi món / đổi bài / swap / feedback / dị ứng / chấn thương / từ khoá / kho món / kho động tác / dấu hiệu nguy hiểm / khẩu phần | `swap-and-feedback.md` |
| đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md` |
| screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
| CORS / API_BASE_URL / dart-define / ApiClient / provider / shared_preferences / fixture hợp đồng / quyền mạng | `flutter-ui.md`, `critical-constraints.md` |
| BRD / roadmap / rubric / phạm vi / FR- / NFR- | `product-spec.md` *(chưa có — đọc thẳng BRD.md)* |
| tài liệu tham khảo / thư viện / SDK / phiên bản / deprecated | `reference-materials.md` |

Fallback: nếu không khớp từ khóa nào, load `project-architecture.md` làm baseline (tạo bài này khi cấu trúc dự án đã ổn định).

## Skill nào dùng bảng nào

| Skill | Bảng | Dùng trên input gì |
| --- | --- | --- |
| `commit` | Theo đường dẫn file | Các file trong diff |
| `feature-explore` | Theo từ khóa | Từ khóa trong yêu cầu |
| `feature-build` | Theo đường dẫn file | Danh sách file trong Scope của feature spec |
| `wiki-lookup` | Cả hai | Tham số truyền vào (đường dẫn file hoặc chủ đề) |
