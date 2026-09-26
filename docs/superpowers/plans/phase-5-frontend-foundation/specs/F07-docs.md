# F07 — Tài liệu: wiki, CLAUDE.md, README, PLAN.md, SETUP_CREDENTIALS

## Feature

Ghi lại những gì giai đoạn 5 thêm, để người sau (và các skill đọc wiki) biết tầng kết nối API nằm đâu, chạy app với backend thế nào, và các quy tắc mới. **Không đổi BRD** (vẫn v2.5.1): CORS, `CORS_ORIGINS`, fixture và CI là chi tiết triển khai, không đổi phạm vi hay hợp đồng API.

## Scope

Docs:

- `docs/knowledge/wiki/flutter-ui.md` (mới), `critical-constraints.md`, `wiki-triggers.md`, `INDEX.md`, `log.md`
- `docs/knowledge/CLAUDE.md`
- `CLAUDE.md`, `README.md`, `docs/PLAN.md`, `docs/SETUP_CREDENTIALS.md`

## Implementation

### API Routes

Không có.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- Tên file wiki tiếng Anh, nội dung tiếng Việt.
- Ràng buộc mới #26–#29; #12 trỏ sang #28.

## Definition of Done

- [ ] `grep -rn "chưa có — tạo ở giai đoạn 5" docs/` không ra dòng nào
- [ ] `critical-constraints.md` có #26–#29; `INDEX.md` có `[[flutter-ui]]`
- [ ] PLAN.md: 5.1–5.9 đã tích; 6.6, 6.7, 9.2, 9.3 cập nhật
- [ ] README: cách chạy app với backend trên từng nền tảng; changelog có giai đoạn 5
- [ ] CLAUDE.md không còn câu "no `http`, `provider`, or `shared_preferences`" hay "Not yet wired"

## Test Checklist

1. **@links**: mọi `[[...]]` trong `flutter-ui.md` trỏ tới bài có thật (`critical-constraints`, `plan-data-contract`, `swap-and-feedback`, `auth-and-history`)
2. **@commands**: lệnh trong README/CLAUDE.md chạy được như ghi (`flutter test`, `npm run fixtures:update`)
3. Các nhãn **@auth**, **@timeout**, **@partial-fail**, **@token**, **@db**: không áp dụng

## Tasks

### Task 1 — Bài wiki mới `docs/knowledge/wiki/flutter-ui.md`

```markdown
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
| Android | `INTERNET` trong `android/app/src/main/AndroidManifest.xml` (bản release); `usesCleartextTraffic="true"` chỉ trong manifest debug |
| iOS | `NSAppTransportSecurity` → `NSAllowsLocalNetworking` trong `ios/Runner/Info.plist` |
| macOS | `com.apple.security.network.client` trong cả `DebugProfile.entitlements` và `Release.entitlements` |
| Web | không cần; cần CORS phía backend |

Chưa chạy thử trên máy ảo Android, iOS Simulator hay macOS: máy lập plan giai đoạn 5 không có Xcode và tải Gradle bị ngắt. Bản web build và chạy được.

## Test

- `cd frontend_app && flutter test` — 44 test, không cần backend chạy:
  - `test/models/contract_test.dart` — vòng tròn fixture, kiểu số, JSON sai hợp đồng;
  - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
  - `test/providers/` — `SharedPreferences.setMockInitialValues()`;
  - `test/widget_test.dart` — màn đầu theo dữ liệu đã lưu;
  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, ghi lại request.
- CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi.
- Code có sẵn chưa theo `dart format` ở khổ dòng nào, nên CI không kiểm format; sửa file cũ thì không format lại cả file (sẽ gộp dòng ở các widget không liên quan).

## Việc của giai đoạn sau

- **6:** màn hình đọc/ghi qua `PlanProvider`, `AuthProvider` và model `lib/models/api/`, xoá view-model cũ; Loading gọi `PlanProvider.generate()`; lỗi hiện `ApiException.message`; widget test dùng `FakeBackend`; chạy thử trên máy ảo Android.
- **7:** nút đổi món, đổi bài, bảng feedback; 409 → gợi ý tạo plan mới; `FeedbackResult.safetyWarning` → cảnh báo nổi bật.
- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`.
```

### Task 2 — `critical-constraints.md`

Cột "Lý do" của **#12**, thêm vào cuối: ` Phía app: #28.`

Thêm 4 dòng cuối bảng:

```markdown
| 26 | Model Dart trong `frontend_app/lib/models/api/` phải đi vòng tròn: `fromJson(json).toJson()` bằng đúng JSON server gửi — không rơi trường, giữ nguyên `int`/`double` (đọc số qua `num`). Thiếu trường, sai kiểu, mã lạ → `FormatException` nêu tên trường, không đoán. Đổi hợp đồng BRD 6 ở backend → `cd backend_api && npm run fixtures:update`, sửa model Dart, commit fixture (`frontend_app/test/fixtures/`) và model cùng nhau. | Quyết định Q1 giai đoạn 5. Đổi món, đổi bài, feedback gửi lại nguyên plan và server kiểm từng ID, con số (#24): `toJson` lệch một trường là mọi thao tác sau bị 400/409. `backend_api/test/contract-fixtures.e2e-spec.ts` đỏ khi fixture cũ; `frontend_app/test/models/contract_test.dart` đỏ khi model lệch fixture. |
| 27 | CORS chỉ cấu hình trong `resolveCorsOptions()` (`backend_api/src/cors-options.ts`), gọi từ `configureApp()` (#18), qua biến `CORS_ORIGINS` (danh sách `http(s)://host[:port]` cách nhau dấu phẩy). Trống khi phát triển → `http://localhost` và `http://127.0.0.1` mọi cổng; trống khi `NODE_ENV=production` → tắt CORS; origin sai dạng → backend không khởi động. Header cho phép phải có `Authorization`; `credentials: false`; không dùng `origin: true` hay `*`. | Quyết định Q2 giai đoạn 5. Trước đó preflight trả 404 nên mọi POST từ bản web bị trình duyệt chặn (phát hiện F1). Đã kiểm trong Chrome thật: origin không khai báo bị chặn cả GET lẫn POST. App mobile không gửi `Origin` nên không bị ảnh hưởng. |
| 28 | App Flutter gọi backend chỉ qua `ApiClient` (`frontend_app/lib/services/api_client.dart`): timeout 60 s cho request có thể gọi Gemini (dài hơn 40 s của backend — #15), 15 s cho phần còn lại; body đọc bằng UTF-8 từ `bodyBytes`; mọi lỗi thành `ApiException` có câu tiếng Việt cho người dùng. **Không** in request/response body, hồ sơ hay token ra log (`print`, `debugPrint`, `log`); chi tiết lỗi 400 chỉ giữ trong `ValidationException.details`. Hồ sơ (kể cả `restrictions`) và JWT chỉ lưu trên máy bằng `shared_preferences` (web: `localStorage`), khoá có số phiên bản, bản lưu hỏng thì xoá. | BRD NFR-2, NFR-7, mục 4; quyết định Q3 giai đoạn 5. Body chứa dữ liệu sức khoẻ (#12). App hết giờ trước backend thì báo lỗi trong khi plan vẫn đang được tạo (phát hiện F8). Không có `Content-Type` thì package `http` giải mã latin1 — tên món tiếng Việt bị vỡ. |
| 29 | Quyền mạng: Android khai báo `INTERNET` trong `android/app/src/main/AndroidManifest.xml` (bản release), `usesCleartextTraffic` **chỉ** trong manifest debug; iOS dùng `NSAllowsLocalNetworking` (không dùng `NSAllowsArbitraryLoads`); macOS có `com.apple.security.network.client` trong cả `DebugProfile.entitlements` lẫn `Release.entitlements`. Bản release chỉ gọi backend qua `https://`. | Phát hiện F3, F4 giai đoạn 5: template Flutter chỉ có `INTERNET` trong manifest debug, nên APK demo (PLAN 9.3) sẽ không gọi được mạng; app macOS chạy trong sandbox, thiếu quyền gọi ra ngoài; Android 9+ và iOS chặn `http://`. |
```

`last_updated: 2026-09-26`. Câu mở đầu "Các quy tắc bắt buộc phải biết trước khi đụng vào `backend_api/src/` (plan, auth, database, history), prompt Gemini, hoặc hợp đồng request/response." → "Các quy tắc bắt buộc phải biết trước khi đụng vào `backend_api/src/` (plan, auth, database, history), prompt Gemini, hợp đồng request/response, hoặc tầng kết nối API của `frontend_app/` (model, `ApiClient`, provider, cấu hình mạng theo nền tảng)."

### Task 3 — `wiki-triggers.md`

- `last_updated: 2026-09-26`.
- Câu mở đầu "Flutter chỉ lưu `access_token` và plan hiện tại bằng `shared_preferences`." → "Flutter lưu JWT, hồ sơ và plan hiện tại trên máy bằng `shared_preferences` (`frontend_app/lib/providers/`, từ giai đoạn 5)."
- Bảng theo đường dẫn — thay hai dòng `flutter-ui.md` *(chưa có…)* bằng:

```markdown
| `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
| `frontend_app/lib/models/**`, `frontend_app/lib/services/**`, `frontend_app/lib/providers/**`, `frontend_app/lib/config/**`, `frontend_app/test/**` | `flutter-ui.md`, `critical-constraints.md` (#26, #28) |
| `backend_api/src/cors-options.ts`, `backend_api/test/cors.e2e-spec.ts`, `backend_api/test/contract-fixtures.e2e-spec.ts` | `flutter-ui.md`, `critical-constraints.md` (#26, #27) |
| `frontend_app/pubspec.yaml`, `frontend_app/android/**/AndroidManifest.xml`, `frontend_app/ios/Runner/Info.plist`, `frontend_app/macos/Runner/*.entitlements`, `.github/workflows/frontend.yml` | `flutter-ui.md`, `critical-constraints.md` (#29) |
```

- "Trigger bổ sung", gạch đầu dòng thứ hai → "Hợp đồng request/response (BRD.md mục 6) thay đổi mà `backend_api/src/plan/dto/`, `enums/`, `data/sample-plan.json`, fixture `frontend_app/test/fixtures/` (`npm run fixtures:update`) và model `frontend_app/lib/models/api/` chưa cập nhật khớp theo"
- Bảng từ khoá — thay dòng Flutter bằng hai dòng:

```markdown
| screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
| CORS / API_BASE_URL / dart-define / ApiClient / provider / shared_preferences / fixture hợp đồng / quyền mạng | `flutter-ui.md`, `critical-constraints.md` |
```

### Task 4 — `INDEX.md`, `log.md`, `docs/knowledge/CLAUDE.md`

`INDEX.md`: `_Cập nhật lần cuối: 2026-09-26_`; thêm dòng trước `[[log]]`:

```markdown
| [[flutter-ui]]              | App Flutter: model theo hợp đồng, ApiClient, provider, lưu trên máy, fixture hợp đồng, CORS, quyền mạng |
```

`log.md`, thêm cuối file:

```markdown
2026-09-26 — Giai đoạn 5 (PLAN.md): thêm bài [[flutter-ui]]; thêm ràng buộc #26 (model Dart đi vòng tròn + fixture hợp đồng), #27 (CORS qua `CORS_ORIGINS`), #28 (app gọi backend qua `ApiClient`, không log body, lưu trên máy), #29 (quyền mạng theo nền tảng); #12 trỏ sang #28; wiki-triggers không còn trỏ tới `flutter-ui.md` như bài chưa có
```

`docs/knowledge/CLAUDE.md`, mảng trọng tâm 3 → "Giao diện Flutter trong `frontend_app/` — screens/widgets và tầng kết nối API (có từ giai đoạn 5, xem [[flutter-ui]])".

### Task 5 — `CLAUDE.md` (gốc repo)

**Repository layout**, gạch đầu dòng `frontend_app/` → thay cả đoạn bằng:

```markdown
- **`frontend_app/`** — Flutter app. Since phase 5 it has the API layer (`http`, `provider`, `shared_preferences`; models in `lib/models/api/`, `ApiClient` in `lib/services/`, `PlanProvider`/`AuthProvider` in `lib/providers/`), but the **screens still render hardcoded mock data** through the old view-models in `lib/models/meal_plan.dart` — wiring them to the providers is phase 6. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package.
```

Câu "When asked to "connect the app to the backend," …" → thay bằng:

```markdown
When asked to "connect the app to the backend," the plumbing exists (phase 5): screens should read and write through `PlanProvider`/`AuthProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).
```

**Commands → Frontend** — thay khối lệnh bằng:

```bash
flutter pub get                 # install dependencies
flutter run -d chrome           # run on Chrome; backend defaults to http://localhost:3000 (Android emulator: 10.0.2.2)
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000   # real phone: LAN IP of the machine running backend_api
flutter run                     # run on a connected device/emulator
flutter analyze                 # static analysis (flutter_lints, default rule set)
flutter test                    # run all tests (no backend needed; fixtures in test/fixtures/)
flutter test test/services/api_client_test.dart   # run a single test file
```

**Commands → Backend** — thêm sau dòng `npm run test:e2e`:

```bash
npm run fixtures:update         # rewrite frontend_app/test/fixtures/ after changing the BRD §6 contract, then fix the Dart models
```

Đoạn về test, câu cuối (GitHub Actions) → thay bằng:

```markdown
`test/contract-fixtures.e2e-spec.ts` compares real responses with the JSON fixtures committed in `frontend_app/test/fixtures/` (UUIDs, token and timestamps normalised; `RandomSource` fixed) — the Flutter tests use the same files, so a contract change fails on both sides until `npm run fixtures:update` is run and the Dart models are fixed. GitHub Actions: `.github/workflows/backend.yml` runs build + typecheck + unit + e2e + smoke on Node 24 and 26 on every push touching `backend_api/`, `ai_workspace/` or the fixtures; `.github/workflows/frontend.yml` runs `flutter analyze` + `flutter test` on Flutter 3.47.5 for `frontend_app/`. No secrets.
```

**Backend architecture**, gạch đầu dòng `src/app.setup.ts` → thay bằng:

```markdown
- `src/app.setup.ts` — `configureApp()` applies the global `ValidationPipe({ whitelist: true, transform: true })`, CORS from `resolveCorsOptions()` (`src/cors-options.ts`: `CORS_ORIGINS` comma list; empty in dev → any port on `http://localhost`/`http://127.0.0.1` for `flutter run -d chrome`; empty with `NODE_ENV=production` → CORS off, mobile only; malformed → boot fails), and mounts Swagger at `/docs` (JSON at `/docs-json`), with bearer auth so Swagger shows an Authorize button. Both `main.ts` and the e2e tests call it; put new global app config there, not in `main.ts`.
```

**Frontend architecture** — thay cả mục (giữ câu cuối về chữ tiếng Việt) bằng:

```markdown
## Frontend architecture

- `lib/main.dart` — `main()` awaits `SharedPreferences.getInstance()` before `runApp`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())` and both providers; `SmartFitApp(auth:, plans:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart`). `MainShell` owns navigation (`AppScreen` enum: onboarding → loading → dashboard → grocery; `setState` + `switch` in `_buildBody()`, no router); it opens on the dashboard if `PlanProvider.hasPlan`, else onboarding. The existing files are not `dart format`-ed — don't reformat whole files (it reflows unrelated widgets); CI doesn't check format.
- `lib/config/api_config.dart` — `resolveApiBaseUrl()`: `--dart-define=API_BASE_URL`, else `http://10.0.2.2:3000` on Android, `http://localhost:3000` elsewhere.
- `lib/models/api/` — hand-written models for BRD §6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…; enums in `codes.dart`). `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
- `lib/models/meal_plan.dart` — old UI view-models (`MealItem`, `DayPlan`, `GroceryCategory`…) the screens still use with hardcoded data; removed in phase 6.
- `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text (400 details stay in `ValidationException.details`); a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
- `lib/providers/` — `PlanProvider` (profile + plan in `shared_preferences` keys `smartfit.profile.v1` / `smartfit.plan.v1`; `busy` flag, calls while busy are ignored; corrupt data dropped) and `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401).
- `lib/screens/` — one file per screen; `lib/widgets/` — `macro_ring.dart`, `feedback_bottom_sheet.dart`.
- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest, iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements.
```

### Task 6 — `README.md`

Cấu trúc thư mục: `frontend_app/    Ứng dụng Flutter (đang phát triển UI, dùng dữ liệu mẫu)` → `frontend_app/    Ứng dụng Flutter (đã có tầng gọi API; màn hình còn dùng dữ liệu mẫu tới giai đoạn 6)`.

Mục **Frontend (Flutter)** → thay khối lệnh bằng:

````markdown
```bash
cd frontend_app
flutter pub get
flutter run -d chrome   # hoặc flutter run cho thiết bị/máy ảo
flutter test            # không cần backend chạy
```

App gọi backend ở `http://localhost:3000` (máy ảo Android: `http://10.0.2.2:3000`). Chạy trên điện thoại thật thì chỉ địa chỉ máy đang chạy backend, hai máy cùng Wi-Fi:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000
```
````

Changelog: tiêu đề `### BRD v2.5.1 — 2026-09-24` → `### BRD v2.5.1 — 2026-09-24 → 2026-09-26`; thêm gạch đầu dòng đầu tiên:

```markdown
- Giai đoạn 5 — nền tảng kết nối app với backend: app Flutter có model theo đúng hợp đồng API, lớp gọi API báo lỗi bằng tiếng Việt thay vì crash (mất mạng, hết giờ, phiên hết hạn…), lưu kế hoạch và phiên đăng nhập trên máy — mở lại app vẫn xem được kế hoạch khi không có mạng. Backend bật CORS cho bản web (`CORS_ORIGINS`). Backend xuất 14 mẫu JSON thật để test hai phía cùng dùng — đổi hợp đồng mà quên cập nhật phía nào thì test phía đó đỏ. Thêm CI cho Flutter (44 test); sửa quyền mạng Android/iOS/macOS. Màn hình vẫn dùng dữ liệu mẫu tới giai đoạn 6
```

### Task 7 — `docs/PLAN.md`

Mục **Hiện trạng**:

- dòng Backend: thêm `, CORS cho bản web` sau `Swagger UI`;
- dòng Frontend → `- [x] Frontend: giao diện Onboarding, Loading, Dashboard, Grocery, bảng Feedback (dữ liệu mẫu); tầng kết nối API — model theo hợp đồng, \`ApiClient\`, provider, lưu trên máy (giai đoạn 5). Màn hình **chưa nối API** (giai đoạn 6)`.

Giai đoạn 5 → thay danh sách bằng:

```markdown
- [x] **5.1** Thêm package `http`, `provider`, `shared_preferences`
- [x] **5.2** Địa chỉ backend qua `--dart-define=API_BASE_URL` — web: `localhost`; máy ảo Android: `10.0.2.2`; điện thoại thật: IP mạng LAN của máy chạy backend (`lib/config/api_config.dart`). Quyền mạng Android (release), iOS, macOS
- [x] **5.3** Model Dart có `fromJson`/`toJson` theo BRD mục 6 (`lib/models/api/`), đi vòng tròn đúng JSON server trả. Màn hình chuyển sang model mới và xoá view-model cũ `meal_plan.dart` ở 6.7
- [x] **5.4** `ApiClient` (`lib/services/`): gọi mọi endpoint; lỗi → `ApiException` có câu tiếng Việt, không crash (NFR-2); timeout 60 s cho request có Gemini
- [x] **5.5** `PlanProvider` (plan + hồ sơ, lưu `shared_preferences`) và `AuthProvider` (JWT; 401 → đăng xuất)
- [x] **5.6** `MainShell`: chưa có plan → mở Onboarding, đã có → Dashboard; viết lại `widget_test.dart`
- [x] **5.7** Bật CORS trong `configureApp()` qua `CORS_ORIGINS` (trống khi phát triển → `localhost`/`127.0.0.1` mọi cổng; trống khi deploy → tắt), cho phép header `Authorization`
- [x] **5.8** *(bổ sung, quyết định Q1)* Fixture hợp đồng: backend xuất 14 JSON thật vào `frontend_app/test/fixtures/` (`npm run fixtures:update`), test hai phía cùng dùng
- [x] **5.9** *(bổ sung, quyết định Q4)* CI Flutter: `flutter analyze` + `flutter test` (`.github/workflows/frontend.yml`)

Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-5-frontend-foundation.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-5-frontend-foundation/`.
```

Giai đoạn 6:

- 6.6 → `- [ ] **6.6** Widget test dùng backend giả \`test/fake_backend.dart\` (có từ giai đoạn 5)`;
- thêm sau 6.6: `- [ ] **6.7** Màn hình đọc/ghi qua \`PlanProvider\`/\`AuthProvider\` và model \`lib/models/api/\`; xoá view-model cũ \`lib/models/meal_plan.dart\`. Chạy thử trên máy ảo Android (quyền mạng giai đoạn 5 chưa kiểm được trên máy thật)`.

Giai đoạn 9:

- 9.2: thêm `, \`CORS_ORIGINS\` (địa chỉ bản web, nếu deploy bản web)` sau `GEMINI_API_KEY`;
- 9.3 → `- [ ] **9.3** Build app để demo: bản web và/hoặc APK Android, với \`--dart-define=API_BASE_URL=https://<địa chỉ backend>\``.

### Task 8 — `docs/SETUP_CREDENTIALS.md`

Mục 2.3, thêm gạch đầu dòng cuối danh sách (sau dòng `DATABASE_PATH`):

```markdown
- Bản web của app chạy ở địa chỉ khác backend nên cần CORS. Khi phát triển, để trống `CORS_ORIGINS` (cho `localhost` mọi cổng). Khi deploy bản web, đặt `CORS_ORIGINS=https://<địa chỉ bản web>` — cùng địa chỉ khai báo ở "Authorized JavaScript origins" của Web Client ID (giai đoạn 8). Để trống khi `NODE_ENV=production` thì chỉ app mobile gọi được.
```

### Task 9 — Cổng kiểm tra F07

```bash
grep -rn "chưa có — tạo ở giai đoạn 5" docs/ || echo "sạch"
grep -c "^| 2[6-9] |" docs/knowledge/wiki/critical-constraints.md   # 4
grep -n "no \`http\`\|Not yet wired" CLAUDE.md || echo "sạch"
```
