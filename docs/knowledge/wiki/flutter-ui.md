---
last_updated: 2026-09-27
tags: [flutter, frontend, hop-dong-api, cors, onboarding]
---

# Giao diện Flutter và tầng kết nối API

App Flutter nằm trong `frontend_app/` (package `my_ai_app`, tên hiển thị "SmartFit AI"). Giai đoạn 5 dựng tầng kết nối backend (model theo hợp đồng BRD 6, `ApiClient`, provider lưu trên máy); từ giai đoạn 6 mọi màn hình đọc/ghi qua provider — không còn dữ liệu viết cứng. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#32. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].

## Cấu trúc `lib/`

| Đường dẫn | Nội dung |
|---|---|
| `main.dart` | `main()` bật vẽ dưới thanh hệ thống (`edgeToEdge`), đọc `SharedPreferences`, tạo một `ApiClient` và ba provider; `SmartFitApp(auth:, plans:, grocery:)` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng Onboarding → màn chờ → màn chính 4 tab bằng enum `AppScreen` + `setState` (không có router) |
| `config/api_config.dart` | `resolveApiBaseUrl()` — địa chỉ backend |
| `models/api/` | Model viết tay theo BRD 6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…) và enum mã cố định (`codes.dart`) |
| `models/profile_rules.dart` | Giới hạn và luật an toàn giống backend: tuổi 18–100, chiều cao, cân nặng, BMI < 18,5, mang thai → không Giảm mỡ (#30) |
| `models/restriction_options.dart` | Danh sách chip dị ứng / chấn thương / bệnh nền, ghép và tách chuỗi gửi đi (D5, #32) |
| `models/plan_schedule.dart` | Ngày bắt đầu của plan, hôm nay là ngày mấy (D6-B1) |
| `services/` | `ApiClient`, `ApiException` |
| `providers/` | `PlanProvider` (plan, hồ sơ của plan, lịch, bản nháp hồ sơ), `AuthProvider`, `GroceryProvider` (đã mua / đã có sẵn) |
| `screens/` | `onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`, `profile_screen.dart` |
| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart` |
| `theme/app_colors.dart` | Bảng màu dùng chung |

Ngoài `lib/`: `tool/make_icon.swift` + `tool/update_icons.sh` vẽ lại icon, `assets/icon/` là hai ảnh gốc. Chữ trên giao diện và comment viết tiếng Việt; số thập phân hiển thị kiểu Việt ("24,8").

## Luồng mở app

1. `SharedPreferences.getInstance()` đọc hết dữ liệu đã lưu một lần, sau đó đọc đồng bộ — không cần màn chờ.
2. `AuthProvider` nạp token và user; `PlanProvider` nạp hồ sơ, plan, lịch, bản nháp. Hồ sơ lưu từ trước mà nay bị luật v2.6.0 chặn (dưới 18 tuổi, thiếu cân + Giảm mỡ…) → bỏ plan, giữ hồ sơ để điền sẵn Onboarding (mọi request với hồ sơ đó đều bị 400).
3. `MainShell`: có plan → màn chính, tab Kế hoạch mở đúng ngày hôm nay; chưa có → Onboarding. Mở app không gọi mạng, nên có plan thì xem được khi không có mạng (NFR-2). App quay lại foreground (ví dụ qua nửa đêm) → tính lại ngày.

## Màn hình

| Màn | Làm gì |
|---|---|
| Onboarding | 3 bước (D6-B2): cơ thể (giới tính, mang thai / cho con bú nếu là nữ, tuổi, chiều cao, cân nặng) → mức vận động và mục tiêu → hạn chế. Báo lỗi ngay dưới ô; nút tiếp tục khoá tới khi bước hợp lệ; "Giảm mỡ" bị khoá kèm lý do khi thiếu cân hoặc mang thai (#30). Nút Back của hệ thống quay lại bước trước. Nút luôn ở đáy nên màn hình nhỏ không đẩy nút xuống dưới mép |
| Hạn chế (D5) | 3 công tắc "Tôi có …" (tắt = không có) → chip chọn nhiều + "Khác" tự ghi; tối đa 300 ký tự mỗi mục; dòng khuyến cáo y tế (NFR-9) |
| Màn chờ | Gọi `PlanProvider.generate()`; sau 15 s đổi câu "có thể mất tới 40 giây". Lỗi → câu của `ApiException` + "Thử lại", "Sửa hồ sơ", và "Về kế hoạch đang có" nếu đã có plan |
| Kế hoạch | 3 tab ngày, mở sẵn hôm nay; 3 bữa (calo, đạm, tinh bột, béo, nguyên liệu); tổng ngày so với `daily_target` bằng `MacroRing` (phần trăm thật, có thể > 100%); buổi tập; `warnings`; nhãn "Thực đơn mẫu" khi `source = sample`. Dải nhắc: hồ sơ đã sửa, kế hoạch đã hết (> 3 ngày), chưa tới ngày bắt đầu |
| Đổi món / đổi bài | Gọi API (FR-4.1, FR-4.2 — chuyển từ giai đoạn 7 lên); khoá mọi nút khi `busy`, vòng xoay đúng nút đang chờ; 409 → câu của server + nút "Tạo mới"; 422 và lỗi khác → câu của server |
| Đi chợ | Dựng từ `grocery_list` (#7), tên nhóm theo BRD FR-3.1; tích "đã mua"; "đã có sẵn" ẩn khỏi danh sách cần mua, "Hiện lại" → "Cần mua"; tìm kiếm (`matchesSearch()` trong `lib/models/search_text.dart`: gõ không dấu "ga" ra "Thịt gà", "Gạo tẻ"; gõ có dấu thì so đúng dấu — "cá" không ra "Cà chua"), lọc nhóm. Không có nút thêm nguyên liệu |
| Cá nhân | Tóm tắt hồ sơ (BMI, calo mục tiêu); sửa bằng cùng form, lưu thành **bản nháp** — plan đang mở vẫn dùng hồ sơ cũ nên đổi món không bị 409; dải "Tạo kế hoạch mới" dùng bản nháp |
| Lịch sử | Chỗ giữ — đăng nhập và lịch sử ở giai đoạn 8 |
| Feedback cuối ngày | Chưa có nút — làm lại theo D2 ở giai đoạn 7 |

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

Đổi món, đổi bài, feedback gửi lại **nguyên** plan và server kiểm từng ID, con số (#24). Nên `MealPlan.fromJson(json).toJson()` phải bằng đúng `json`: đọc số qua `num` để giữ `22.5` là `22.5` và `640` là `640`. Thiếu trường, sai kiểu, mã lạ → `FormatException` nêu tên trường (`json_read.dart`), không đoán (#26). `Profile` có `pregnantOrBreastfeeding` (JSON `pregnant_or_breastfeeding`, luôn gửi đi; hồ sơ lưu trước v2.6.0 thiếu trường này thì đọc thành `false`).

## Fixture hợp đồng

`backend_api/test/contract-fixtures.e2e-spec.ts` gọi thật 14 tình huống (hồ sơ, `/health`, đăng nhập, tạo plan, lịch sử, đổi món, đổi bài, hai kiểu feedback, lỗi 400/401/404/409/422) và so với file JSON trong `frontend_app/test/fixtures/`, cộng `restriction_labels.json` — nhãn dị ứng / chấn thương bộ khớp từ khoá nhận ra (#32). UUID, token, thời điểm được thay bằng giá trị cố định; `RandomSource` cố định nên đổi món luôn ra cùng món. App dùng chính các file này cho test vòng tròn, `ApiClient`, provider, màn hình.

Khi đổi hợp đồng BRD 6 hoặc file từ khoá ở backend:

1. `cd backend_api && npm run fixtures:update` — ghi lại fixture;
2. sửa model trong `frontend_app/lib/models/api/` (hoặc chip trong `restriction_options.dart`) tới khi `flutter test` xanh;
3. commit fixture và phần sửa app cùng nhau.

Quên bước 1 → test backend đỏ ("… đã cũ — chạy npm run fixtures:update"); quên bước 2 → `contract_test.dart` hoặc `restriction_options_test.dart` đỏ.

## Lưu trên máy

| Khoá `shared_preferences` | Provider | Nội dung |
|---|---|---|
| `smartfit.profile.v1` | `PlanProvider` | hồ sơ đã tạo plan hiện tại, kể cả `restrictions` và cờ mang thai |
| `smartfit.plan.v1` | `PlanProvider` | plan hiện tại, đúng JSON server trả |
| `smartfit.plan_schedule.v1` | `PlanProvider` | `plan_id` + ngày bắt đầu (yyyy-mm-dd): tạo mới → hôm nay; feedback ngày 3 → ngày mai; đổi món/bài giữ nguyên |
| `smartfit.profile_draft.v1` | `PlanProvider` | hồ sơ đã sửa ở tab Cá nhân mà chưa tạo plan mới; giống hồ sơ của plan thì xoá |
| `smartfit.grocery.v1` | `GroceryProvider` | `plan_id` + món đã mua + món đã có sẵn; khoá mỗi dòng = nhóm + tên + lượng (lượng đổi sau khi đổi món → dòng đó bỏ tích); plan mới → xoá |
| `smartfit.access_token` | `AuthProvider` | JWT của backend (7 ngày) |
| `smartfit.user.v1` | `AuthProvider` | `id`, `email`, `name` |

- Số phiên bản trong khoá: đổi định dạng theo cách bản cũ không đọc được thì tăng số.
- Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai; lịch thiếu hoặc của plan khác → coi như bắt đầu hôm nay.
- Trên web, `shared_preferences` là `localStorage` của trình duyệt: dữ liệu sức khoẻ và token nằm trong trình duyệt. BRD chấp nhận việc lưu trên máy người dùng (NFR-7, D4); backend vẫn không lưu `restrictions` (#12).
- `PlanProvider.busy` = đang chờ server; gọi thêm khi đang bận bị bỏ qua, không ném lỗi. `PlanProvider` nhận đồng hồ (`now:`) để test đổi ngày.

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
| Windows | không cần cấu hình (app desktop Windows không có sandbox mạng) |

Android: `compileSdk = 36` trong `android/app/build.gradle.kts` — plugin Android của `shared_preferences` đòi biên dịch với API ≥ 36; `targetSdk` vẫn 34. Trước đó file này ghim `compileSdk = 34` và APK không build được. Từ D7 (2026-09-29), job `build` của CI build bản release APK, web, Windows, macOS nên lỗi kiểu này đỏ ngay trên CI.

## Tên app, icon, màn khởi động, thanh hệ thống (PLAN 6.8)

- Tên "SmartFit AI": `android:label`, `CFBundleDisplayName`, `web/index.html`, `web/manifest.json` (màu thương hiệu `#059669`).
- Icon: nền xanh, chữ "S" trắng bo tròn và chiếc lá. `tool/update_icons.sh` (macOS, cần `swift` và `sips` có sẵn) vẽ hai ảnh gốc bằng `tool/make_icon.swift` rồi chép đủ kích thước cho Android (icon vuông + icon thích ứng `mipmap-anydpi-v26`), iOS, macOS, web. Kết quả tất định — chạy lại ra đúng từng byte. Ảnh iOS không có kênh trong suốt (App Store bắt buộc).
- Màn khởi động: Android 12+ vẽ lớp trước của icon thích ứng (hình trắng) trên `windowSplashScreenBackground` = xanh thương hiệu (`values-v31/styles.xml`) — để nền mặc định trắng thì hình biến mất; Android cũ hơn hiện icon giữa nền trắng (`launch_background.xml`).
- Thanh trạng thái / điều hướng: theme `Theme.Light.NoTitleBar` mặc định tô đen thanh hệ thống và bỏ qua màu Flutter đặt → các theme bật `windowDrawsSystemBarBackgrounds`, nền trong suốt; `main()` bật `SystemUiMode.edgeToEdge`, màn hình dùng `SafeArea`.

Đã kiểm trên máy ảo Android 16 (Pixel 8, API 36): icon trên launcher, màn khởi động, thanh trạng thái sáng, luồng Onboarding → Dashboard → Đi chợ → Cá nhân, cỡ chữ 130%. Kiểm lại 2026-09-29 bằng bản **release** APK: đủ 3 bước Onboarding (tuổi 17 bị chặn; Back ở bước 2 về bước 1 giữ dữ liệu), dị ứng trứng + thịt bò + "Khác", đau gối → món và động tác bị thay đúng, macro mỗi ngày 97–103% mục tiêu; đổi món, đổi bài; đi chợ (đã mua, có sẵn, tìm kiếm); sửa hồ sơ → nháp → tạo kế hoạch mới; tắt hẳn app rồi mở lại vẫn giữ plan, đi chợ, nháp. macOS cùng ngày: integration test 3/3 và một lượt chụp từng màn trong cửa sổ 800×600 (cột giữa đúng). iOS và macOS (Xcode 27, 2026-09-27): `flutter test integration_test -d <máy>` 3/3 xanh trên iPhone 17 Simulator (iOS 27) và trên macOS — gồm luồng Onboarding → plan thật → Dashboard → đổi món và lưu trên máy; mở app trên Simulator thấy Onboarding đúng. Plugin (`shared_preferences`) chạy qua Swift Package Manager (`FlutterGeneratedPluginSwiftPackage` đã có trong `project.pbxproj`), không cần CocoaPods — `flutter doctor` vẫn báo thiếu CocoaPods, bỏ qua được. Tên app macOS là `PRODUCT_NAME` trong `macos/Runner/Configs/AppInfo.xcconfig` ("SmartFit AI"; trước đó `my_ai_app`). `xcode-select` đang trỏ Command Line Tools thì đặt `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` trước lệnh Flutter (đổi `xcode-select` cần sudo).

## Nền tảng (PLAN D7)

Nhắm tới Android, web, Windows, macOS; iOS tạm bỏ (vẫn build được — xem trên — nhưng không kiểm thử, không cấu hình riêng).

- `frontend.yml` có job `build` (chạy sau `flutter analyze` + `flutter test`): `flutter build apk|web|windows|macos --release` trên Ubuntu / Windows / macOS; file build để ở tab Actions 7 ngày (`smartfit-apk`, `-web`, `-windows`, `-macos` — bản macOS nén bằng `ditto` vì `upload-artifact` làm mất symlink và quyền chạy trong `.app`). Bản build trỏ backend mặc định (localhost; máy ảo Android `10.0.2.2`). JDK 21 cho APK (AGP 9 cần ≥ 17).
- Máy dev là Mac: bản Windows chỉ build được trên CI. Chưa chạy thử trên máy Windows thật.
- macOS: cửa sổ mở ở khổ đứng 600×760 (`contentRect` trong `macos/Runner/Base.lproj/MainMenu.xib`; template là 800×600 — thấp, ô khuyến cáo ở bước 3 bị che, Dashboard chỉ thấy một bữa), nhỏ nhất 360×560, căn giữa (`MainFlutterWindow.swift`). Các lần mở sau macOS tự khôi phục cỡ người dùng đã chỉnh — kể cả sau khi app bị tắt ngang, nên thử cỡ mở đầu phải chạy `"SmartFit AI.app/Contents/MacOS/SmartFit AI" -ApplePersistenceIgnoreState YES`. Đặt cỡ bằng `setContentSize` trong `awakeFromNib` không có tác dụng vì bị khôi phục đè.
- Windows: `BINARY_NAME` = `smartfit_ai` (`windows/CMakeLists.txt`), tiêu đề cửa sổ ở `windows/runner/main.cpp`, thông tin file ở `windows/runner/Runner.rc`; icon `windows/runner/resources/app_icon.ico` do `tool/update_icons.sh` gói từ 7 ảnh PNG 16–256 px bằng `tool/make_ico.swift` (mỗi mục giữ dạng PNG — Windows Vista trở lên đọc được).
- Cửa sổ rộng: `AppFrame` (`lib/widgets/app_frame.dart`) đặt ở `MaterialApp.builder` giữ cả app — thanh tab, bảng trượt, hộp thoại, SnackBar — trong cột giữa rộng tối đa 640, hai bên nền xám nhạt, và sửa `MediaQuery.size` cho khớp bề rộng cột. Kéo cửa sổ qua ngưỡng không mất màn hình đang mở (Navigator của `MaterialApp` có `GlobalKey`). Test: `widget_test.dart` ("cửa sổ rộng …").

## Test

- `cd frontend_app && flutter test` — 94 test, không cần backend chạy:
  - `test/models/` — vòng tròn fixture (`contract_test.dart`), luật hồ sơ, chip hạn chế so với `restriction_labels.json`, lịch ngày;
  - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
  - `test/providers/` — `SharedPreferences.setMockInitialValues()`, đồng hồ giả;
  - `test/screens/` — từng màn hình; `test/widget_test.dart` — luồng của cả app;
  - `test/app_harness.dart` — dựng app/màn hình cỡ điện thoại (411×914 dp) với backend giả, dữ liệu đã lưu, đồng hồ giả; `fillOnboarding()`, `scrollTo()` (danh sách chỉ dựng phần đang hiện — cuộn rồi `ensureVisible` trước khi bấm);
  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, `responses` thay JSON cho một đường dẫn, ghi lại request.
- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (điền Onboarding → plan thật → Dashboard → đổi món). Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`. Máy ảo mở lại từ snapshot đôi khi làm test treo ở màn khởi động (bản debug chờ `flutter` kết nối mãi) — tắt máy ảo rồi khởi động nguội: `emulator -avd <tên> -no-snapshot-load`.
- Chưa có máy ảo: Android Studio → Device Manager → tạo thiết bị (ví dụ Pixel 8, API 36).
- `Container` có màu nền bọc `ListTile`/`SwitchListTile`/`ExpansionTile` → Flutter báo lỗi ở bản debug (hiệu ứng bấm bị che) — dùng `Material` có `shape` thay cho `Container`.
- CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi, rồi build 4 nền tảng (mục "Nền tảng").
- Code viết từ giai đoạn 6 theo `dart format --line-length 120`; file cũ chưa theo định dạng nào thì không format lại cả file (sẽ gộp dòng ở các widget không liên quan). CI không kiểm format.

## Việc của giai đoạn sau

- **7:** bảng feedback cuối ngày theo D2 (3 câu hỏi, chọn nhiều tình trạng cơ thể), khoá sau khi gửi cho một ngày; `FeedbackResult.safetyWarning` → cảnh báo nổi bật. `PlanProvider.submitFeedback()` đã có (plan ngày 3 bắt đầu từ ngày mai).
- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`; tab Lịch sử.
- Thực đơn mẫu lệch macro so với mục tiêu (ví dụ tinh bột ~120%, chất béo ~70%) vì chỉ được nhân khẩu phần theo calo; backend không kiểm tỉ lệ macro — Dashboard hiện đúng phần trăm thật. Ghi ở mục "Để sau" của PLAN.
