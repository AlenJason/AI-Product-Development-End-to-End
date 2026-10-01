# Brainstorm: Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7)
**Source:** `docs/PLAN.md` (giai đoạn 8, bước 8.1–8.4; quyết định D7) + `BRD.md` v2.7.1 (FR-6, FR-7, mục 6.3, NFR-5, NFR-7)
**Date:** 2026-09-30

## 1. Phạm vi

- **8.1** Đăng nhập: "Đăng nhập demo" khi backend giả lập, Google Sign-In khi thật; đăng nhập là tuỳ chọn (FR-7 — có nút bỏ qua). FR-6.1: màn hình chào có nút "Đăng nhập với Google".
- **8.2** Gắn JWT vào request; 401 → đăng nhập lại.
- **8.3** Tab "Lịch sử" (hiện là chỗ giữ): danh sách plan (ngày tạo, calo mục tiêu — FR-7.2), bấm xem chi tiết.
- **8.4** `SETUP_CREDENTIALS.md` phần Google Sign-In cho Flutter: Client ID, web, Android (SHA-1), macOS, Windows (D7).
- Ngoài bước ghi trong PLAN nhưng thuộc FR-6: đăng xuất, **xoá tài khoản** (FR-6.4 — backend có `DELETE /api/v1/me` từ giai đoạn 3, app chưa có nút).

Backend đã đủ (giai đoạn 3–4): `POST /api/v1/auth/google`, `DELETE /api/v1/me`, `GET /api/v1/plans/history`, `/:id`; `generate-plan` có token → lưu; đổi món/bài/feedback có token → cập nhật plan đã lưu, feedback ngày 3 → lưu mới.

## 2. Ngữ cảnh đã nạp

- **Wiki:** `INDEX.md`, `wiki-triggers.md`; khớp từ khoá → [[auth-and-history]] (đăng nhập, JWT, token, Google Sign-In, tài khoản, lịch sử), [[flutter-ui]] (Flutter, màn hình, provider, `ApiClient`, `shared_preferences`), [[reference-materials]] (thư viện, SDK, phiên bản), [[critical-constraints]] (đọc hết — việc này đụng auth, token, dịch vụ ngoài).
- **`docs/SETUP_CREDENTIALS.md` mục 2:** backend nhận Web Client ID; trên Android/iOS app xin ID Token cho Web Client ID qua `serverClientId`, nên backend chỉ cần Web Client ID; `GOOGLE_CLIENT_ID` nhận nhiều giá trị (thêm Client ID khác nếu có token cấp cho nó); app ở trạng thái *Testing* → chỉ **Test users** đăng nhập được.
- **App đã có (giai đoạn 5):** `AuthProvider` (`signIn(idToken)` → `ApiClient.loginWithGoogle()`, lưu `smartfit.access_token` + `smartfit.user.v1`, `signOut()`, `deleteAccount()`, 401 → `onUnauthorized` → đăng xuất); `ApiClient.history()`, `historyPlan(id)` (model `PlanSummary`), `health()` (`HealthStatus.authMode`); fixture `auth_login`, `history`, `error_401`, `error_404`. Tab 3 của `MainShell` là chỗ giữ "Lịch sử kế hoạch — tính năng sắp có".
- **Ràng buộc áp dụng:** #10 (chỉ Google, không mật khẩu), #12 (hồ sơ, dữ liệu sức khoẻ không vào lịch sử), #17 (test không gọi Google thật), #21 (mock chỉ khi phát triển/demo; định danh bằng `sub`), #22 (401/404), #26 (model vòng tròn — `PlanSummary` có sẵn), #27 (CORS có header `Authorization`), #28 (token chỉ lưu trên máy, không log), #29 (quyền mạng), #35 (dữ liệu đang nhập dở lưu tạm), D7 (Android, web, Windows, macOS).

## 3. Phát hiện — kiểm chứng ngày 2026-09-30

| # | Phát hiện | Hệ quả |
|---|---|---|
| P1 | `google_sign_in` mới nhất là **7.2.0** (pub.dev): Android, iOS, macOS, web — **không có Windows/Linux**. API 7.x (đọc mã nguồn): `GoogleSignIn.instance.initialize(clientId:, serverClientId:)`, `authenticate()` (không dùng được trên web), `supportsAuthenticate()`, luồng `authenticationEvents`, `account.authentication.idToken` | Windows cần cách khác hoặc chỉ dùng như khách (D7) |
| P2 | Web: đăng nhập **phải** bằng nút do SDK vẽ — `renderButton()` trong `package:google_sign_in_web/web_only.dart`; file này dùng `dart:js_interop` | Import có điều kiện (`if (dart.library.js_interop)`), không thì Android/macOS/Windows không biên dịch |
| P3 | Thử thêm `google_sign_in: ^7.2.0` vào bản sao app: `flutter build macos --debug` **đạt không cần CocoaPods** (GoogleSignIn kéo qua Swift Package Manager), `flutter build apk --debug`, `flutter build web` đạt. Kéo theo `google_sign_in_android` 7.2.17, `google_sign_in_ios` 6.3.6 (phần macOS), `google_sign_in_web` 1.1.3 | Thêm package không làm hỏng build; Windows kiểm trên CI |
| P4 | macOS chạy thật cần `GIDClientID` + `CFBundleURLTypes` (Client ID loại iOS đảo ngược) trong `macos/Runner/Info.plist` và bật **keychain sharing** trong cả hai file entitlements — thiếu keychain sharing thì SDK ném lỗi keychain lúc đăng nhập. Keychain sharing trên macOS thường đòi ký bằng Apple Developer Team | Không đặt được lúc chạy — cần Client ID thật; chưa kiểm được bản macOS không ký |
| P5 | Windows: cách "nhập mã trên máy khác" (OAuth device flow) cho phép `openid email profile` nhưng **bắt buộc `client_secret`** trong app, và tài liệu Google không nói token có `id_token` (thứ backend cần); cách mở trình duyệt + cổng nội bộ (loopback) phải tự làm PKCE, server HTTP cục bộ, cũng cần client secret loại Desktop | Làm đăng nhập Google riêng cho Windows tốn công và có rủi ro — xem Q3 |
| P6 | `HistoryService.update()` chỉ sửa bản ghi `{ id, user_id }` đã có. Plan tạo lúc **chưa đăng nhập**, sau đó đăng nhập và đổi món/feedback → `update` sửa 0 dòng, không báo lỗi, không cảnh báo — plan đó không bao giờ vào lịch sử | Người dùng tưởng đã lưu. Xem Q4 |
| P7 | `/health` trả `auth_mode` (`mock` / `google`) — app biết backend đang ở chế độ nào mà không cần `--dart-define=AUTH_MODE` như PLAN 8.1 ghi | Chọn nút đăng nhập theo backend thì không lệch được (APK build giả lập mà backend thật, hoặc ngược lại). Mâu thuẫn với chữ của PLAN 8.1 — xem Q1 |
| P8 | Nhóm chưa có OAuth Client ID thật (SETUP mục 2.2 có hướng dẫn tạo, chưa ai làm): luồng Google không kiểm được từ đầu tới cuối; luồng giả lập kiểm trọn vẹn (backend mặc định `AUTH_MODE=mock`) | Code Google phải bọc sau một lớp giao diện để test bằng bản giả (#17); kiểm thật khi có Client ID — xem Q2 |
| P9 | App hiện mở thẳng Onboarding khi chưa có plan — không có màn hình chào (FR-6.1) | Thêm màn chào lần đầu: "Đăng nhập với Google" / "Đăng nhập demo" và "Dùng ngay, không cần đăng nhập" |
| P10 | Lịch sử lưu đúng response (`plan_json`), **không** có hồ sơ (#12). "Dùng lại" một plan cũ làm plan hiện tại thì đổi món/feedback cần hồ sơ đã tạo ra nó → dễ 409 | Chi tiết plan cũ chỉ để xem (FR-7.2 "xem lại") |
| P11 | 401 hiện chỉ đăng xuất âm thầm: `generate-plan` lỗi "Phiên đăng nhập đã hết hạn", bấm "Thử lại" thì tạo như khách, không lưu | Lỗi 401 kèm nút "Đăng nhập lại" (màn chờ, SnackBar đổi món/bài, bảng feedback, tab Lịch sử) |

## 4. Các hướng tiếp cận

### Hướng A — Chế độ theo backend (`/health`), một lớp `GoogleAuth` cho từng nền tảng *(khuyến nghị)*

- Màn đăng nhập (chào lần đầu, và mở lại từ tab Cá nhân / Lịch sử) gọi `ApiClient.health()`: `auth_mode = mock` → ô email + "Đăng nhập demo" (gửi `mock:<email>`) trên **mọi** nền tảng, kể cả Windows; `google` → nút Google.
- `lib/services/google_auth.dart` — lớp trừu tượng `GoogleAuth { bool get available; Future<String?> signIn(); Widget? webButton(); Future<void> signOut(); }`, bản thật dùng `google_sign_in` 7.2 (Android/macOS: `authenticate()`; web: `renderButton()` qua import có điều kiện + nghe `authenticationEvents`), bản không hỗ trợ (Windows) `available = false`. Client ID qua `--dart-define=GOOGLE_WEB_CLIENT_ID` (web: `clientId`; Android: `serverClientId`); macOS đọc `GIDClientID` trong `Info.plist`. Test dùng bản giả (#17).
- Tab "Lịch sử": chưa đăng nhập → lời mời đăng nhập; đã đăng nhập → danh sách (ngày tạo giờ máy, calo mục tiêu, "Đang dùng" nếu trùng `plan_id` hiện tại), kéo để tải lại, bấm → màn chi tiết chỉ xem (dùng lại thành phần của Dashboard, không nút đổi món/bài/feedback).
- Tab Cá nhân: mục "Tài khoản" — email/tên, "Đăng xuất", "Xoá tài khoản" (hộp xác nhận, nói rõ xoá cả lịch sử, plan trên máy vẫn giữ — FR-6.4).
- 401 ở mọi chỗ → câu "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại".

**+** Không lệch cấu hình app/backend; demo giả lập chạy mọi nền tảng; Google cô lập, test được bằng bản giả. **−** Mở màn đăng nhập cần gọi `/health` (đăng nhập vốn cần mạng); lệch chữ PLAN 8.1.

### Hướng B — Như A nhưng chọn chế độ bằng `--dart-define=AUTH_MODE` (đúng chữ PLAN 8.1)

**+** Không gọi `/health`. **−** Build nhầm chế độ là đăng nhập hỏng mà người dùng không hiểu vì sao; mỗi chế độ một bản build.

### Hướng C — Chỉ "Đăng nhập demo" + lịch sử, để Google Sign-In tới khi có Client ID

**+** Nhanh, kiểm trọn vẹn. **−** Chưa đạt FR-6.1 (nút Google); việc cấu hình từng nền tảng dồn về sau.

### Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| #10 chỉ Google, không mật khẩu | ✓ (demo chỉ khi backend mock) | ✓ | ✓ |
| #17 test không gọi Google | ✓ `GoogleAuth` giả | ✓ | ✓ |
| #21 mock chỉ khi phát triển/demo | ✓ theo backend | ⚠ app build mock gọi backend thật → 401 | ✓ |
| #28 token chỉ trên máy, không log | ✓ | ✓ | ✓ |
| D7 Windows | ✓ demo được; Google → khách | như A | ✓ |
| FR-6.1 | ✓ | ✓ | ✗ |

## 5. Thiết kế đề xuất (hướng A)

### 5.1 Đăng nhập

- **Màn chào** (lần đầu mở app, chưa có plan, chưa đăng nhập, chưa bấm bỏ qua): tên app, một câu lợi ích ("Đăng nhập để xem lại các kế hoạch cũ trên mọi thiết bị"), nút đăng nhập theo chế độ, "Dùng ngay, không cần đăng nhập" → Onboarding. Nhớ lựa chọn bỏ qua bằng một khoá nhỏ trên máy, để không hiện lại mỗi lần mở.
- **Đăng nhập demo:** ô email (kiểm dạng), gửi `mock:<email>`; ghi rõ "Chế độ demo — không cần tài khoản Google". Email đang gõ lưu tạm theo #35.
- **Google:** Android/macOS → `authenticate()` → `idToken` → `AuthProvider.signIn()`; web → nút GIS; người dùng huỷ → không báo lỗi; Google lỗi / backend 401 → câu tiếng Việt. Windows + backend `google` → "Đăng nhập Google chưa hỗ trợ trên Windows — bạn vẫn dùng đầy đủ tính năng, trừ lịch sử" (Q3).
- **Đăng xuất:** `AuthProvider.signOut()` + `GoogleAuth.signOut()`; plan trên máy giữ nguyên.

### 5.2 Lịch sử

- `HistoryProvider` (hoặc hàm trong `AuthProvider`): tải danh sách khi mở tab / kéo xuống; không lưu xuống máy (dữ liệu nằm ở server — FR-7.3).
- Danh sách: "Thứ Tư, 30/9 · 14:05", "1.624 kcal/ngày", nhãn "Đang dùng".
- Chi tiết: `GET /:id` → màn chỉ xem 3 ngày (món, macro, buổi tập), tiêu đề "Kế hoạch ngày …". 404 (plan đã xoá, tài khoản khác) → câu tiếng Việt, tải lại danh sách.
- Plan đang dùng chưa có trong lịch sử (P6) → Q4.

### 5.3 Tài khoản (tab Cá nhân)

Đã đăng nhập: email, tên, "Đăng xuất", "Xoá tài khoản" (xác nhận hai bước: hộp thoại nêu hậu quả). Chưa: "Đăng nhập để lưu lịch sử kế hoạch".

### 5.4 401

`UnauthorizedException` (đã có) + nút "Đăng nhập lại" ở màn chờ, SnackBar đổi món/bài, bảng feedback, tab Lịch sử. Không tự gọi lại như khách (#22, [[flutter-ui]]).

### 5.5 Tài liệu (8.4)

`SETUP_CREDENTIALS.md` mục 2.x "Google Sign-In trong app": tạo Web Client ID (đã có ở 2.2), Android client (package `com.example.my_ai_app`, SHA-1 của khoá debug/release — lệnh `keytool` / `./gradlew signingReport`), iOS-type client cho macOS (bundle id `com.example.myAiApp`, `GIDClientID`, URL scheme, keychain sharing, ký app), thẻ meta / `--dart-define` cho web + "Authorized JavaScript origins", Windows (Q3), lỗi thường gặp.

### 5.6 Test

- `GoogleAuth` giả; `FakeBackend` đã có đường dẫn auth/history.
- Widget: màn chào (mock → ô email; google → nút Google; Windows giả lập → thông báo), đăng nhập demo, tab Lịch sử (chưa đăng nhập / danh sách / chi tiết / 404 / 401), tài khoản (đăng xuất, xoá — xác nhận), 401 → "Đăng nhập lại".
- Integration trên máy ảo Android và macOS: đăng nhập demo → tạo plan → Lịch sử có plan → chi tiết.
- Google thật: kiểm tay khi có Client ID (Q2).

## 6. Edge case

| Tình huống | Xử lý |
|---|---|
| Không mạng khi mở màn đăng nhập | `/health` lỗi → câu mất mạng + "Thử lại"; "Dùng ngay" vẫn bấm được |
| Token hết hạn (7 ngày) giữa chừng | Request đó 401 → đăng xuất, câu + "Đăng nhập lại"; plan trên máy giữ |
| Đăng nhập tài khoản khác trên cùng máy | Plan trên máy thuộc người trước — giữ (plan cục bộ không gắn tài khoản); lịch sử theo tài khoản mới |
| Xoá tài khoản khi đang có plan | Server xoá tài khoản + lịch sử; app đăng xuất, plan trên máy giữ, dùng tiếp như khách (`AuthProvider.deleteAccount()` đã làm vậy) |
| Plan tạo lúc chưa đăng nhập (P6) | Q4 |
| Người dùng huỷ hộp chọn tài khoản Google | Không báo lỗi, ở lại màn đăng nhập |
| Backend đổi chế độ mock ↔ google khi app đang đăng nhập | Token cũ vẫn hợp lệ (JWT không gắn chế độ) tới khi hết hạn; tài khoản mock và Google là hai người dùng khác nhau (SETUP 2.6) |
| Web: Client ID chưa đặt | Nút Google không hiện; câu "chưa cấu hình Google Sign-In" |
| macOS chưa có `GIDClientID` / keychain sharing | Nút Google báo lỗi cấu hình (P4) — SETUP ghi cách sửa |

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

- **Q1 — App chọn cách đăng nhập theo gì:** (a) theo `/health` của backend (`mock` → "Đăng nhập demo", `google` → nút Google) *(khuyến nghị — P7)*; (b) `--dart-define=AUTH_MODE` lúc build như PLAN 8.1 ghi.
- **Q2 — Google Sign-In thật:** (a) viết đủ code + cấu hình qua `--dart-define`/`Info.plist`, test bằng bản giả, kiểm thật khi nhóm tạo Client ID (hướng dẫn trong SETUP) *(khuyến nghị)*; (b) tạo Client ID ngay trong giai đoạn này để kiểm thật (cần tài khoản Google Cloud của nhóm); (c) chỉ "Đăng nhập demo", để Google sau.
- **Q3 — Windows khi backend dùng Google:** (a) dùng như khách, ghi rõ "chưa hỗ trợ đăng nhập Google trên Windows"; đăng nhập demo vẫn có khi backend giả lập *(khuyến nghị — P5)*; (b) tự làm đăng nhập qua trình duyệt (loopback + PKCE, cần client secret loại Desktop); (c) ẩn hẳn mọi thứ về đăng nhập trên Windows.
- **Q4 — Plan tạo lúc chưa đăng nhập (P6):** (a) tab Lịch sử ghi "Kế hoạch đang dùng được tạo khi chưa đăng nhập nên chưa có trong lịch sử — tạo kế hoạch mới để lưu" *(khuyến nghị — không đổi hợp đồng)*; (b) backend: lần đổi món/bài/feedback đầu tiên sau khi đăng nhập thì lưu plan đó vào lịch sử (cập nhật 0 dòng → thêm mới); (c) endpoint mới lưu plan hiện tại ngay khi đăng nhập (đổi BRD 6.3).

## 8. Quyết định (2026-09-30)

| # | Quyết định |
|---|---|
| Q1 | App chọn cách đăng nhập theo `/health` của backend: `mock` → "Đăng nhập demo" (ô email, gửi `mock:<email>`) trên mọi nền tảng; `google` → nút Google. Thay cho `--dart-define=AUTH_MODE` của PLAN 8.1 (PLAN sửa theo) |
| Q2 | Viết đủ code Google Sign-In (Android, web, macOS) sau lớp `GoogleAuth`, cấu hình qua `--dart-define` / `Info.plist`, test bằng bản giả; hướng dẫn tạo Client ID trong `SETUP_CREDENTIALS.md`; kiểm thật khi nhóm có Client ID |
| Q3 | Windows + backend `google`: dùng như khách, ghi rõ "chưa hỗ trợ đăng nhập Google trên Windows"; backend giả lập thì đăng nhập demo vẫn có |
| Q4 | Plan tạo lúc chưa đăng nhập: tab Lịch sử ghi chú "chưa có trong lịch sử — tạo kế hoạch mới để lưu"; không đổi backend |

## 9. Bổ sung sau khi rà chế độ khách (2026-09-30)

Rà lại "Dùng ngay" (dùng như khách) với người dùng; kiểm trong code:

| # | Phát hiện | Quyết định |
|---|---|---|
| P12 | Khách chỉ có dữ liệu trên máy; "Tạo kế hoạch mới" (`PlanProvider.generate()`) thay plan cũ mà không hỏi, khách không có lịch sử để xem lại | Q5: khách bấm tạo kế hoạch mới khi đang có plan → hỏi lại "Kế hoạch hiện tại sẽ bị thay và không xem lại được" (đã đăng nhập thì không hỏi — plan cũ nằm trong lịch sử) |
| P13 | Không có dấu hiệu nào cho biết đang dùng như khách | Q6: dải nhắc ở tab Cá nhân và tab Lịch sử: "Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này" + nút đăng nhập |
| P14 | `android/app/src/main/AndroidManifest.xml` không khai báo `allowBackup` → mặc định Android bật Auto Backup: `shared_preferences` (hồ sơ có dữ liệu sức khoẻ, JWT) có thể được sao lưu lên Google Drive và khôi phục sang máy khác | Q7: loại khỏi sao lưu tự động (`dataExtractionRules` cho Android 12+, `fullBackupContent` cho bản cũ hơn) — dữ liệu sức khoẻ và token không rời máy ngoài ý muốn (NFR-7) |
| P15 | `generate-plan` không cần đăng nhập (BRD) và backend không giới hạn tần suất → ai biết địa chỉ backend cũng tiêu hết 20 lượt Gemini/ngày, mọi người nhận thực đơn mẫu | Để giai đoạn 9 (deploy): giới hạn tần suất theo IP — ghi vào PLAN |

**Bước tiếp theo:** `/feature-plan phase-8-auth-history`.
