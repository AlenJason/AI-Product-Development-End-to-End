---
last_updated: 2026-09-26
tags: [flutter, frontend, hop-dong-api, cors]
---

# Giao diện Flutter và tầng kết nối API

App Flutter nằm trong `frontend_app/` (package `my_ai_app`). Từ giai đoạn 5, app có tầng kết nối backend: model đọc/ghi đúng hợp đồng BRD mục 6, `ApiClient` gọi mọi endpoint, hai provider lưu plan và phiên đăng nhập trên máy. Các màn hình **vẫn dùng dữ liệu mẫu** tới giai đoạn 6. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#29. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].

## Cấu trúc `lib/`

| Đường dẫn | Nội dung |
|---|---|
| `main.dart` | `main()` đọc `SharedPreferences`, tạo một `ApiClient` và hai provider; `SmartFitApp` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng bằng enum `AppScreen` + `setState` (không có router) |
| `config/api_config.dart` | `resolveApiBaseUrl()` — địa chỉ backend |
| `models/api/` | Model viết tay theo BRD 6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…) và enum mã cố định (`codes.dart`) |
| `models/meal_plan.dart` | View-model **cũ** (`DayPlan`, `MealItem`, `GroceryCategory`…) màn hình đang dùng với dữ liệu viết cứng — xoá ở giai đoạn 6 |
| `services/` | `ApiClient`, `ApiException` |
| `providers/` | `PlanProvider`, `AuthProvider` |
| `screens/`, `widgets/` | Onboarding, Loading, Dashboard, Grocery; `macro_ring`, `feedback_bottom_sheet` |

Chữ trên giao diện và comment viết tiếng Việt.

## Luồng mở app

1. `SharedPreferences.getInstance()` đọc hết dữ liệu đã lưu một lần, sau đó đọc đồng bộ — không cần màn chờ.
2. `AuthProvider` nạp token và user; `PlanProvider` nạp hồ sơ và plan.
3. `MainShell`: có plan → Dashboard, chưa có → Onboarding. Mở app không gọi mạng, nên có plan thì xem được khi không có mạng (NFR-2).

## Địa chỉ backend

Đặt bằng `--dart-define=API_BASE_URL=<địa chỉ>` khi `flutter run` / `flutter build`. Không đặt thì:

| Chạy trên | Mặc định |
|---|---|
| Web, iOS Simulator, macOS/Windows/Linux | `http://localhost:3000` |
| Máy ảo Android | `http://10.0.2.2:3000` (máy dev nhìn từ máy ảo) |
| Điện thoại thật | phải đặt: `http://<IP LAN của máy chạy backend>:3000`, hai máy cùng Wi-Fi, tường lửa mở cổng 3000 |

## Gọi API (`ApiClient`)

- Chín hàm cho chín endpoint (BRD 6.1–6.4). Body gửi/nhận là JSON UTF-8; body nhận luôn giải mã từ `bodyBytes` — thiếu `Content-Type` thì package `http` giải mã latin1 và tên món tiếng Việt bị vỡ.
- **Timeout:** 60 s cho `generate-plan`, đổi món, đổi bài, feedback (có thể gọi Gemini; backend dừng Gemini sau 40 s — #15); 15 s cho phần còn lại.
- **Token:** `accessToken` do `AuthProvider` đặt. Đăng nhập không gửi token cũ. 401 cho request có token → `onUnauthorized` → đăng xuất; không tự gọi lại như khách.
- **Lỗi** → `ApiException` (sealed), `message` là câu tiếng Việt hiện thẳng cho người dùng:

| Tình huống | Lớp |
|---|---|
| Không tới được máy chủ, **CORS chặn trên web** | `NetworkException` |
| Quá timeout | `ApiTimeoutException` |
| 400 (câu class-validator tiếng Anh giữ trong `details`, không hiện) | `ValidationException` |
| 401 | `UnauthorizedException` |
| 404 | `NotFoundException` |
| 409 — plan tạo cho hồ sơ khác, cần tạo plan mới | `PlanOutdatedException` (câu của server) |
| 422 — không còn món/động tác thay thế | `NoReplacementException` (câu của server) |
| 5xx, body không phải JSON, JSON sai hợp đồng | `ServerException` |

- Parse model nằm trong khối bắt `FormatException` của `_send()`: JSON sai hợp đồng thành `ServerException`, không lọt ra giao diện.
- **Không in log** request, response, hồ sơ hay token (#28).

## Model và vòng tròn JSON

Đổi món, đổi bài, feedback gửi lại **nguyên** plan và server kiểm từng ID, con số (#24). Nên `MealPlan.fromJson(json).toJson()` phải bằng đúng `json`: đọc số qua `num` để giữ `22.5` là `22.5` và `640` là `640`. Thiếu trường, sai kiểu, mã lạ → `FormatException` nêu tên trường (`json_read.dart`), không đoán (#26).

## Fixture hợp đồng

`backend_api/test/contract-fixtures.e2e-spec.ts` gọi thật 14 tình huống (hồ sơ, `/health`, đăng nhập, tạo plan, lịch sử, đổi món, đổi bài, hai kiểu feedback, lỗi 400/401/404/409/422) và so với file JSON trong `frontend_app/test/fixtures/`. UUID, token, thời điểm được thay bằng giá trị cố định; `RandomSource` cố định nên đổi món luôn ra cùng món. App dùng chính các file này cho test vòng tròn, `ApiClient`, provider và widget test.

Khi đổi hợp đồng BRD 6 ở backend:

1. `cd backend_api && npm run fixtures:update` — ghi lại fixture;
2. sửa model trong `frontend_app/lib/models/api/` tới khi `flutter test` xanh;
3. commit fixture và model cùng nhau.

Quên bước 1 → test backend đỏ ("… đã cũ — chạy npm run fixtures:update"); quên bước 2 → `test/models/contract_test.dart` đỏ.

## Lưu trên máy

| Khoá `shared_preferences` | Provider | Nội dung |
|---|---|---|
| `smartfit.profile.v1` | `PlanProvider` | hồ sơ, kể cả `restrictions` |
| `smartfit.plan.v1` | `PlanProvider` | plan hiện tại, đúng JSON server trả |
| `smartfit.access_token` | `AuthProvider` | JWT của backend (7 ngày) |
| `smartfit.user.v1` | `AuthProvider` | `id`, `email`, `name` |

- Số phiên bản trong khoá: đổi định dạng theo cách bản cũ không đọc được thì tăng số.
- Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai.
- Trên web, `shared_preferences` là `localStorage` của trình duyệt: dữ liệu sức khoẻ và token nằm trong trình duyệt. BRD chấp nhận việc lưu trên máy người dùng (NFR-7, D4); backend vẫn không lưu `restrictions` (#12).
- `PlanProvider.busy` = đang chờ server; gọi thêm khi đang bận bị bỏ qua, không ném lỗi.

## CORS (bản web)

Bản web chạy ở origin khác backend nên cần CORS; app mobile không gửi `Origin` nên không cần. Backend đọc `CORS_ORIGINS` trong `resolveCorsOptions()` (#27): trống khi phát triển → `http://localhost` và `http://127.0.0.1` mọi cổng (`flutter run -d chrome` chạy cổng ngẫu nhiên); deploy bản web → đặt đúng địa chỉ bản web.

Kiểm trong Chrome thật khi lập plan giai đoạn 5: preflight cho POST JSON, header `Authorization`, DELETE đều qua; PUT bị chặn; backend chỉ khai báo origin khác → trang bị chặn cả GET lẫn POST. Trình duyệt không cho code biết lý do, nên CORS bị chặn hiện ra như mất mạng (`NetworkException`) — gặp lỗi mạng trên web mà backend vẫn chạy thì kiểm `CORS_ORIGINS` và địa chỉ trang trước.

## Quyền mạng theo nền tảng (#29)

| Nền tảng | Cấu hình |
|---|---|
| Android | `INTERNET` trong `android/app/src/main/AndroidManifest.xml` (bản release); `usesCleartextTraffic="true"` chỉ trong manifest debug — HTTP của Dart không cần cờ này (đã thử trên Android 16), giữ cho thư viện dùng HTTP của hệ thống |
| iOS | `NSAppTransportSecurity` → `NSAllowsLocalNetworking` trong `ios/Runner/Info.plist` |
| macOS | `com.apple.security.network.client` trong cả `DebugProfile.entitlements` và `Release.entitlements` |
| Web | không cần; cần CORS phía backend |

Android: `compileSdk = 36` trong `android/app/build.gradle.kts` — plugin Android của `shared_preferences` đòi biên dịch với API ≥ 36; `targetSdk` vẫn 34. Trước đó file này ghim `compileSdk = 34` và APK không build được. CI chỉ chạy `analyze` + `test` nên không bắt được lỗi kiểu này — đổi package có plugin thì build thử `flutter build apk --debug`.

Đã kiểm: APK debug và release build được; manifest đã gộp của bản debug có `INTERNET` + `usesCleartextTraffic`, bản release có `INTERNET`, không có cleartext. Bản web build và chạy được. Chạy trên máy ảo Android 16 (Pixel 8, API 36, 2026-09-26): `integration_test/backend_smoke_test.dart` gọi backend thật qua `10.0.2.2` — tạo plan, lịch sử, đổi món, đổi bài, feedback, lỗi 409, lưu `shared_preferences` thật — đều xanh; plan đã lưu → mở thẳng Dashboard cả khi backend tắt; plan hỏng → Onboarding, không crash, giữ hồ sơ. Chưa build iOS/macOS (máy không có Xcode).

## Test

- `cd frontend_app && flutter test` — 44 test, không cần backend chạy:
  - `test/models/contract_test.dart` — vòng tròn fixture, kiểu số, JSON sai hợp đồng;
  - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
  - `test/providers/` — `SharedPreferences.setMockInitialValues()`;
  - `test/widget_test.dart` — màn đầu theo dữ liệu đã lưu;
  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, ghi lại request.
- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó. Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`, không chạy test này.
- Chưa có máy ảo: Android Studio → Device Manager → tạo thiết bị (ví dụ Pixel 8, API 36).
- CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi.
- Code có sẵn chưa theo `dart format` ở khổ dòng nào, nên CI không kiểm format; sửa file cũ thì không format lại cả file (sẽ gộp dòng ở các widget không liên quan).

## Việc của giai đoạn sau

- **6:** màn hình đọc/ghi qua `PlanProvider`, `AuthProvider` và model `lib/models/api/`, xoá view-model cũ; Loading gọi `PlanProvider.generate()`; lỗi hiện `ApiException.message`; widget test dùng `FakeBackend`; chạy thử trên máy ảo Android.
- **7:** nút đổi món, đổi bài, bảng feedback; 409 → gợi ý tạo plan mới; `FeedbackResult.safetyWarning` → cảnh báo nổi bật.
- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`.
