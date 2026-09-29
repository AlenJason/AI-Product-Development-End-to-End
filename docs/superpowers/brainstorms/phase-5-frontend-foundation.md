# Brainstorm: Giai đoạn 5 — Frontend: nền tảng
**Source:** `docs/PLAN.md` (giai đoạn 5, bước 5.1–5.7) + `BRD.md` v2.5.1 (mục 4 — lựa chọn công nghệ Flutter, mục 6 — hợp đồng API, NFR-1, NFR-2, NFR-7)
**Date:** 2026-09-24

## 1. Phạm vi

| Bước | Nội dung |
|---|---|
| 5.1 | Thêm `http`, `provider`, `shared_preferences` |
| 5.2 | Địa chỉ backend qua `--dart-define=API_BASE_URL` (web `localhost`, máy ảo Android `10.0.2.2`, điện thoại thật: IP LAN) |
| 5.3 | Model Dart có `fromJson`/`toJson` theo BRD mục 6 |
| 5.4 | `ApiClient` gọi mọi endpoint; lỗi mạng → thông báo dễ hiểu, không crash (NFR-2) |
| 5.5 | `PlanProvider` (plan hiện tại, lưu `shared_preferences`) và `AuthProvider` (JWT) |
| 5.6 | `MainShell`: chưa có plan → Onboarding, đã có → Dashboard; sửa `widget_test.dart` |
| 5.7 | Bật CORS trong `configureApp()` của backend |

Giai đoạn 5 **chỉ dựng nền**. Các màn hình vẫn hiển thị dữ liệu mẫu; nối Onboarding, Loading, Dashboard, Grocery với API là việc của giai đoạn 6.

## 2. Ngữ cảnh đã nạp

- **Wiki:**
  - `INDEX.md`, `wiki-triggers.md`;
  - `critical-constraints.md` (#1–#25);
  - `auth-and-history.md` (JWT 7 ngày, 401 khi token sai hoặc user đã xoá);
  - `swap-and-feedback.md` (client gửi lại **nguyên** plan, 400/409/422);
  - `plan-data-contract.md`, `gemini-integration.md` (đo thật: tạo plan 8–15 s, tối đa ~40 s);
  - `reference-materials.md` mục 3 (Flutter: chỉ ghi `shared_preferences` cần Dart ≥ 3.9 — đã thoả).
- **Chưa có bài `flutter-ui.md`:** `wiki-triggers.md` ghi "tạo ở giai đoạn 5". Giai đoạn này viết bài đó.
- **Điều kiện nạp ràng buộc: có**, vì có lưu và gửi token đăng nhập, gọi mọi endpoint, và sửa cấu hình backend (CORS). Liên quan trực tiếp:
  - #3: khoá Gemini không bao giờ nằm trong app;
  - #10: app lưu JWT của backend, không lưu ID Token Google — FR-6.3;
  - #12: `restrictions` chỉ nằm trên máy; app cũng không được in request body ra log;
  - #13: app không tự tính BMR/calo, chỉ hiển thị `daily_target` server trả;
  - #16: ID do server gán, app không tự tạo;
  - #18: CORS phải nằm trong `configureApp()`;
  - #22, #24: 401 → đăng nhập lại; 409 → hồ sơ đã đổi, tạo plan mới; client phải gửi lại plan **đúng như server đã trả**.

## 3. Phát hiện — kiểm chứng ngày 2026-09-24

| # | Phát hiện | Cách kiểm |
|---|---|---|
| F1 | **Backend chưa trả lời preflight CORS:** `OPTIONS /api/v1/generate-plan` với `Origin: http://localhost:5000` → **404**, không có `Access-Control-Allow-Origin`. Flutter web gửi `Content-Type: application/json` (và `Authorization`) nên **mọi POST từ bản web đều bị trình duyệt chặn** | `curl -X OPTIONS` vào backend bản build |
| F2 | **Test Flutter duy nhất đang đỏ:** `widget_test.dart` tìm chữ "MỤC TIÊU HÔM NAY", nhưng giao diện làm lại theo Figma (commit `445864b`) đã bỏ dòng chữ đó. `flutter analyze` sạch. Không ai phát hiện vì CI chỉ chạy backend | `flutter test`, `grep` trong `dashboard_screen.dart` |
| F3 | **Android bản release không có quyền `INTERNET`:** template chỉ khai báo trong `src/debug/AndroidManifest.xml`. APK demo (PLAN 9.3) sẽ không gọi được backend. Ngoài ra Android 9+ chặn HTTP không mã hoá (`http://10.0.2.2:3000`, `http://<IP LAN>:3000`) nếu không bật `usesCleartextTraffic` | Đọc `android/app/src/*/AndroidManifest.xml` |
| F4 | **macOS:** `DebugProfile.entitlements` chỉ có `network.server`, thiếu `network.client` → chạy app bản macOS sẽ không gọi được backend. **iOS:** chưa cấu hình ATS cho mạng LAN (`NSAllowsLocalNetworking`) | Đọc `macos/Runner/*.entitlements`, `ios/Runner/Info.plist` |
| F5 | Phiên bản hiện hành: `http` 1.6.0 (Dart ≥ 3.4), `provider` 6.1.5+1, `shared_preferences` 2.5.5 (Dart ≥ 3.9, Flutter ≥ 3.35). Máy dev: Flutter 3.47.5 / Dart 3.13.4 → đều dùng được | pub.dev API, `flutter --version` |
| F6 | **Plan phải đi vòng tròn chính xác:** đổi món và feedback gửi lại nguyên plan; server kiểm ID theo vị trí, `daily_target` phải bằng mục tiêu tính lại (khác → 409), và toàn bộ hợp đồng. Macro có thể là số thập phân (thực đơn mẫu nhân khẩu phần → `22.5`). Nếu `toJson` làm rơi trường hay đổi số, mọi thao tác sau sẽ bị 400/409 | Đọc `client-plan.ts`, `meal-scaling.ts` |
| F7 | Tên lớp bị trùng: `lib/models/meal_plan.dart` đang có view-model `MealItem`, `DayPlan`, `GroceryItem`… mà các màn hình dùng với dữ liệu viết cứng. PLAN 5.3 ghi "thay các view-model", nhưng làm vậy ở giai đoạn 5 sẽ kéo theo sửa toàn bộ màn hình, tức việc của giai đoạn 6 | Đọc `lib/screens/*.dart` |
| F8 | Thời gian chờ thật: `generate-plan` 8–15 s, tối đa ~40 s (giới hạn Gemini của backend) → timeout HTTP của app phải dài hơn (khoảng 60 s), nếu không app tự báo lỗi trong khi backend vẫn đang làm | wiki `gemini-integration.md` |

## 4. Các hướng tiếp cận

### Hướng A — Đúng những gì PLAN viết, tối giản

`http` + `provider` + `shared_preferences`, model viết tay, `ApiClient`, hai provider, `MainShell` rẽ nhánh, CORS.

- **Ưu:** đúng BRD, ít việc.
- **Nhược:** không có gì chặn backend và app **lệch hợp đồng** về sau (F6); test Flutter vẫn không chạy trên CI (F2 sẽ lặp lại).

### Hướng B — Bộ công cụ "hiện đại"

`dio` + `riverpod` + `freezed`/`json_serializable` (sinh code bằng `build_runner`) + `go_router`.

- **Ưu:** mạnh, phổ biến ở dự án lớn.
- **Nhược:**
  - **Lệch BRD mục 4**: BRD chọn `http` và `setState`/`Provider` vì dễ học cho sinh viên;
  - thêm bước sinh code;
  - viết lại điều hướng đang chạy.

### Hướng C — Hướng A + fixture hợp đồng + CI Flutter *(khuyến nghị)*

Như hướng A, thêm:

- **Fixture hợp đồng:** backend xuất JSON thật (plan mẫu, lịch sử, đăng nhập, feedback) ra `frontend_app/test/fixtures/`.
  - Một test backend kiểm fixture còn khớp output hiện tại; đổi hợp đồng thì test đỏ, nhắc xuất lại.
  - Test Flutter đọc fixture, kiểm `fromJson` → `toJson` ra **đúng** JSON ban đầu (F6).
- **Job CI** `flutter analyze` + `flutter test` (F2).

| | |
|---|---|
| **Ưu** | Bắt lệch hợp đồng ở cả hai phía; không đổi công nghệ BRD đã chọn |
| **Nhược** | Thêm một script xuất fixture và một job CI |

### Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| BRD mục 4 (công nghệ Flutter) | ✓ | ✗ lệch | ✓ |
| #3 khoá Gemini không trong app | ✓ | ✓ | ✓ |
| #10 lưu JWT backend, không lưu token Google | ✓ | ✓ | ✓ |
| #12 không log dữ liệu sức khoẻ | ✓ nếu `ApiClient` không in body | ✓ (dio có interceptor log → dễ lỡ in body) | ✓ |
| #18 CORS trong `configureApp()` | ✓ | ✓ | ✓ |
| #24 gửi lại plan nguyên vẹn | chỉ dựa vào viết code cẩn thận | ✓ nhờ sinh code | ✓ có test vòng tròn bằng JSON thật |

## 5. Thiết kế đề xuất (hướng C, để `/feature-plan` chi tiết hoá)

**Cấu trúc `lib/`:**

- `config/api_config.dart` — đọc `API_BASE_URL`; không có thì mặc định theo nền tảng: web/iOS/desktop `http://localhost:3000`, Android `http://10.0.2.2:3000`.
- `models/api/` — model viết tay theo BRD 6:
  - `MealPlan`, `DayPlan`, `Meal`, `Ingredient`, `Workout`, `Exercise`, `GroceryCategory`, `DailyTarget`;
  - `Profile`, `Restrictions`;
  - `AuthResult`, `PlanSummary`;
  - `FeedbackRequest`, `FeedbackResult`;
  - mã cố định là `enum` có `fromJson`, mã lạ → `FormatException`.

  Tên lớp đặt khác view-model cũ (F7); màn hình chuyển sang model mới và xoá view-model cũ ở giai đoạn 6.
- `services/api_client.dart` — `ApiClient` nhận `http.Client` (test thay bằng `MockClient` của `package:http/testing`):
  - `generatePlan`, `swapMeal`, `swapExercise`, `submitFeedback`, `loginWithGoogle`, `deleteAccount`, `history`, `historyPlan`, `health`;
  - timeout: 60 s cho các lời gọi có Gemini, 15 s cho phần còn lại;
  - lỗi thành các loại cụ thể (bảng dưới);
  - không bao giờ in request hay response body (#12).
- `providers/plan_provider.dart` — plan hiện tại + hồ sơ (kể cả `restrictions`, chỉ trên máy — NFR-7); lưu và đọc `shared_preferences` kèm số phiên bản dữ liệu; đọc lỗi thì xoá, quay về Onboarding.
- `providers/auth_provider.dart` — `access_token` + `user`; nhận `UnauthorizedException` → đăng xuất.
- `main.dart` — `MultiProvider`; `MainShell` đọc dữ liệu đã lưu (có màn chờ ngắn): chưa có plan → Onboarding, có → Dashboard (5.6).

**Lỗi `ApiClient` → thông báo cho người dùng:**

| Tình huống | Loại lỗi | Câu gợi ý |
|---|---|---|
| Không kết nối được (`SocketException`/`ClientException`, CORS bị chặn trên web) | `NetworkException` | "Không kết nối được máy chủ. Kiểm tra mạng hoặc địa chỉ backend." |
| Hết giờ | `ApiTimeoutException` | "Máy chủ phản hồi quá lâu, hãy thử lại." |
| 400 | `ValidationException` (kèm danh sách `message` server trả) | Nội dung server trả |
| 401 | `UnauthorizedException` | "Phiên đăng nhập hết hạn, vui lòng đăng nhập lại." |
| 404 | `NotFoundException` | "Không tìm thấy kế hoạch." |
| 409 | `PlanOutdatedException` | "Hồ sơ đã thay đổi, hãy tạo kế hoạch mới." |
| 422 | `NoReplacementException` | Nội dung server trả |
| 5xx / JSON hỏng | `ServerException` | "Máy chủ gặp lỗi, hãy thử lại sau." |

**Backend — CORS (5.7), trong `configureApp()` (#18):**

- Đọc `CORS_ORIGINS` (danh sách cách nhau dấu phẩy).
- Để trống khi phát triển → cho phép `http://localhost:*` và `http://127.0.0.1:*`, vì Flutter web chạy cổng ngẫu nhiên.
- Cho phép header `Content-Type`, `Authorization`; không dùng cookie nên `credentials: false`.
- Test e2e:
  - preflight từ `localhost` → 204 kèm header;
  - origin lạ → không có `Access-Control-Allow-Origin`;
  - app mobile (không gửi `Origin`) không bị ảnh hưởng.

**Nền tảng:**

- Android: quyền `INTERNET` vào manifest chính; cho HTTP không mã hoá **chỉ ở bản debug**.
- iOS: `NSAllowsLocalNetworking`.
- macOS: thêm `network.client` (F3, F4).

**Fixture hợp đồng:**

- Script backend `npm run export:fixtures` (chạy trên bản build, như `measure:gemini`) ghi JSON với `plan_id` và ngày cố định.
- `contract-fixtures.spec.ts` kiểm file đã commit còn khớp.
- Flutter `test/contract_test.dart`: mỗi fixture `fromJson` → `toJson` bằng đúng JSON gốc.

**CI:** job `frontend_app` dùng `subosito/flutter-action` (ghim Flutter 3.47.x), chạy `flutter pub get`, `flutter analyze`, `flutter test`; lọc đường dẫn `frontend_app/**`.

**Test Flutter** (không cần backend chạy):
- `ApiClient` với `MockClient`: mỗi mã lỗi, timeout, không có mạng;
- provider với `SharedPreferences.setMockInitialValues`: lưu, đọc, dữ liệu hỏng;
- widget test `MainShell`: chưa có plan → Onboarding, có plan → Dashboard;
- vòng tròn fixture.

## 6. Edge case

- **Plan cũ trong máy không đọc được** (app cập nhật, hợp đồng đổi) → xoá plan đã lưu, về Onboarding; hồ sơ giữ lại nếu còn đọc được.
- **Mở app khi không có mạng** mà đã có plan → vẫn vào Dashboard, xem được (NFR-2).
- **Token đã hết hạn** trong máy → lần gọi đầu nhận 401 → xoá token, dùng tiếp như khách (luồng đăng nhập lại ở giai đoạn 8).
- **Bấm tạo plan hai lần liên tiếp** → provider có cờ "đang gọi", bỏ qua lần bấm thứ hai.
- **`API_BASE_URL` sai hoặc backend chưa chạy** → `NetworkException` với câu hướng dẫn, không crash. Trên web, CORS bị chặn cũng hiện ra như lỗi mạng (trình duyệt không cho biết lý do) — ghi vào hướng dẫn.
- **Điện thoại thật:** backend phải nghe mọi địa chỉ (Nest `listen(PORT)` đã nghe mọi interface), tường lửa máy dev phải cho cổng 3000, hai máy cùng mạng Wi-Fi — ghi vào README.
- **Web:** `shared_preferences` dùng `localStorage`, nên dữ liệu sức khoẻ và token nằm trong trình duyệt. BRD chấp nhận việc này (lưu trên máy người dùng); ghi rõ trong bài wiki.
- **Số trong JSON:** đọc qua `num`, giữ số thập phân của macro; `calories` luôn là số nguyên từ server.

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

1. **Model Dart:**
   - (a) viết tay + fixture hợp đồng xuất từ backend, test vòng tròn *(khuyến nghị — dễ đọc với sinh viên, bắt được lệch hợp đồng)*;
   - (b) `json_serializable` + `build_runner` (sinh code);
   - (c) dán JSON vào quicktype như BRD gợi ý (sinh một lần, kiểu lỏng, phải sửa tay).
2. **CORS:**
   - (a) biến `CORS_ORIGINS`; để trống khi phát triển thì cho `localhost`/`127.0.0.1` mọi cổng; khi deploy (`NODE_ENV=production`) mà để trống thì tắt CORS, nghĩa là chỉ app mobile gọi được *(khuyến nghị)*;
   - (b) cho mọi origin (dễ nhất; an toàn tương đối vì không dùng cookie);
   - (c) chỉ một danh sách cố định.
3. **Lưu JWT:**
   - (a) `shared_preferences` như BRD mục 4 *(khuyến nghị cho đồ án — trên web dù sao cũng chỉ có `localStorage`)*;
   - (b) `flutter_secure_storage` trên mobile (Keychain/Keystore), web vẫn `localStorage` — an toàn hơn trên điện thoại, thêm một package và hai nhánh code.
4. **CI cho Flutter** (`flutter analyze` + `flutter test` mỗi lần push):
   - (a) thêm *(khuyến nghị — test Flutter đã đỏ mà không ai biết, F2)*;
   - (b) chưa cần.

Không hỏi, theo khuyến nghị (đổi được nếu muốn):

- Model API đặt ở `lib/models/api/`, tên khác view-model cũ; màn hình chuyển sang ở giai đoạn 6.
- Timeout 60 s cho lời gọi có Gemini.
- Sửa quyền mạng cho Android, iOS, macOS.
- Viết bài wiki `flutter-ui.md`.

## 8. Quyết định (2026-09-24)

| Câu hỏi | Quyết định |
|---|---|
| Q1 | **Model viết tay + fixture hợp đồng** xuất từ backend (`npm run export:fixtures`), test backend kiểm fixture đã commit còn khớp, test Flutter kiểm vòng tròn `fromJson` → `toJson` |
| Q2 | **`CORS_ORIGINS`**; để trống khi phát triển → `localhost`/`127.0.0.1` mọi cổng; `NODE_ENV=production` mà để trống → tắt CORS |
| Q3 | **`shared_preferences`** cho JWT (như BRD mục 4) |
| Q4 | **Thêm job CI Flutter** (`flutter analyze` + `flutter test`, lọc `frontend_app/**`) |

Không đổi phạm vi BRD: CORS và các biến mới được ghi trong SETUP, CLAUDE.md, wiki.

**Bước tiếp theo:** `/feature-plan phase-5-frontend-foundation`.
