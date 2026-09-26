# Giai đoạn 5 — Frontend: nền tảng — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-5-frontend-foundation.md` (quyết định Q1–Q4 ở mục 8)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F07, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. CI chạy sau khi push (`Backend CI` và `Frontend CI` mới).

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Backend: CORS qua `CORS_ORIGINS`, fixture hợp đồng cho Flutter | API + CI | 5.7, 5.8 (mới, Q1) |
| F02 | Package, địa chỉ backend (`API_BASE_URL`), quyền mạng Android/iOS/macOS | UI (cấu hình) | 5.1, 5.2 |
| F03 | Model Dart theo BRD 6 + test vòng tròn bằng fixture | UI (model) | 5.3 |
| F04 | `ApiClient`: 9 endpoint, lỗi → `ApiException` tiếng Việt, timeout 60 s / 15 s | UI (service) | 5.4 |
| F05 | `PlanProvider`, `AuthProvider`, lưu `shared_preferences` | UI (state) | 5.5 |
| F06 | `MainShell` mở đúng màn đầu, widget test, CI Flutter | UI + CI | 5.6, 5.9 (mới, Q4) |
| F07 | Wiki (`flutter-ui.md`, #26–#29), CLAUDE.md, README, PLAN.md, SETUP_CREDENTIALS | Docs | — |

## Thứ tự thực hiện

F01 → F02 → F03 → F04 → F05 → F06 → F07. F03 cần fixture của F01; F04 cần package của F02 và model của F03.

## Code trong spec đã được chạy thật

Code của F01–F06 được viết và chạy trên bản sao `backend_api/` và `frontend_app/` trong thư mục nháp. Sau đó, để chắc mỗi feature tự đứng được, các file được áp **lần lượt từng feature** lên bản `HEAD` của repo (`git archive`), và ở mỗi mốc đều chạy cổng kiểm. Code trong spec chép nguyên văn từ bản đã chạy.

| Mốc | Backend unit | Backend e2e | Flutter | Kiểm thêm |
|---|---|---|---|---|
| Hiện tại | 25 file, 257 test | 5 file, 59 test | 1 test, **đỏ** (phát hiện F2) | — |
| Sau F01 | 26 file, 264 test | 7 file, 66 test | như cũ | 14 fixture sinh ra giống hệt lần chạy trước (tất định); sửa tay một fixture → e2e đỏ; typecheck, build, smoke, lint sạch |
| Sau F02 | | | `test/config`: 2 | `pubspec.lock` giống bản nháp; `plutil`, `xmllint` sạch; `flutter build web` được |
| Sau F03 | | | `test/models`: 12 | |
| Sau F04 | | | `test/services`: 13 | |
| Sau F05 | | | `test/providers`: 14 | |
| Sau F06 | | | **toàn bộ: 44 test xanh** | `flutter analyze` sạch ở mọi mốc |

**Kiểm ngược (mutation).** Cố ý làm hỏng 16 hành vi; lần nào cũng có test đỏ:

- 401 không gọi `onUnauthorized`;
- đăng nhập vẫn gửi token cũ;
- `Meal.toJson()` bỏ `portion`;
- tag động tác không được ghi lại;
- mã lạ bị thay bằng giá trị đầu tiên thay vì báo lỗi;
- đọc body bằng `response.body` (latin1 khi không có `Content-Type`);
- bỏ timeout;
- 409 thành lỗi chung;
- bỏ khoá "đang bận";
- bản lưu hỏng làm crash;
- hồ sơ hỏng mà vẫn giữ plan;
- không lưu plan;
- app luôn mở Dashboard;
- CORS thiếu header `Authorization`;
- `NODE_ENV=production` vẫn mở CORS cho localhost;
- `CORS_ORIGINS` có đường dẫn vẫn được nhận.

**Chạy trong Chrome thật** (backend bản build, chế độ giả lập, trang `http://127.0.0.1:5173` là bản `flutter build web`):

| Thử | Kết quả |
|---|---|
| `POST /api/v1/generate-plan` JSON (có preflight) | 200, `source: sample`, 27 ms |
| Đăng nhập giả lập → `GET /plans/history` có `Authorization` → `DELETE /api/v1/me` | 200 → 200 → 204 |
| `PUT` (không cho phép) | trình duyệt chặn |
| Backend chỉ khai báo `https://smartfit.example.com` | trang bị chặn cả `GET /health` lẫn `POST` |
| Log backend | không có chữ "Hải sản" hay email đã gửi |

**Không kiểm được trên máy lập plan:** build Android (tải Gradle bị ngắt sau 10 phút), iOS và macOS (không có Xcode). Cấu hình quyền mạng chỉ được kiểm cú pháp; chạy thử trên máy ảo Android là việc của giai đoạn 6 (PLAN 6.7).

**Kiểm lại sau khi thực hiện (2026-09-26):** build Android chạy được khi thử lại và lộ lỗi thật — `android/app/build.gradle.kts` ghim `compileSdk = 34` (commit `445864b`), còn plugin `shared_preferences_android` đòi ≥ 36, nên **APK không build được**. CI không bắt được vì không build APK. Sửa: `compileSdk = 36`, `targetSdk` giữ 34. Sau khi sửa, APK debug và release build được; manifest đã gộp: debug có `INTERNET` + `usesCleartextTraffic`, release có `INTERNET`, không có cleartext. Backend nghe mọi địa chỉ (`*:PORT`), gọi được qua IP LAN.

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P1 | Lỗi 400 của backend là câu class-validator tiếng Anh ("age must not be greater than 100") — brainstorm định hiện nguyên câu server | `ValidationException` hiện câu tiếng Việt chung, giữ câu gốc trong `details` để debug (F04). 409, 422 là câu tiếng Việt của server nên hiện nguyên |
| P2 | Tên brainstorm đề xuất (`DayPlan`, `GroceryCategory`, `FeedbackRequest`) trùng view-model cũ | Đặt `PlanDay`, `GroceryGroup`, `GroceryEntry`, `FeedbackAnswers` (F03) |
| P3 | Xuất fixture bằng script chạy trên bản build (như brainstorm) phải dựng lại DB, đăng nhập giả, cố định số ngẫu nhiên | Dùng chính e2e: `createTestApp()` đã có DB trong RAM, đăng nhập giả lập, không Gemini; ghi đè `RandomSource`. Một file vừa ghi (`npm run fixtures:update`) vừa kiểm (F01). Thêm 5 fixture lỗi (400/401/404/409/422) |
| P4 | Bản đầu của `ApiClient` parse model **ngoài** khối `try` → JSON sai hợp đồng lọt `FormatException` ra giao diện | Parse trong `_send()`; test "JSON sai hợp đồng → `ServerException`" bắt được lỗi này (F04) |
| P5 | Package `http` đã tự giải mã `application/json` không có charset bằng UTF-8, nên test UTF-8 ban đầu không phân biệt được — kiểm ngược mới lộ ra | Test bỏ hẳn header `Content-Type` (F04) |
| P6 | Brainstorm dự tính màn chờ khi đọc dữ liệu đã lưu | Không cần: `SharedPreferences.getInstance()` chạy trước `runApp`, sau đó đọc đồng bộ (F06) |
| P7 | Brainstorm: "plan hỏng → xoá plan, giữ hồ sơ" — còn trường hợp ngược lại | Hồ sơ hỏng → xoá cả plan, vì server cần `profile` để đổi món/feedback (F05) |
| P8 | Đăng nhập gửi kèm token cũ: đăng nhập lại thất bại (401) sẽ gọi `onUnauthorized` và làm mất phiên đang có | Đăng nhập không gửi token (`authorize: false`) (F04, F05) |
| P9 | Brainstorm: "bấm hai lần → bỏ qua lần hai" — ném lỗi thì dễ crash | Gọi khi đang bận trả về ngay, không gọi server; `submitFeedback` trả `null` (F05) |
| P10 | Code Flutter có sẵn chưa theo `dart format` ở khổ dòng nào (7–8 file đổi); chạy format trên `main.dart` gộp dòng ở các widget không liên quan | CI không kiểm format; `main.dart` chỉ sửa đúng chỗ, spec ghi rõ không format cả file (F06) |
| P11 | Dart 3.13 cho phép tham số có tên riêng tư (`required this._api`); `flutter_lints` gợi ý (`prefer_initializing_formals`) | Dùng trong provider; nơi gọi vẫn viết `api:` (F05) |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với quyết định của brainstorm. Ràng buộc được test khoá lại trong giai đoạn này:

| Ràng buộc | Test |
|---|---|
| #12 không log dữ liệu sức khoẻ — phía app | không có `print`/`log` trong code mới (cổng F04); log backend khi chạy thật không có dữ liệu đã gửi |
| #15 app chờ lâu hơn giới hạn Gemini của backend | `api_client_test.dart` (timeout cấu hình được; mặc định 60 s) |
| #17 test không gọi dịch vụ thật | fixture sinh bằng `createTestApp()`; test Flutter dùng `MockClient`/`FakeBackend`, widget test kiểm không có request |
| #18 cấu hình toàn cục trong `configureApp()` | `cors.e2e-spec.ts` chạy qua `configureApp()` |
| #22 401 → đăng xuất | `auth_provider_test.dart` |
| #24 gửi lại plan nguyên vẹn | `contract_test.dart` (vòng tròn), `plan_provider_test.dart` (body gửi đi = plan đã lưu) |

Ràng buộc mới ghi vào wiki ở F07: #26 (model đi vòng tròn + fixture), #27 (CORS), #28 (app gọi backend qua `ApiClient`, không log body, lưu trên máy), #29 (quyền mạng theo nền tảng).

## Việc chuyển sang giai đoạn sau

- **Giai đoạn 6:** màn hình dùng provider và model `lib/models/api/`, xoá view-model cũ (PLAN 6.7 mới); Loading gọi `PlanProvider.generate()`; widget test dùng `FakeBackend` (6.6); chạy thử trên máy ảo Android.
- **Giai đoạn 7:** 409 → gợi ý tạo plan mới; `safetyWarning` → cảnh báo nổi bật.
- **Giai đoạn 8:** Google Sign-In gọi `AuthProvider.signIn(idToken)`.
- **Giai đoạn 9:** deploy bản web → đặt `CORS_ORIGINS`; build với `--dart-define=API_BASE_URL=https://…`.

## Danh sách file

- `specs/F01-backend-cors-fixtures.md`
- `specs/F02-packages-platform.md`
- `specs/F03-dart-models.md`
- `specs/F04-api-client.md`
- `specs/F05-providers.md`
- `specs/F06-main-shell-ci.md`
- `specs/F07-docs.md`
- `project.json`
- `README.md`
