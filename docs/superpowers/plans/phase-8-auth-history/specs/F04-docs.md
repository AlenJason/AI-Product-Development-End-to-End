# F04 — Tài liệu: SETUP mục 3, BRD v2.8.0, PLAN, wiki #37

## Feature

- **`docs/SETUP_CREDENTIALS.md` mục 3 — Google Sign-In trong app Flutter (PLAN 8.4):** app chọn cách đăng nhập theo `/health`; một giá trị lúc build `--dart-define=GOOGLE_WEB_CLIENT_ID`; web (Authorized JavaScript origins có cổng, cổng cố định, nút của Google); Android (SHA-1 bằng `keytool` / `./gradlew signingReport`, Android client với package `com.example.my_ai_app`, máy ảo có Google Play); macOS (Client ID loại iOS với bundle `com.example.myAiApp`, `GIDClientID`, URL scheme, keychain sharing cần Team — không commit vì CI build không ký, thêm Client ID iOS vào `GOOGLE_CLIENT_ID`); Windows (Q3); kiểm tra; bảng lỗi. Bảng đầu file và mục 2.2, 2.4 trỏ sang mục 3.
- **BRD v2.8.0:** FR-6.1 phần app (màn chào, cách đăng nhập theo `/health`, Windows dùng như khách, đăng xuất); FR-6.4 phần app (hỏi lại khi xoá); FR-6.5 mới (dải nhắc khách, hỏi lại khi khách thay kế hoạch, 401 → "Đăng nhập lại"); FR-7.2 chi tiết hoá (giờ máy, "Đang dùng", chỉ xem, plan lúc chưa đăng nhập không vào lịch sử); NFR-7 (Android không sao lưu); mục 4 (`google_sign_in` 7.x không có Windows).
- **PLAN:** tích 8.1–8.4, 8.1 sửa theo Q1 (thay `--dart-define=AUTH_MODE`), dòng "Chi tiết"; "Hiện trạng"; 9.4 thêm đăng nhập Google thật; 9.7 mới — giới hạn tần suất (P15).
- **Wiki:** ràng buộc #37; [[auth-and-history]] mục "Phía app" + hành vi `google_sign_in` 7.2.0, bỏ ghi chú CORS đã cũ; [[flutter-ui]] (cấu trúc, màn hình, khoá lưu, sao lưu Android, khôi phục, 174 test, integration test); [[reference-materials]]; INDEX; wiki-triggers; log. `CLAUDE.md`, README (cách đăng nhập, changelog).

## Scope

Docs-only: `BRD.md`, `CLAUDE.md`, `README.md`, `docs/PLAN.md`, `docs/SETUP_CREDENTIALS.md`, `docs/knowledge/wiki/critical-constraints.md`, `flutter-ui.md`, `auth-and-history.md`, `reference-materials.md`, `wiki-triggers.md`, `INDEX.md`, `log.md`

## Implementation

### API Routes

Không có.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- BRD "Approved": thêm yêu cầu (FR-6.5, NFR-7 Android) → nâng **v2.8.0**, ghi "bổ sung bản 2.8.0" ở từng chỗ.
- Wiki: tên file tiếng Anh, nội dung tiếng Việt; `log.md` chỉ thêm.
- Không ghi Client ID, khoá hay token thật vào tài liệu — chỉ giá trị mẫu (`1234567890-abc…`).

## Definition of Done

- [ ] `grep -c '^| 37 |' docs/knowledge/wiki/critical-constraints.md` → `1`
- [ ] `grep -c '^- \[x\] \*\*8\.[1-4]\*\*' docs/PLAN.md` → `4`
- [ ] `grep -c '^\*\*Phiên bản:\*\* 2.8.0' BRD.md` → `1`
- [ ] `grep -c '^## 3. Google Sign-In trong app Flutter' docs/SETUP_CREDENTIALS.md` → `1`

## Test Checklist

1. **@docs**: bốn lệnh ở DoD
2. **@links**: mục 3 SETUP được trỏ từ bảng đầu file, mục 2.2, 2.4, PLAN 8.4, 9.4, `CLAUDE.md`, README
3. **@auth**, **@timeout**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — `SETUP_CREDENTIALS.md`

````diff
--- a/docs/SETUP_CREDENTIALS.md
+++ b/docs/SETUP_CREDENTIALS.md
@@ -6,7 +6,7 @@
 |---|---|---|
 | Gemini API | Đã có | [Mục 1](#1-gemini-api-key) |
 | Google Sign-In — backend | Đã có | [Mục 2](#2-google-sign-in) |
-| Google Sign-In — Flutter | Chưa làm ([PLAN.md](PLAN.md) bước 8.4) | [Mục 2](#2-google-sign-in) |
+| Google Sign-In — Flutter | Đã có (giai đoạn 8); bản web đã thử với Client ID thật (2026-10-01), Android và macOS chưa | [Mục 3](#3-google-sign-in-trong-app-flutter) |
 
 ---
 
@@ -133,7 +133,7 @@
 
 Client ID không phải bí mật (nó nằm sẵn trong app). **Client secret** thì là bí mật — backend không cần nó, đừng copy vào `.env` hay vào app.
 
-Cấu hình phía Flutter (Client ID cho Android/iOS, SHA-1, thẻ meta cho bản web) làm ở [PLAN.md](PLAN.md) bước 8.4. Trên Android/iOS, app thường xin ID Token cho Web Client ID (tham số `serverClientId`), nên backend chỉ cần Web Client ID.
+Cấu hình phía Flutter (Web Client ID lúc build, SHA-1 cho Android, Client ID cho macOS, nguồn được phép cho bản web): [mục 3](#3-google-sign-in-trong-app-flutter). Trên Android và macOS, app xin ID Token cho Web Client ID (tham số `serverClientId`), nên backend chủ yếu cần Web Client ID.
 
 ### 2.3. Điền vào backend
 
@@ -165,7 +165,7 @@
 
 1. `http://localhost:3000/health` phải có `"auth_mode":"google"`.
 2. Gửi `POST /api/v1/auth/google` với `{"id_token": "abc"}` → 401, và terminal backend có dòng `Từ chối Google ID Token: Wrong number of segments in token`. Nghĩa là backend đang xác minh bằng Google và không còn nhận `mock:`.
-3. Kiểm tra trọn vẹn (đăng nhập bằng tài khoản Google thật) cần nút đăng nhập trong app Flutter — [PLAN.md](PLAN.md) giai đoạn 8.
+3. Kiểm tra trọn vẹn (đăng nhập bằng tài khoản Google thật) bằng nút đăng nhập trong app — [mục 3.6](#36-kiểm-tra).
 
 ### 2.5. Lỗi thường gặp
 
@@ -188,3 +188,115 @@
 - `JWT_SECRET` bảo vệ giống khoá Gemini (mục 1.8): chỉ nằm trong `.env`, không commit; khi deploy thì khai báo trên trang cấu hình của host.
 - Không commit file DB (`*.sqlite`) — nó chứa email và tên người dùng thật.
 - JWT chỉ chứa id người dùng. Log của backend không ghi token hay email khi từ chối đăng nhập.
+
+---
+
+## 3. Google Sign-In trong app Flutter
+
+Code đã có (giai đoạn 8). Bản web đã thử với Client ID thật ngày 2026-10-01 (mục 3.6); Android và macOS mới kiểm bằng bản giả — ai thử lần đầu, ghi kết quả vào [PLAN.md](PLAN.md) bước 9.4.
+
+### 3.1. App chọn cách đăng nhập thế nào
+
+Khi mở bảng đăng nhập (màn chào lần đầu, tab Cá nhân, tab Lịch sử, nút "Đăng nhập lại"), app gọi `GET /health` và xem `auth_mode`:
+
+| `auth_mode` của backend | App hiện |
+|---|---|
+| `mock` (mặc định) | Ô email + "Đăng nhập demo" — app gửi `mock:<email>`. Chạy trên mọi nền tảng, không cần gì ở mục này |
+| `google` | Nút đăng nhập Google — cần làm các bước dưới cho từng nền tảng |
+
+Mọi nền tảng dùng **một** giá trị lúc build: Web Client ID (mục 2.2, cũng là `GOOGLE_CLIENT_ID` của backend):
+
+```bash
+flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=1234567890-abc123def456.apps.googleusercontent.com
+```
+
+Web dùng nó làm `clientId`; Android và macOS dùng làm `serverClientId`, để ID Token được cấp cho đúng Client ID mà backend kiểm. Thiếu giá trị này, app ghi "Bản app này chưa được cấu hình đăng nhập Google" và vẫn dùng được như khách. Client ID không phải bí mật, nhưng mỗi nhóm có một cái riêng nên không ghi cứng vào repo.
+
+### 3.2. Web
+
+1. Ở Web Client ID (mục 2.2), mục **Authorized JavaScript origins** phải có đúng địa chỉ trang, gồm cả cổng: `http://localhost:5050` khi phát triển, `https://<địa chỉ bản web>` khi deploy.
+2. Chạy ở cổng cố định rồi mở `http://localhost:5050` bằng Chrome thường (đã đăng nhập Google):
+
+   ```bash
+   flutter run -d web-server --web-port 5050 --dart-define=GOOGLE_WEB_CLIENT_ID=<Web Client ID>
+   ```
+
+   - Không dùng cổng 5000 trên macOS: AirPlay Receiver nghe sẵn cổng này, `localhost:5000` trả trang 403 của AirTunes (gặp 2026-10-01). Muốn dùng 5000 thì tắt **System Settings → General → AirDrop & Handoff → AirPlay Receiver**.
+   - `flutter run -d chrome` mở một Chrome riêng ở chế độ điều khiển tự động, chưa đăng nhập; Google có thể chặn đăng nhập trong trình duyệt đó.
+
+3. Web không dùng được nút tự vẽ: Google bắt buộc nút của Google Identity Services, app hiện nút đó trong bảng đăng nhập (`renderButton()` của `google_sign_in_web`).
+4. Bản web deploy cần thêm `CORS_ORIGINS` ở backend (mục 2.3).
+
+### 3.3. Android
+
+1. Lấy SHA-1 của khoá ký app. Bản debug và bản release hiện ký cùng khoá debug (`android/app/build.gradle.kts`):
+
+   ```bash
+   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
+   # hoặc
+   cd frontend_app/android && ./gradlew signingReport
+   ```
+
+   Mỗi máy dev có khoá debug riêng, nên mỗi máy một SHA-1. Khi có khoá release riêng, thêm SHA-1 của nó.
+2. Trang **Clients** → **Create client** → **Android**: package name `com.example.my_ai_app`, dán SHA-1. Tạo một Android client cho mỗi SHA-1.
+3. Không dán Android Client ID vào app: Google nhận ra app qua package + SHA-1. App chỉ cần Web Client ID (mục 3.1).
+4. Máy ảo phải là bản có Google Play (Device Manager → cột Play Store) và đã thêm một tài khoản Google trong Settings.
+
+### 3.4. macOS
+
+1. Trang **Clients** → **Create client** → **iOS** (macOS dùng loại này): Bundle ID `com.example.myAiApp` (`macos/Runner/Configs/AppInfo.xcconfig`). Copy Client ID và **iOS URL scheme** (Client ID đảo ngược, dạng `com.googleusercontent.apps.1234567890-xyz`).
+2. Thêm vào `macos/Runner/Info.plist`:
+
+   ```xml
+   <key>GIDClientID</key>
+   <string>1234567890-xyz.apps.googleusercontent.com</string>
+   <key>CFBundleURLTypes</key>
+   <array>
+     <dict>
+       <key>CFBundleURLSchemes</key>
+       <array>
+         <string>com.googleusercontent.apps.1234567890-xyz</string>
+       </array>
+     </dict>
+   </array>
+   ```
+
+3. Bật keychain sharing — thêm vào **cả** `macos/Runner/DebugProfile.entitlements` và `Release.entitlements`:
+
+   ```xml
+   <key>keychain-access-groups</key>
+   <array>
+     <string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
+   </array>
+   ```
+
+   Entitlement này bắt buộc ký app bằng Apple Developer Team: mở `macos/Runner.xcworkspace` → Runner → **Signing & Capabilities** → chọn Team. Không có Team thì `flutter build macos` dừng với lỗi `"Runner" has entitlements that require signing with a development certificate` (đã thử 2026-10-01). Vì vậy repo **không** chứa các dòng ở bước 2–3: CI build bản macOS không ký.
+4. Thêm Client ID loại iOS vào `GOOGLE_CLIENT_ID` của backend (cách nhau dấu phẩy, cạnh Web Client ID) — phòng khi ID Token được cấp cho Client ID này.
+5. Chạy: `flutter run -d macos --dart-define=GOOGLE_WEB_CLIENT_ID=<Web Client ID>`.
+
+### 3.5. Windows
+
+`google_sign_in` không có bản Windows. Khi backend dùng Google, app trên Windows ghi "Đăng nhập Google chưa hỗ trợ trên Windows" và chạy như khách (đủ tính năng trừ lịch sử). Khi backend giả lập, "Đăng nhập demo" vẫn có. Người dùng Windows muốn có lịch sử thì mở bản web trên trình duyệt. Đăng nhập Google riêng cho Windows cần tự làm luồng trình duyệt + PKCE và client secret loại Desktop — chưa làm (brainstorm giai đoạn 8, P5).
+
+### 3.6. Kiểm tra
+
+1. Backend: `http://localhost:3000/health` có `"auth_mode":"google"` (mục 2.4).
+2. App: tab Cá nhân → "Đăng nhập" → thấy nút Google (không phải ô email).
+3. Đăng nhập → tab Cá nhân hiện tên, email; tạo kế hoạch → tab Lịch sử có kế hoạch đó, nhãn "Đang dùng".
+4. Đăng nhập cùng tài khoản trên nền tảng khác → thấy cùng lịch sử (FR-7.3).
+
+Đã thử 2026-10-01 — bản web trên Chrome (macOS), backend `AUTH_MODE=google` với Web Client ID thật, app ở trạng thái *Testing*: nút "Đăng nhập bằng Google" hiện ở màn chào → hộp chọn tài khoản → màn đồng ý chỉ xin tên, ảnh hồ sơ, email → app vào Onboarding; backend tạo tài khoản với `google_sub` của Google (không phải `mock:`), tên và email lấy từ Google; tạo kế hoạch → tab Lịch sử có kế hoạch đó, nhãn "Đang dùng", xem lại được; đổi món → kế hoạch lưu trên server đổi theo; "Xoá tài khoản" → server không còn tài khoản và lịch sử, app về khách.
+
+### 3.7. Lỗi thường gặp
+
+| App báo | Nguyên nhân thường gặp | Cách xử lý |
+|---|---|---|
+| "Bản app này chưa được cấu hình đăng nhập Google" | Build thiếu `--dart-define=GOOGLE_WEB_CLIENT_ID` | Build lại với giá trị đó (mục 3.1) |
+| Web trên macOS: `localhost:5000` ra trang 403 (máy chủ "AirTunes"), không phải app | AirPlay Receiver chiếm cổng 5000 | Dùng cổng khác (mục 3.2) và thêm origin của cổng đó |
+| Android: "Đăng nhập Google chưa được cấu hình đúng…" | Package name hoặc SHA-1 của Android client không khớp bản đang chạy; Web Client ID sai | Kiểm lại mục 3.3 — mỗi máy dev một SHA-1 |
+| Android: không hiện hộp chọn tài khoản | Máy ảo không có Google Play, chưa có tài khoản Google | Mục 3.3 bước 4 |
+| Web: nút Google không hiện, hoặc cửa sổ Google báo `origin_mismatch` | Địa chỉ trang (cả cổng) chưa có trong Authorized JavaScript origins | Mục 3.2 |
+| macOS: "Đăng nhập Google chưa được cấu hình đúng…" | Thiếu `GIDClientID`, URL scheme, hoặc keychain sharing | Mục 3.4 |
+| "Máy chủ không chấp nhận lần đăng nhập này" | Backend trả 401: token cấp cho Client ID khác `GOOGLE_CLIENT_ID`, tài khoản chưa xác minh email | Xem dòng log của backend (mục 2.5) |
+| Tài khoản cụ thể không đăng nhập được | App ở trạng thái *Testing*, tài khoản chưa có trong **Test users** | Mục 2.2 bước 5 |
+| "Đăng nhập Google chưa hỗ trợ trên Windows" | Đúng như thiết kế | Mục 3.5 |
````

### Task 2 — BRD, PLAN

```diff
--- a/BRD.md
+++ b/BRD.md
@@ -3,8 +3,8 @@
 **Tên sản phẩm:** Trợ lý AI Gợi ý & Điều chỉnh Thực đơn, Lịch tập Thông minh  
 **Môn học:** AI Product Development End-to-End (Đồ án Kỹ sư / Cử nhân Năm 4)  
 **Đơn vị thực hiện:** Trường Đại học Công nghệ Thông tin và Truyền thông Việt - Hàn (VKU)  
-**Phiên bản:** 2.7.1 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
-**Ngày cập nhật:** 30/09/2026  
+**Phiên bản:** 2.8.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
+**Ngày cập nhật:** 01/10/2026  
 **Trạng thái:** Đã phê duyệt (Approved)  
 
 ---
@@ -96,7 +96,7 @@
   * Thư viện mạng: Gói `http` cơ bản (dễ học hơn `dio` cho người mới).
   * State Management: `setState` hoặc `ChangeNotifier` / `Provider` (dễ hiểu, không cần học Bloc quá phức tạp lúc đầu).
   * Lưu trữ cục bộ: `shared_preferences` để lưu lại kế hoạch JSON và `access_token`, mở app lại không bị mất dữ liệu và giảm số lần gọi AI.
-  * Đăng nhập: `google_sign_in` — lấy ID Token từ Google, gửi lên backend đổi lấy JWT riêng của app (FR-6).
+  * Đăng nhập: `google_sign_in` — lấy ID Token từ Google, gửi lên backend đổi lấy JWT riêng của app (FR-6). Bản 7.x chạy trên Android, macOS, web; không có bản Windows. *(bổ sung bản 2.8.0)*
 * **Backend (NestJS - TypeScript):**
   * Kiến trúc module/controller/service rõ ràng (giống Angular), cùng ngôn ngữ TypeScript với phần nhiều tooling frontend, dễ định nghĩa DTO/validate dữ liệu bằng `class-validator` + `class-transformer`.
   * Dùng `@nestjs/swagger` để tự sinh tài liệu kiểm thử **Swagger UI** tại `http://localhost:3000/docs` giúp sinh viên test API ngay trên trình duyệt trước khi viết code Flutter.
@@ -166,13 +166,15 @@
 
 #### FR-6: Đăng nhập bằng Google (Google Sign-In)
 * **FR-6.1:** Màn hình chào mở app có nút "Đăng nhập với Google"; dùng package `google_sign_in` phía Flutter.
+* **FR-6.1 — trên app** *(bổ sung bản 2.8.0)*: Màn chào chỉ hiện ở lần đầu mở app, có thêm nút "Dùng ngay, không cần đăng nhập" (FR-7: đăng nhập là tuỳ chọn); đăng nhập sau được ở tab Cá nhân và tab Lịch sử. App hỏi backend cách đăng nhập (`GET /health` → `auth_mode`), không chọn lúc build: backend giả lập → ô email "Đăng nhập demo" (gửi `mock:<email>`, mọi nền tảng); backend dùng Google → nút "Đăng nhập với Google" (Android, macOS; bản web dùng nút do Google vẽ). Windows chưa đăng nhập Google được (`google_sign_in` không có bản Windows): app ghi rõ, người dùng dùng như khách. Tab Cá nhân có tên, email và "Đăng xuất"; đăng xuất không xoá kế hoạch trên máy.
 * **FR-6.2:** Backend nhận ID Token từ Flutter, verify với Google, tự tạo tài khoản mới nếu `google_sub` chưa tồn tại (không cần màn hình đăng ký riêng).
 * **FR-6.3:** Backend phát hành JWT riêng của app sau khi xác thực thành công; Flutter lưu JWT này (không lưu ID Token Google) để gọi các API cần đăng nhập ở các lần sau.
-* **FR-6.4** *(bổ sung bản 2.4.0)*: Người dùng tự xoá được tài khoản của mình: backend xoá tài khoản cùng toàn bộ lịch sử kế hoạch (`DELETE /api/v1/me`). Đây là quyền yêu cầu xoá dữ liệu cá nhân theo Nghị định 13/2023/NĐ-CP.
+* **FR-6.4** *(bổ sung bản 2.4.0)*: Người dùng tự xoá được tài khoản của mình: backend xoá tài khoản cùng toàn bộ lịch sử kế hoạch (`DELETE /api/v1/me`). Đây là quyền yêu cầu xoá dữ liệu cá nhân theo Nghị định 13/2023/NĐ-CP. Trên app: nút "Xoá tài khoản" ở tab Cá nhân, hỏi lại trước khi xoá và nói rõ lịch sử trên máy chủ mất hẳn, kế hoạch trên máy vẫn giữ. *(bổ sung bản 2.8.0)*
+* **FR-6.5 — dùng như khách, phiên hết hạn** *(bổ sung bản 2.8.0)*: Chưa đăng nhập thì tab Cá nhân và tab Lịch sử có dải nhắc "kế hoạch chỉ lưu trên máy này". Khách tạo kế hoạch mới khi đang có kế hoạch → app hỏi lại, vì kế hoạch cũ mất hẳn. Server trả 401 (token hết hạn, tài khoản đã xoá) → app báo "Phiên đăng nhập đã hết hạn" kèm nút "Đăng nhập lại", không âm thầm chuyển thành khách; tạo kế hoạch bị 401 thì đăng nhập lại xong app tạo tiếp để kế hoạch vào lịch sử.
 
 #### FR-7: Lịch sử kế hoạch (Plan History)
 * **FR-7.1:** Mỗi lần `/api/v1/generate-plan` thành công **và** request có kèm JWT hợp lệ, Backend lưu lại plan đó vào bảng lịch sử, gắn với `user_id`. Khi đã đăng nhập, đổi món, đổi bài tập và feedback cũng cập nhật plan đã lưu; plan mới tạo từ feedback ngày 3 được lưu thành một mục mới. *(bổ sung bản 2.5.0)*
-* **FR-7.2:** Màn hình "Lịch sử" trong Flutter (thay cho placeholder "Thống kê" hiện tại) hiển thị danh sách các plan đã tạo trước đó (ngày tạo, calo mục tiêu), bấm vào xem lại chi tiết từng plan.
+* **FR-7.2:** Màn hình "Lịch sử" trong Flutter (thay cho placeholder "Thống kê" hiện tại) hiển thị danh sách các plan đã tạo trước đó (ngày tạo, calo mục tiêu), bấm vào xem lại chi tiết từng plan. *(chi tiết hoá ở bản 2.8.0)*: ngày giờ tạo theo giờ trên máy; nhãn "Đang dùng" cho kế hoạch hiện tại; chi tiết chỉ để xem — lịch sử không lưu hồ sơ (NFR-7) nên kế hoạch cũ không đổi món, đổi bài hay gửi đánh giá được. Kế hoạch tạo lúc chưa đăng nhập không vào lịch sử, kể cả khi đăng nhập sau đó; tab Lịch sử ghi chú điều này.
 * **FR-7.3:** Đăng nhập cùng tài khoản Google trên thiết bị khác vẫn thấy đầy đủ lịch sử — vì dữ liệu gắn với `user_id` trong DB, không gắn với thiết bị.
 * **Lưu ý:** Nếu gọi `/api/v1/generate-plan` mà không đăng nhập (không có JWT), API vẫn hoạt động bình thường như bản 2.1.0 (không lưu lịch sử) — đăng nhập là tuỳ chọn, không bắt buộc để dùng tính năng cốt lõi.
 
@@ -443,6 +445,7 @@
 7. **Quyền riêng tư dữ liệu sức khoẻ (bổ sung bản 2.3.0):**
    * Dị ứng, chấn thương, tình trạng sức khoẻ và việc mang thai / cho con bú là dữ liệu cá nhân nhạy cảm (Nghị định 13/2023/NĐ-CP). Chúng chỉ lưu trên máy người dùng, gửi kèm từng request rồi bỏ đi: backend không ghi vào database, không ghi log nội dung request hay nội dung Gemini trả về.
    * Plan lưu trong lịch sử (FR-7) không chứa các trường này.
+   * Android không đưa dữ liệu đã lưu của app lên bản sao lưu Google Drive và không chép sang máy mới khi chuyển máy: hồ sơ có dữ liệu sức khoẻ và token đăng nhập chỉ nằm trên máy đã nhập. *(bổ sung bản 2.8.0)*
 8. **Chống prompt injection (bổ sung bản 2.3.0):** Văn bản tự do của người dùng được đặt trong một khối dữ liệu có thẻ phân cách, bỏ ký tự `<` `>` và xuống dòng, giới hạn 300 ký tự mỗi ô; prompt dặn Gemini coi khối này là dữ liệu, không phải chỉ dẫn. Đầu ra vẫn phải qua bộ kiểm tra ở NFR-4, nên dù bị chèn lệnh cũng không làm hỏng app.
 9. **Khuyến cáo y tế (bổ sung bản 2.3.0):** Onboarding ghi rõ gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Khi người dùng có khai tình trạng sức khoẻ, hoặc khi calo mục tiêu phải nâng lên bằng BMR, response có câu giải thích trong `warnings` để app hiển thị.
 10. **An toàn khi lập kế hoạch (bổ sung bản 2.6.0):** Không phục vụ người dưới 18 tuổi; không lập kế hoạch thâm hụt calo cho người thiếu cân (BMI < 18,5) hoặc đang mang thai / cho con bú (FR-1.3); độ khó bài tập giới hạn theo tuổi, mức vận động và thai kỳ (FR-2.2). Backend kiểm ở mọi endpoint nhận hồ sơ, kể cả đổi món, đổi bài, feedback; app khoá lựa chọn theo đúng các ngưỡng đó. Người mang thai / cho con bú nhận thêm khuyến cáo hỏi ý kiến bác sĩ trong `warnings`.
```

```diff
--- a/docs/PLAN.md
+++ b/docs/PLAN.md
@@ -32,7 +32,7 @@
 - [x] BRD v2.6.0 (MVP, tính năng nâng cao, tài khoản & lịch sử, hợp đồng API đầy đủ)
 - [x] Backend: `GET /health`, `POST /api/v1/generate-plan` (tính BMR/TDEE, gọi Gemini, kiểm tra khoảng calo, fallback), đổi món, đổi bài tập, feedback, đăng nhập Google (giả lập mặc định), lịch sử kế hoạch (SQLite), validate DTO, Swagger UI, CORS cho bản web
 - [x] `ai_workspace/`: script thử prompt Gemini
-- [x] Frontend: Onboarding 3 bước, màn chờ, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — đọc/ghi qua provider, không còn dữ liệu viết cứng (giai đoạn 6); feedback cuối ngày (giai đoạn 7). Chưa có: đăng nhập và lịch sử (giai đoạn 8)
+- [x] Frontend: Onboarding 3 bước, màn chờ, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — đọc/ghi qua provider, không còn dữ liệu viết cứng (giai đoạn 6); feedback cuối ngày (giai đoạn 7); màn chào, đăng nhập (demo / Google), tab Lịch sử, đăng xuất, xoá tài khoản (giai đoạn 8). Đăng nhập Google thật đã thử trên bản web với Client ID thật (2026-10-01); Android, macOS chưa
 - [x] Wiki nội bộ `docs/knowledge/`, `CLAUDE.md`
 
 ---
@@ -210,19 +210,22 @@
 
 ## Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7) · M
 
-- [ ] **8.1** Màn đăng nhập, chọn chế độ bằng `--dart-define=AUTH_MODE`: giả lập → nút "Đăng nhập demo"; thật → package `google_sign_in`. Có nút bỏ qua đăng nhập (đăng nhập là tuỳ chọn theo FR-7)
-- [ ] **8.2** Gắn JWT vào request; nhận 401 → yêu cầu đăng nhập lại
-- [ ] **8.3** Đổi tab "Thống kê" thành "Lịch sử": danh sách plan cũ, bấm vào xem chi tiết
-- [ ] **8.4** `SETUP_CREDENTIALS.md` — phần **Google Sign-In (Flutter)**: Client ID, thẻ meta cho bản web, SHA-1 cho Android, cấu hình macOS; cách đăng nhập trên Windows (D7)
+- [x] **8.1** Màn chào lần đầu + bảng đăng nhập. Chọn cách đăng nhập theo `/health` của backend (quyết định Q1 — thay cho `--dart-define=AUTH_MODE` ghi trước đây): giả lập → "Đăng nhập demo"; thật → `google_sign_in` 7.x (Android, macOS, web; Windows dùng như khách — Q3). Có nút bỏ qua đăng nhập (đăng nhập là tuỳ chọn theo FR-7)
+- [x] **8.2** Gắn JWT vào request; nhận 401 → "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại" ở màn chờ, SnackBar đổi món/bài, bảng feedback, tab Lịch sử
+- [x] **8.3** Đổi tab "Thống kê" thành "Lịch sử": danh sách plan cũ, bấm vào xem chi tiết (chỉ xem)
+- [x] **8.4** `SETUP_CREDENTIALS.md` mục 3 — **Google Sign-In trong app**: Web Client ID qua `--dart-define`, nguồn được phép cho bản web, SHA-1 cho Android, cấu hình macOS; Windows (D7)
 
+Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-8-auth-history.md` (quyết định Q1–Q4 ở mục 8, Q5–Q7 ở mục 9), plan `docs/superpowers/plans/phase-8-auth-history/`. Làm thêm ngoài 8.1–8.4: đăng xuất, xoá tài khoản (FR-6.4), hỏi lại khi khách thay kế hoạch (Q5), dải nhắc khách (Q6), loại dữ liệu của app khỏi sao lưu Android (Q7) — BRD v2.8.0. Đăng nhập Google thật đã thử trên bản web với Client ID thật (2026-10-01): đăng nhập, tạo plan, lịch sử, đổi món cập nhật lịch sử, xoá tài khoản; Android, macOS còn chờ (9.4).
+
 ## Giai đoạn 9 — Deploy, nghiệm thu, nộp bài · M
 
 - [ ] **9.1** Chọn nơi deploy: (a) giữ SQLite, dùng host có ổ lưu trữ bền (Railway volume, Fly.io volume, VPS), hoặc (b) chuyển sang Postgres. **Không** dùng Render bản free với SQLite
 - [ ] **9.2** Deploy backend, cấu hình biến môi trường trên host: `NODE_ENV=production`, `AUTH_MODE=google`, `GOOGLE_CLIENT_ID`, `JWT_SECRET`, `DATABASE_PATH` trỏ vào ổ lưu trữ bền, `GEMINI_API_KEY`, `CORS_ORIGINS` (địa chỉ bản web, nếu deploy bản web)
 - [ ] **9.3** Build app để demo: bản web, APK Android, Windows, macOS (D7), với `--dart-define=API_BASE_URL=https://<địa chỉ backend>` — có thể thêm vào job `build` của CI
-- [ ] **9.4** Chạy checklist kiểm thử toàn luồng ở cả hai chế độ (giả lập / khoá thật)
+- [ ] **9.4** Chạy checklist kiểm thử toàn luồng ở cả hai chế độ (giả lập / khoá thật) — gồm đăng nhập Google thật trên Android, macOS (bản web đã thử 2026-10-01; [SETUP_CREDENTIALS.md](SETUP_CREDENTIALS.md) mục 3)
 - [ ] **9.5** Cập nhật README (cách chạy, ảnh chụp màn hình), Changelog, BRD mục 9, wiki
 - [ ] **9.6** Slide báo cáo và video demo
+- [ ] **9.7** Làm trước 9.2: giới hạn tần suất theo IP cho `generate-plan`, đổi món/bài, feedback. Các endpoint này không cần đăng nhập (BRD) và mỗi lần có thể gọi Gemini — ai biết địa chỉ backend cũng tiêu hết 20 lượt/ngày, mọi người nhận thực đơn mẫu (P15 giai đoạn 8)
 
 ---
```

### Task 3 — Wiki

```diff
--- a/docs/knowledge/wiki/critical-constraints.md
+++ b/docs/knowledge/wiki/critical-constraints.md
@@ -1,5 +1,5 @@
 ---
-last_updated: 2026-09-27
+last_updated: 2026-10-01
 ---
 
 # Ràng buộc cứng của dự án
@@ -47,4 +47,6 @@
 | 35 | Dữ liệu người dùng đang nhập dở trong app (Onboarding, sửa hồ sơ, tab đang mở) chỉ lưu tạm bằng state restoration (`MaterialApp.restorationScopeId`, `RestorationMixin`), **không** ghi `shared_preferences`; Back ở màn gốc Android chỉ đưa app xuống nền (`MainActivity.popSystemNavigator()` → `moveTaskToBack`). Kết quả: hệ thống tắt app ở nền → khôi phục; force-quit → mất. Test: `widget_test.dart` (`restartAndRestore()`, và kiểm không có khoá nào được ghi). | PLAN D8. Trước đó Back ở bước 1 gọi `finish()` → mất hết. Ghi xuống máy thì force-quit cũng không xoá được — trái quyết định của người dùng. |
 | 36 | Feedback cuối ngày trên app (BRD FR-5.1 v2.7.1, PLAN giai đoạn 7): ngày được gửi theo `canReviewDay()` (`frontend_app/lib/models/feedback_rules.dart`: hôm nay, hôm qua; ngày 3 cả khi plan đã hết). Ngày đã gửi lưu ở `smartfit.feedback.v1` = `{ plan_id, days }` — **chỉ** số ngày, không lưu câu trả lời (tình trạng cơ thể là dữ liệu sức khoẻ); `PlanProvider` chỉ khoá sau khi server trả plan, xoá khi tạo plan mới hoặc feedback ngày 3 trả plan mới. Câu trả lời đang chọn chỉ lưu tạm (#35). Dấu hiệu nguy hiểm: khuyến cáo hiện ngay trong bảng không chờ server; `safety_warning` chỉ đóng bằng nút "Tôi đã hiểu" (`PopScope`, `enableDrag: false`). Báo kết quả bằng `describeFeedbackChanges()` — không có câu viết sẵn kiểu "AI đã cân đối lại thực đơn". | Backend không lưu trạng thái: gửi lại cùng một ngày điều chỉnh thêm lần nữa (BRD 6.4). Khoá trước khi server trả lời thì lỗi mạng làm người dùng không gửi lại được. Bảng feedback cũ (xoá ở giai đoạn 6) báo "AI đã cân đối lại thực đơn Ngày 2!" dù không có gì thay đổi. |
 
+| 37 | Đăng nhập trên app (BRD FR-6.1, FR-6.5 v2.8.0, PLAN giai đoạn 8): cách đăng nhập lấy từ `/health` (`AuthProvider.loginMode()`: `mock` → "Đăng nhập demo" gửi `mock:<email>` chữ thường, `google` → nút Google), không từ cờ lúc build. Google chỉ đi qua `GoogleAuth` (`frontend_app/lib/services/google_auth.dart`): test dùng `FakeGoogleAuth`, bản thật thử bằng `GoogleSignInPlatform` giả (#17); `GOOGLE_WEB_CLIENT_ID` (`--dart-define`) là `clientId` trên web, `serverClientId` trên Android/macOS; không đưa mô tả lỗi của SDK ra giao diện hay log; người dùng tự huỷ → không báo lỗi. 401 cho request có token → câu "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại" ở mọi chỗ gọi API (màn chờ, đổi món/bài, bảng feedback, lịch sử), không âm thầm thành khách; 401 **lúc đăng nhập** là "máy chủ không chấp nhận", không phải hết hạn. Khách thay kế hoạch đang có → hỏi lại (`MainShell._createPlan()`). Android: `android:dataExtractionRules` + `android:fullBackupContent` (`res/xml/`) loại `sharedpref` khỏi sao lưu và chuyển máy — không bỏ. Không commit Client ID, `GIDClientID`, URL scheme hay keychain sharing của macOS (`docs/SETUP_CREDENTIALS.md` mục 3). | PLAN 8.1 cũ chọn chế độ bằng `--dart-define=AUTH_MODE`: build lệch backend là đăng nhập hỏng mà không rõ vì sao. 401 trước giai đoạn 8 chỉ đăng xuất âm thầm — bấm "Thử lại" là tạo plan như khách, không vào lịch sử. Auto Backup của Android mặc định bật: thử bằng `bmgr` + LocalTransport (2026-10-01), bản cũ đưa `FlutterSharedPreferences.xml` (token, hồ sơ sức khoẻ) vào bản sao lưu, bản mới thì không. Thêm keychain sharing → `flutter build macos` không ký (CI) dừng vì "requires signing with a development certificate". |
+
 _File này được feature-explore và feature-build load khi phát hiện công việc liên quan tới ràng buộc._
```

```diff
--- a/docs/knowledge/wiki/auth-and-history.md
+++ b/docs/knowledge/wiki/auth-and-history.md
@@ -1,11 +1,11 @@
 ---
-last_updated: 2026-09-24
+last_updated: 2026-10-01
 tags: [auth, jwt, google-sign-in, sqlite, typeorm, lich-su]
 ---
 
 # Tài khoản & lịch sử kế hoạch
 
-Backend có đăng nhập Google (FR-6) và lịch sử kế hoạch xem được trên mọi thiết bị (FR-7), xây ở giai đoạn 3. Bài này ghi cách các phần nối với nhau, những hành vi thư viện đã kiểm chứng ngày 2026-09-24, và cách test mà không gọi Google hay đụng file DB thật. Ràng buộc liên quan: [[critical-constraints]] #10–#12, #17–#22. Hợp đồng plan: [[plan-data-contract]]. Hướng dẫn gắn Client ID thật: `docs/SETUP_CREDENTIALS.md` mục 2.
+Backend có đăng nhập Google (FR-6) và lịch sử kế hoạch xem được trên mọi thiết bị (FR-7), xây ở giai đoạn 3. Bài này ghi cách các phần nối với nhau, những hành vi thư viện đã kiểm chứng ngày 2026-09-24, và cách test mà không gọi Google hay đụng file DB thật. Ràng buộc liên quan: [[critical-constraints]] #10–#12, #17–#22. Hợp đồng plan: [[plan-data-contract]]. Hướng dẫn gắn Client ID thật: `docs/SETUP_CREDENTIALS.md` mục 2 (backend), mục 3 (app). Phía app (giai đoạn 8): mục "Phía app" bên dưới và [[flutter-ui]].
 
 ## Thành phần
 
@@ -59,7 +59,33 @@
 - E2E: `createTestApp()` (`backend_api/test/test-app.ts`) ghim `DATABASE_PATH=:memory:`, `AUTH_MODE=mock`, các biến JWT/Google, `GEMINI_*` trước khi nạp `AppModule`, và trả lại khi đóng. `loginMock()` đăng nhập bằng `mock:<email>`.
 - Smoke: `npm run test:smoke` chạy `dist/main.js` và gọi 5 request (#20).
 
+## Phía app (giai đoạn 8, BRD v2.8.0)
+
+- **Cách đăng nhập theo backend:** `AuthProvider.loginMode()` đọc `auth_mode` của `/health` mỗi lần mở bảng đăng nhập — một bản build dùng được cho cả backend giả lập lẫn thật (#37). Demo gửi `mock:<email>` chữ thường (backend coi `sub` phân biệt hoa thường); app kiểm email bằng đúng mẫu `MOCK_TOKEN_PATTERN` của backend.
+- **Google:** `GoogleAuth` (`lib/services/google_auth.dart`) → ID token → `AuthProvider.signIn()` → `POST /api/v1/auth/google`. App không giữ token Google, không xin thêm quyền. Đăng xuất gọi cả `GoogleAuth.signOut()`.
+- **401:** request có token bị 401 → `ApiClient.onUnauthorized` → đăng xuất; màn hình nói rõ và có "Đăng nhập lại". `HistoryProvider` giữ lỗi 401 để tab Lịch sử nói vì sao bị đăng xuất.
+- **Plan tạo lúc chưa đăng nhập:** `HistoryService.update()` chỉ sửa bản ghi `{ id, user_id }` đã có — đổi món/feedback sau khi đăng nhập không đưa plan đó vào lịch sử (P6). Không đổi backend (quyết định Q4); tab Lịch sử ghi chú.
+- **Xoá tài khoản:** tab Cá nhân, hỏi lại; server xoá user + lịch sử (`ON DELETE CASCADE`), app đăng xuất, plan trên máy giữ.
+
+### `google_sign_in` 7.2.0 (đọc mã nguồn, thử build ngày 2026-09-30 → 2026-10-01)
+
+| Hành vi | Hệ quả trong code |
+|---|---|
+| Có bản Android (`google_sign_in_android` 7.2.17), iOS + macOS (`google_sign_in_ios` 6.3.6), web (`google_sign_in_web` 1.1.3); **không có Windows, Linux** — `GoogleSignInPlatform.instance` ở đó ném `UnimplementedError` | `PluginGoogleAuth.support` = `unsupported` trên Windows, không bao giờ gọi SDK |
+| API 7.x: `GoogleSignIn.instance.initialize()` gọi **một lần** trước mọi hàm khác; `authenticate()` (không có trên web — `supportsAuthenticate()` = false); token ở `account.authentication.idToken` | `_init()` nhớ Future khởi tạo, lỗi thì lần sau thử lại |
+| Web: phải dùng nút của Google Identity Services — `renderButton()` trong `package:google_sign_in_web/web_only.dart`, file dùng `dart:js_interop` | Import có điều kiện; `google_sign_in_web` là dependency trực tiếp; token tới qua `authenticationEvents` |
+| Người dùng đóng hộp chọn → `GoogleSignInException` mã `canceled` (hoặc `interrupted`) | Trả `null`, không báo lỗi |
+| macOS thiếu keychain sharing → lỗi `keychainError`, ánh xạ thành `providerConfigurationError` (README ghi là `PlatformException`) | Cả hai thành "chưa được cấu hình đúng" |
+| `description` của lỗi có thể chứa email/Client ID | Không đưa ra giao diện hay log |
+| Thêm gói vào app: `flutter build macos` chạy không cần CocoaPods (GoogleSignIn kéo qua Swift Package Manager); APK, web build được | — |
+| Entitlement `keychain-access-groups` (`$(AppIdentifierPrefix)…`) bắt buộc ký bằng Team | Không commit; SETUP mục 3.4 |
+
+### Đã thử với Google thật (2026-10-01)
+
+Bản web trên Chrome (macOS), backend `AUTH_MODE=google` với Web Client ID thật, app ở trạng thái *Testing*: nút "Đăng nhập bằng Google" hiện ở màn chào → hộp chọn tài khoản → màn đồng ý chỉ xin tên, ảnh hồ sơ, email → app vào Onboarding; backend tạo tài khoản với `google_sub` của Google (không phải `mock:`), tên và email lấy từ Google; tạo kế hoạch → tab Lịch sử có kế hoạch đó, nhãn "Đang dùng", xem lại được; đổi món → kế hoạch lưu trên server đổi theo; "Xoá tài khoản" → server không còn tài khoản và lịch sử, app về khách. Lúc thử: backend chạy với `DATABASE_PATH` riêng trong thư mục tạm, xoá ngay sau đó — email thật không vào `database.sqlite` của repo.
+
 ## Việc để sau
 
-- **CORS** chưa bật: Flutter web chạy ở cổng khác sẽ bị trình duyệt chặn, nhất là khi có header `Authorization` — PLAN 5.7.
+- Kiểm đăng nhập Google thật trên Android, macOS (PLAN 9.4).
+- Giới hạn tần suất các endpoint gọi Gemini mà không cần đăng nhập (PLAN 9.7).
 - **Chuyển sang Postgres** (nếu host không có ổ bền, #11): đổi `type` trong `dataSourceOptions()`. Entity dùng kiểu chung, nhưng migration hiện có biểu thức SQLite (`datetime('now')`), nên cần viết một migration khởi tạo mới cho Postgres.
```

```diff
--- a/docs/knowledge/wiki/flutter-ui.md
+++ b/docs/knowledge/wiki/flutter-ui.md
@@ -1,17 +1,17 @@
 ---
-last_updated: 2026-09-27
-tags: [flutter, frontend, hop-dong-api, cors, onboarding]
+last_updated: 2026-10-01
+tags: [flutter, frontend, hop-dong-api, cors, onboarding, dang-nhap, lich-su]
 ---
 
 # Giao diện Flutter và tầng kết nối API
 
-App Flutter nằm trong `frontend_app/` (package `my_ai_app`, tên hiển thị "SmartFit AI"). Giai đoạn 5 dựng tầng kết nối backend (model theo hợp đồng BRD 6, `ApiClient`, provider lưu trên máy); từ giai đoạn 6 mọi màn hình đọc/ghi qua provider — không còn dữ liệu viết cứng. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#32. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].
+App Flutter nằm trong `frontend_app/` (package `my_ai_app`, tên hiển thị "SmartFit AI"). Giai đoạn 5 dựng tầng kết nối backend (model theo hợp đồng BRD 6, `ApiClient`, provider lưu trên máy); từ giai đoạn 6 mọi màn hình đọc/ghi qua provider — không còn dữ liệu viết cứng. Ràng buộc liên quan: [[critical-constraints]] #12, #15, #22, #24, #26–#32, #35–#37. Hợp đồng phía backend: [[plan-data-contract]], [[swap-and-feedback]], [[auth-and-history]].
 
 ## Cấu trúc `lib/`
 
 | Đường dẫn | Nội dung |
 |---|---|
-| `main.dart` | `main()` bật vẽ dưới thanh hệ thống (`edgeToEdge`), đọc `SharedPreferences`, tạo một `ApiClient` và ba provider; `SmartFitApp(auth:, plans:, grocery:)` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng Onboarding → màn chờ → màn chính 4 tab bằng enum `AppScreen` + `setState` (không có router) |
+| `main.dart` | `main()` bật vẽ dưới thanh hệ thống (`edgeToEdge`), đọc `SharedPreferences`, tạo một `ApiClient` và bốn provider; `SmartFitApp(auth:, plans:, grocery:, history:)` bọc `MaterialApp` bằng `MultiProvider`; `MainShell` điều hướng màn chào (lần đầu) → Onboarding → màn chờ → màn chính 4 tab bằng enum `AppScreen` + `setState` (không có router); giữ hai route khôi phục được: bảng feedback, bảng đăng nhập |
 | `config/api_config.dart` | `resolveApiBaseUrl()` — địa chỉ backend |
 | `models/api/` | Model viết tay theo BRD 6 (`MealPlan`, `Profile`, `AuthResult`, `FeedbackResult`…) và enum mã cố định (`codes.dart`) |
 | `models/profile_rules.dart` | Giới hạn và luật an toàn giống backend: tuổi 18–100, chiều cao, cân nặng, BMI < 18,5, mang thai → không Giảm mỡ (#30) |
@@ -19,10 +19,10 @@
 | `models/plan_schedule.dart` | Ngày bắt đầu của plan, hôm nay là ngày mấy (D6-B1) |
 | `models/feedback_rules.dart` | Ngày nào được gửi feedback (`canReviewDay()`), `FeedbackLog` — ngày đã gửi của một plan (#36) |
 | `models/feedback_summary.dart` | `describeFeedbackChanges()` — so plan trước/sau khi gửi feedback, liệt kê điều đã đổi |
-| `services/` | `ApiClient`, `ApiException` |
-| `providers/` | `PlanProvider` (plan, hồ sơ của plan, lịch, bản nháp hồ sơ), `AuthProvider`, `GroceryProvider` (đã mua / đã có sẵn) |
-| `screens/` | `onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`, `profile_screen.dart` |
-| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart`, `app_frame.dart`, `feedback_sheet.dart` (bảng feedback cuối ngày + `feedbackSheetRoute`) |
+| `services/` | `ApiClient`, `ApiException`; `google_auth.dart` — `GoogleAuth` (lớp trừu tượng) và `PluginGoogleAuth` (`google_sign_in` 7.x); `google_button_stub.dart` / `google_button_web.dart` — nút Google của bản web, chọn bằng import có điều kiện (`dart.library.js_interop`) |
+| `providers/` | `PlanProvider` (plan, hồ sơ của plan, lịch, bản nháp hồ sơ), `AuthProvider` (token, user, cách đăng nhập theo `/health`, cờ màn chào), `GroceryProvider` (đã mua / đã có sẵn), `HistoryProvider` (danh sách lịch sử, chỉ trong bộ nhớ) |
+| `screens/` | `welcome_screen.dart`, `onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart` (cả `PlanDayView` — một ngày chỉ để xem), `grocery_screen.dart`, `history_screen.dart`, `plan_detail_screen.dart`, `profile_screen.dart` |
+| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart`, `app_frame.dart`, `feedback_sheet.dart` (bảng feedback cuối ngày + `feedbackSheetRoute`), `login_panel.dart` (`LoginPanel`, `LoginSheet` + `loginSheetRoute`, `GuestBanner`) |
 | `theme/app_colors.dart` | Bảng màu dùng chung |
 
 Ngoài `lib/`: `tool/make_icon.swift` + `tool/update_icons.sh` vẽ lại icon, `assets/icon/` là hai ảnh gốc. Chữ trên giao diện và comment viết tiếng Việt; số thập phân hiển thị kiểu Việt ("24,8").
@@ -31,20 +31,24 @@
 
 1. `SharedPreferences.getInstance()` đọc hết dữ liệu đã lưu một lần, sau đó đọc đồng bộ — không cần màn chờ.
 2. `AuthProvider` nạp token và user; `PlanProvider` nạp hồ sơ, plan, lịch, bản nháp. Hồ sơ lưu từ trước mà nay bị luật v2.6.0 chặn (dưới 18 tuổi, thiếu cân + Giảm mỡ…) → bỏ plan, giữ hồ sơ để điền sẵn Onboarding (mọi request với hồ sơ đó đều bị 400).
-3. `MainShell`: có plan → màn chính, tab Kế hoạch mở đúng ngày hôm nay; chưa có → Onboarding. Mở app không gọi mạng, nên có plan thì xem được khi không có mạng (NFR-2). App quay lại foreground (ví dụ qua nửa đêm) → tính lại ngày.
+3. `MainShell`: có plan → màn chính, tab Kế hoạch mở đúng ngày hôm nay; chưa có → Onboarding, trước đó là màn chào nếu `AuthProvider.showWelcome` (chưa đăng nhập, chưa bấm "Dùng ngay" — khoá `smartfit.welcome_done.v1`). Có plan thì mở app không gọi mạng, xem được khi không có mạng (NFR-2); màn chào gọi `/health` để biết cách đăng nhập. App quay lại foreground (ví dụ qua nửa đêm) → tính lại ngày.
 
 ## Màn hình
 
 | Màn | Làm gì |
 |---|---|
+| Màn chào | Chỉ lần đầu (FR-6.1): tên app, một câu lợi ích, `LoginPanel`, "Dùng ngay, không cần đăng nhập". Đăng nhập xong hoặc bấm "Dùng ngay" → Onboarding, không hiện lại |
+| Bảng đăng nhập | `LoginPanel` hỏi `AuthProvider.loginMode()` (`/health`, #37): `mock` → ô email + "Đăng nhập demo" (kiểm dạng email như backend; email đang gõ lưu tạm — #35); `google` → theo `GoogleAuth.support`: Android/macOS nút "Đăng nhập với Google", web nút do Google vẽ, Windows ghi "chưa hỗ trợ", build thiếu Client ID ghi "chưa được cấu hình". Người dùng huỷ → im lặng; lỗi Google → câu tiếng Việt; backend 401 → "Máy chủ không chấp nhận lần đăng nhập này". `/health` lỗi → câu lỗi + "Thử lại". Mở từ tab Cá nhân, tab Lịch sử, các nút "Đăng nhập lại" (`loginSheetRoute`, khôi phục được) |
 | Onboarding | 3 bước (D6-B2): cơ thể (giới tính, mang thai / cho con bú nếu là nữ, tuổi, chiều cao, cân nặng) → mức vận động và mục tiêu → hạn chế. Báo lỗi ngay dưới ô; nút tiếp tục khoá tới khi bước hợp lệ; "Giảm mỡ" bị khoá kèm lý do khi thiếu cân hoặc mang thai (#30). Nút Back của hệ thống quay lại bước trước. Nút luôn ở đáy nên màn hình nhỏ không đẩy nút xuống dưới mép |
 | Hạn chế (D5) | 3 công tắc "Tôi có …" (tắt = không có) → chip chọn nhiều + "Khác" tự ghi; tối đa 300 ký tự mỗi mục; dòng khuyến cáo y tế (NFR-9) |
-| Màn chờ | Gọi `PlanProvider.generate()`; sau 15 s đổi câu "có thể mất tới 40 giây". Lỗi → câu của `ApiException` + "Thử lại", "Sửa hồ sơ", và "Về kế hoạch đang có" nếu đã có plan |
+| Màn chờ | Gọi `PlanProvider.generate()`; sau 15 s đổi câu "có thể mất tới 40 giây". Lỗi → câu của `ApiException` + "Thử lại", "Sửa hồ sơ", và "Về kế hoạch đang có" nếu đã có plan. 401 → nút chính "Đăng nhập lại" (đăng nhập xong `MainShell` tạo tiếp), "Tạo không cần đăng nhập" |
+| Thay kế hoạch | Khách đang có plan bấm "Tạo kế hoạch mới" (Dashboard, tab Cá nhân, 409 của bảng feedback) → hộp "Thay kế hoạch hiện tại?" (quyết định Q5 giai đoạn 8); đã đăng nhập thì không hỏi — plan cũ nằm trong lịch sử |
 | Kế hoạch | 3 tab ngày, mở sẵn hôm nay; 3 bữa (calo, đạm, tinh bột, béo, nguyên liệu); tổng ngày so với `daily_target` bằng `MacroRing` (phần trăm thật, có thể > 100%); buổi tập; `warnings`; nhãn "Thực đơn mẫu" khi `source = sample`. Dải nhắc: hồ sơ đã sửa, kế hoạch đã hết (> 3 ngày), chưa tới ngày bắt đầu |
-| Đổi món / đổi bài | Gọi API (FR-4.1, FR-4.2 — chuyển từ giai đoạn 7 lên); khoá mọi nút khi `busy`, vòng xoay đúng nút đang chờ; 409 → câu của server + nút "Tạo mới"; 422 và lỗi khác → câu của server |
+| Đổi món / đổi bài | Gọi API (FR-4.1, FR-4.2 — chuyển từ giai đoạn 7 lên); khoá mọi nút khi `busy`, vòng xoay đúng nút đang chờ; 409 → câu của server + nút "Tạo mới"; 401 → "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"; 422 và lỗi khác → câu của server |
 | Đi chợ | Dựng từ `grocery_list` (#7), tên nhóm theo BRD FR-3.1; tích "đã mua"; "đã có sẵn" ẩn khỏi danh sách cần mua, "Hiện lại" → "Cần mua"; tìm kiếm (`matchesSearch()` trong `lib/models/search_text.dart`: gõ không dấu "ga" ra "Thịt gà", "Gạo tẻ"; gõ có dấu thì so đúng dấu — "cá" không ra "Cà chua"), lọc nhóm. Không có nút thêm nguyên liệu |
-| Cá nhân | Tóm tắt hồ sơ (BMI, calo mục tiêu); sửa bằng cùng form, lưu thành **bản nháp** — plan đang mở vẫn dùng hồ sơ cũ nên đổi món không bị 409; dải "Tạo kế hoạch mới" dùng bản nháp |
-| Lịch sử | Chỗ giữ — đăng nhập và lịch sử ở giai đoạn 8 |
+| Cá nhân | Tóm tắt hồ sơ (BMI, calo mục tiêu); sửa bằng cùng form, lưu thành **bản nháp** — plan đang mở vẫn dùng hồ sơ cũ nên đổi món không bị 409; dải "Tạo kế hoạch mới" dùng bản nháp. Khách → dải nhắc "kế hoạch chỉ lưu trên máy này" + "Đăng nhập" (`GuestBanner`, Q6). Đã đăng nhập → thẻ "Tài khoản": tên, email, "Đăng xuất" (plan trên máy giữ), "Xoá tài khoản" (hộp hỏi lại → `DELETE /api/v1/me`, FR-6.4) |
+| Lịch sử | Khách → `GuestBanner` (sau 401: "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"). Đã đăng nhập → tải mỗi lần mở tab, kéo xuống để tải lại; mỗi dòng: ngày giờ tạo theo giờ trên máy (`historyTime()`), "Mục tiêu … kcal/ngày", nhãn "Đang dùng" khi trùng `plan_id` hiện tại. Plan đang dùng không có trong danh sách → ghi chú "chưa có trong lịch sử của tài khoản này" (Q4 — plan tạo lúc chưa đăng nhập không bao giờ vào lịch sử). Lỗi → câu lỗi + "Thử lại" |
+| Xem lại plan cũ | `PlanDetailScreen` (`planDetailRoute`, khôi phục được): 3 tab ngày, `PlanWarnings`, `PlanDayView` — không nút đổi món/bài/feedback (lịch sử không lưu hồ sơ, gửi lại sẽ 409). 404 → "Kế hoạch này không còn trong lịch sử" + "Về danh sách" (tải lại danh sách) |
 | Feedback cuối ngày | Thẻ "Đánh giá cuối ngày" ở cuối tab ngày được đánh giá (hôm nay, hôm qua; ngày 3 cả khi plan đã hết — #36) → bảng trượt 3 câu hỏi (D2): "Bình thường" loại trừ trạng thái khác; chọn dấu hiệu nguy hiểm → ô đỏ khuyến cáo ngay, không cần mạng; gửi → vòng xoay (ngày 3: "có thể mất tới 40 giây"); lỗi → câu của `ApiException`, giữ lựa chọn; 409 → "Tạo kế hoạch mới". Kết quả trong bảng: `safety_warning` → ô đỏ, chỉ nút "Tôi đã hiểu" đóng được (Back, chạm ra ngoài bị chặn, kéo xuống tắt); tóm tắt điều đã đổi từ `describeFeedbackChanges()`. Đã gửi → thẻ "Đã gửi đánh giá ngày d" |
 
 ## Địa chỉ backend
@@ -105,16 +109,19 @@
 | `smartfit.grocery.v1` | `GroceryProvider` | `plan_id` + món đã mua + món đã có sẵn; khoá mỗi dòng = nhóm + tên + lượng (lượng đổi sau khi đổi món → dòng đó bỏ tích); plan mới → xoá |
 | `smartfit.access_token` | `AuthProvider` | JWT của backend (7 ngày) |
 | `smartfit.user.v1` | `AuthProvider` | `id`, `email`, `name` |
+| `smartfit.welcome_done.v1` | `AuthProvider` | `true` sau khi đăng nhập hoặc bấm "Dùng ngay" — màn chào không hiện lại |
 | `smartfit.feedback.v1` | `PlanProvider` | `plan_id` + số ngày đã gửi feedback — **không** có câu trả lời; khoá chỉ đặt sau khi server trả plan; tạo plan mới hoặc feedback ngày 3 → xoá; của plan khác hoặc hỏng → coi như chưa gửi (#36) |
 
 - Số phiên bản trong khoá: đổi định dạng theo cách bản cũ không đọc được thì tăng số.
 - Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai; lịch thiếu hoặc của plan khác → coi như bắt đầu hôm nay.
+- Lịch sử (`HistoryProvider`) không lưu xuống máy — dữ liệu nằm ở server (FR-7.3); đăng xuất hoặc đổi tài khoản → bỏ danh sách.
+- Android không sao lưu các khoá này (#37): `android:dataExtractionRules="@xml/data_extraction_rules"` (Android 12+, cả `cloud-backup` lẫn `device-transfer` — `allowBackup="false"` không chặn được chép giữa hai máy khi `targetSdk` ≥ 31) và `android:fullBackupContent="@xml/backup_rules"` (Android 11 trở xuống), cùng loại `domain="sharedpref"`. Đã thử 2026-10-01 trên Android 16: `bmgr backupnow` qua LocalTransport — bản cũ có `sp/FlutterSharedPreferences.xml` trong bản sao lưu, bản mới chỉ còn tệp thường. Cần bản release (bản debug có `app_flutter` ~55 MB, vượt hạn mức) và app không ở trạng thái bị force-stop.
 - Trên web, `shared_preferences` là `localStorage` của trình duyệt: dữ liệu sức khoẻ và token nằm trong trình duyệt. BRD chấp nhận việc lưu trên máy người dùng (NFR-7, D4); backend vẫn không lưu `restrictions` (#12).
 - `PlanProvider.busy` = đang chờ server; gọi thêm khi đang bận bị bỏ qua, không ném lỗi. `PlanProvider` nhận đồng hồ (`now:`) để test đổi ngày.
 
 ### Dữ liệu đang nhập dở (PLAN D8, #35)
 
-Không ghi xuống `shared_preferences` — chỉ lưu tạm bằng state restoration: `MaterialApp.restorationScopeId: 'smartfit'`; `OnboardingScreen` (bước + form), `ProfileScreen` (phần sửa hồ sơ dở), `MainShell` (tab đang mở, bảng feedback đang mở — `RestorableRouteFuture` + `Navigator.restorablePush(feedbackSheetRoute)`, đặt ở `MainShell` vì Dashboard dựng lại khi plan đổi), `FeedbackSheet` (câu trả lời đang chọn) dùng `RestorationMixin`. Form được chụp thành JSON bằng `ProfileFormController.toSnapshot()` / `restoreSnapshot()` (cả ô chưa hợp lệ). Android: Back ở màn gốc gọi `MainActivity.popSystemNavigator()` → `moveTaskToBack(true)` (như nút Home) thay vì `finish()`.
+Không ghi xuống `shared_preferences` — chỉ lưu tạm bằng state restoration: `MaterialApp.restorationScopeId: 'smartfit'`; `OnboardingScreen` (bước + form), `ProfileScreen` (phần sửa hồ sơ dở), `MainShell` (tab đang mở, bảng feedback đang mở — `RestorableRouteFuture` + `Navigator.restorablePush(feedbackSheetRoute)`, đặt ở `MainShell` vì Dashboard dựng lại khi plan đổi), `FeedbackSheet` (câu trả lời đang chọn) dùng `RestorationMixin`; từ giai đoạn 8 thêm bảng đăng nhập (`MainShell._loginRoute`, hoặc `restorablePush(loginSheetRoute)` từ bảng feedback), email đang gõ trong `LoginPanel`, ngày đang xem trong `PlanDetailScreen`. Form được chụp thành JSON bằng `ProfileFormController.toSnapshot()` / `restoreSnapshot()` (cả ô chưa hợp lệ). Android: Back ở màn gốc gọi `MainActivity.popSystemNavigator()` → `moveTaskToBack(true)` (như nút Home) thay vì `finish()`.
 
 | Tình huống (đã thử trên Android 16, bản release) | Kết quả |
 |---|---|
@@ -163,14 +170,15 @@
 
 ## Test
 
-- `cd frontend_app && flutter test` — 125 test, không cần backend chạy:
+- `cd frontend_app && flutter test` — 174 test, không cần backend chạy:
   - `test/models/` — vòng tròn fixture (`contract_test.dart`), luật hồ sơ, chip hạn chế so với `restriction_labels.json`, lịch ngày;
-  - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
+  - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`; `google_auth_test.dart` — `PluginGoogleAuth` chạy trên `GoogleSignInPlatform` giả (gói `google_sign_in_platform_interface`, chỉ ở `dev_dependencies`): nền tảng → cách đăng nhập, `clientId`/`serverClientId`, huỷ, lỗi cấu hình, keychain, luồng token của nút web;
   - `test/providers/` — `SharedPreferences.setMockInitialValues()`, đồng hồ giả;
-  - `test/screens/` — từng màn hình; `test/widgets/feedback_sheet_test.dart` — bảng feedback trong cả app; `test/widget_test.dart` — luồng của cả app;
-  - `test/app_harness.dart` — dựng app/màn hình cỡ điện thoại (411×914 dp) với backend giả, dữ liệu đã lưu, đồng hồ giả; `fillOnboarding()`, `scrollTo()` (danh sách chỉ dựng phần đang hiện — cuộn rồi `ensureVisible` trước khi bấm);
-  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, `responses` thay JSON cho một đường dẫn, ghi lại request.
-- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (điền Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1). Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`. Máy ảo mở lại từ snapshot đôi khi làm test treo ở màn khởi động (bản debug chờ `flutter` kết nối mãi) — tắt máy ảo rồi khởi động nguội: `emulator -avd <tên> -no-snapshot-load`.
+  - `test/screens/` — từng màn hình (gồm `history_screen_test.dart`: danh sách, ghi chú Q4, 401, chi tiết, 404); `test/widgets/feedback_sheet_test.dart` — bảng feedback trong cả app; `login_panel_test.dart` — bảng đăng nhập theo `auth_mode` và `GoogleAuth.support`; `test/widget_test.dart` — luồng của cả app (màn chào, Q5, 401 lúc tạo plan, khôi phục bảng đăng nhập);
+  - `test/app_harness.dart` — dựng app/màn hình cỡ điện thoại (411×914 dp) với backend giả, `FakeGoogleAuth` (`test/fake_google_auth.dart`), dữ liệu đã lưu, đồng hồ giả; mặc định đã qua màn chào (`firstLaunch: true` để thấy màn chào); `signedIn()` — dữ liệu đã lưu của một phiên đăng nhập; `fillOnboarding()`, `scrollTo()` (danh sách chỉ dựng phần đang hiện — cuộn rồi `ensureVisible` trước khi bấm);
+  - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, `responses` thay JSON cho một đường dẫn, `failWith` (5xx: body chung), ghi lại request.
+- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (màn chào → đăng nhập demo → Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1 → tab Lịch sử có plan "Đang dùng" → xem chi tiết → xoá tài khoản ở tab Cá nhân). 3/3 trên Android 16 và macOS ngày 2026-10-01. Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`. Máy ảo mở lại từ snapshot đôi khi làm test treo ở màn khởi động (bản debug chờ `flutter` kết nối mãi) — tắt máy ảo rồi khởi động nguội: `emulator -avd <tên> -no-snapshot-load`.
+- Flutter web chỉ vẽ khi tab đang hiện: cửa sổ Chrome bị che hoặc thu nhỏ → `document.visibilityState = "hidden"`, trình duyệt ngừng `requestAnimationFrame`, chuyển trang và hộp thoại đứng giữa chừng dù thao tác vẫn chạy (gặp khi thử bằng công cụ điều khiển Chrome, 2026-10-01). Đưa cửa sổ lên trước, hoặc kiểm kết quả ở backend/DB.
 - Chưa có máy ảo: Android Studio → Device Manager → tạo thiết bị (ví dụ Pixel 8, API 36).
 - `Container` có màu nền bọc `ListTile`/`SwitchListTile`/`ExpansionTile` → Flutter báo lỗi ở bản debug (hiệu ứng bấm bị che) — dùng `Material` có `shape` thay cho `Container`.
 - CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi, rồi build 4 nền tảng (mục "Nền tảng").
@@ -178,5 +186,5 @@
 
 ## Việc của giai đoạn sau
 
-- **8:** Google Sign-In → `AuthProvider.signIn(idToken)`; tab Lịch sử.
+- **9.4:** đăng nhập Google thật trên Android, macOS — mới kiểm bằng bản giả; bản web đã thử với Client ID thật 2026-10-01 (`docs/SETUP_CREDENTIALS.md` mục 3).
 - Thực đơn mẫu lệch macro so với mục tiêu (ví dụ tinh bột ~120%, chất béo ~70%) vì chỉ được nhân khẩu phần theo calo; backend không kiểm tỉ lệ macro — Dashboard hiện đúng phần trăm thật. Ghi ở mục "Để sau" của PLAN.
```

```diff
--- a/docs/knowledge/wiki/reference-materials.md
+++ b/docs/knowledge/wiki/reference-materials.md
@@ -1,5 +1,5 @@
 ---
-last_updated: 2026-09-22
+last_updated: 2026-10-01
 tags: [gemini, nestjs, flutter, dinh-duong, tham-khao]
 ---
 
@@ -53,6 +53,7 @@
 - [`http`](https://pub.dev/packages/http) — gọi REST API, package chính thức của dart.dev.
 - [`provider`](https://pub.dev/packages/provider) — state management dựa trên `InheritedWidget`.
 - [`shared_preferences`](https://pub.dev/packages/shared_preferences) — lưu trữ cục bộ key-value, bản mới nhất (2.5.5) yêu cầu Flutter 3.35+/Dart 3.9+. `frontend_app/pubspec.yaml` đang khai báo `sdk: ^3.13.1` (tức Dart ≥ 3.13.1), đã thoả yêu cầu này, không cần nâng. Máy dev hiện chạy Flutter 3.47.5 / Dart 3.13.4.
+- [`google_sign_in`](https://pub.dev/packages/google_sign_in) 7.2.0 (kiểm 2026-09-30) — đăng nhập Google, API 7.x (`GoogleSignIn.instance.initialize()`, `authenticate()`, `authenticationEvents`); Android, iOS, macOS, web, không có Windows/Linux. Bản web bắt buộc nút của Google Identity Services ([`google_sign_in_web`](https://pub.dev/packages/google_sign_in_web) `web_only.renderButton()`). Hành vi đã kiểm và cách dùng trong app: [[auth-and-history]] mục "Phía app".
 
 ## 4. Dinh dưỡng — dữ liệu tham chiếu cho NFR-4
```

```diff
--- a/docs/knowledge/wiki/wiki-triggers.md
+++ b/docs/knowledge/wiki/wiki-triggers.md
@@ -1,6 +1,6 @@
 ---
 type: meta
-last_updated: 2026-09-27
+last_updated: 2026-10-01
 ---
 
 # Wiki Triggers
@@ -21,6 +21,7 @@
 | `frontend_app/lib/screens/**`, `frontend_app/lib/widgets/**`, `frontend_app/lib/theme/**`, `frontend_app/lib/main.dart` | `flutter-ui.md` |
 | `backend_api/src/plan/profile-safety.ts`, `backend_api/src/plan/dto/profile-safety.validator.ts`, `backend_api/src/plan/exercise-level.ts` | `plan-data-contract.md`, `swap-and-feedback.md`, `critical-constraints.md` (#30, #31) |
 | `frontend_app/lib/models/**`, `frontend_app/lib/services/**`, `frontend_app/lib/providers/**`, `frontend_app/lib/config/**`, `frontend_app/test/**` | `flutter-ui.md`, `critical-constraints.md` (#26, #28) |
+| `frontend_app/lib/services/google_auth.dart`, `frontend_app/lib/services/google_button_*.dart`, `frontend_app/lib/providers/auth_provider.dart`, `frontend_app/lib/providers/history_provider.dart`, `frontend_app/lib/widgets/login_panel.dart`, `frontend_app/lib/screens/welcome_screen.dart`, `frontend_app/lib/screens/history_screen.dart`, `frontend_app/lib/screens/plan_detail_screen.dart`, `frontend_app/android/app/src/main/res/xml/**`, `frontend_app/macos/Runner/Info.plist`, `docs/SETUP_CREDENTIALS.md` | `auth-and-history.md`, `flutter-ui.md`, `critical-constraints.md` (#37) |
 | `backend_api/src/cors-options.ts`, `backend_api/test/cors.e2e-spec.ts`, `backend_api/test/contract-fixtures.e2e-spec.ts` | `flutter-ui.md`, `critical-constraints.md` (#26, #27) |
 | `frontend_app/pubspec.yaml`, `frontend_app/android/**/AndroidManifest.xml`, `frontend_app/ios/Runner/Info.plist`, `frontend_app/macos/Runner/*.entitlements`, `.github/workflows/frontend.yml`, `frontend_app/android/app/src/main/res/**`, `frontend_app/web/**`, `frontend_app/tool/**`, `frontend_app/assets/icon/**`, `frontend_app/windows/**`, `frontend_app/macos/Runner/Configs/**`, `frontend_app/android/app/src/main/kotlin/**` | `flutter-ui.md`, `critical-constraints.md` (#29, #35) |
 | `BRD.md` | `product-spec.md` *(chưa có — đọc thẳng BRD.md)* |
@@ -40,7 +41,8 @@
 | gemini / prompt / structured output / JSON schema / ảo giác (hallucination) | `gemini-integration.md` |
 | endpoint / controller / swagger / health / validation / DTO | `plan-data-contract.md`, `auth-and-history.md`, `swap-and-feedback.md` |
 | đổi món / đổi bài / swap / feedback / dị ứng / chấn thương / từ khoá / kho món / kho động tác / dấu hiệu nguy hiểm / khẩu phần | `swap-and-feedback.md`, `flutter-ui.md` và `critical-constraints.md` (#36) khi là phần app |
-| đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md` |
+| đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md`; phần app: `flutter-ui.md`, `critical-constraints.md` (#37) |
+| màn chào / khách / đăng nhập demo / Client ID / SHA-1 / keychain / sao lưu Android / backup | `auth-and-history.md`, `flutter-ui.md`, `critical-constraints.md` (#37) |
 | screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
 | CORS / API_BASE_URL / dart-define / ApiClient / provider / shared_preferences / fixture hợp đồng / quyền mạng | `flutter-ui.md`, `critical-constraints.md` |
 | thiếu cân / BMI / mang thai / cho con bú / tuổi tối thiểu / độ khó động tác / mức động tác | `plan-data-contract.md`, `critical-constraints.md` |
```

```diff
--- a/docs/knowledge/wiki/INDEX.md
+++ b/docs/knowledge/wiki/INDEX.md
@@ -1,6 +1,6 @@
 # Mục lục Knowledge Base
 
-_Cập nhật lần cuối: 2026-09-27_
+_Cập nhật lần cuối: 2026-10-01_
 
 ## Danh sách chủ đề
 
@@ -11,9 +11,9 @@
 | [[reference-materials]]     | Tài liệu/công nghệ tham khảo bên ngoài liên quan tới dự án             |
 | [[plan-data-contract]]      | Hợp đồng dữ liệu plan: luồng generate-plan, hai lớp DTO, mã cố định, danh sách đi chợ |
 | [[gemini-integration]]      | Hành vi thật của SDK Gemini (hết giờ, lỗi, không tự gọi lại), cách test không cần khoá |
-| [[auth-and-history]]        | Đăng nhập Google/giả lập, JWT, guard, SQLite + migration, lịch sử kế hoạch; hành vi thư viện đã kiểm chứng |
+| [[auth-and-history]]        | Đăng nhập Google/giả lập, JWT, guard, SQLite + migration, lịch sử kế hoạch; phía app (cách đăng nhập theo /health, 401, google_sign_in 7.x); hành vi thư viện đã kiểm chứng |
 | [[swap-and-feedback]]       | Đổi món, đổi bài tập, feedback cuối ngày; bộ khớp từ khoá dị ứng/chấn thương; kho món và động tác soạn sẵn |
-| [[flutter-ui]]              | App Flutter: Onboarding 3 bước, kế hoạch 3 ngày, đi chợ, hồ sơ; ApiClient, provider, lưu trên máy, fixture hợp đồng, CORS, quyền mạng, icon |
+| [[flutter-ui]]              | App Flutter: màn chào, đăng nhập, Onboarding 3 bước, kế hoạch 3 ngày, đi chợ, lịch sử, hồ sơ & tài khoản; ApiClient, provider, lưu trên máy, sao lưu Android, fixture hợp đồng, CORS, quyền mạng, icon |
 | [[log]]                     | Nhật ký thay đổi wiki theo thời gian                                   |
 
 ## Tra cứu nhanh
```

```diff
--- a/docs/knowledge/wiki/log.md
+++ b/docs/knowledge/wiki/log.md
@@ -25,3 +25,5 @@
 2026-09-29 — Kiểm lại Android (release APK) và macOS: [[flutter-ui]] ghi kết quả, tìm kiếm đi chợ không dấu (`search_text.dart`), cửa sổ macOS 600×760 và chuyện macOS tự khôi phục cỡ cửa sổ
 2026-09-29 — PLAN D8 (BRD v2.7.0): thêm ràng buộc #34 (tag suy từ tên động tác, `knee_bend`, đau gối tránh gập gối) và #35 (dữ liệu đang nhập chỉ lưu tạm bằng state restoration, Back ở màn gốc Android đưa app xuống nền); [[flutter-ui]] thêm mục "Dữ liệu đang nhập dở"; [[gemini-integration]] thêm lần đo prompt đau gối; [[plan-data-contract]], [[swap-and-feedback]] thêm tag `knee_bend`
 2026-09-30 — Giai đoạn 7 (PLAN.md, BRD v2.7.1): thêm ràng buộc #36 (feedback cuối ngày: ngày được gửi, khoá `smartfit.feedback.v1` chỉ số ngày, cảnh báo an toàn chỉ đóng bằng "Tôi đã hiểu", báo điều đã đổi); [[flutter-ui]] thêm bảng feedback, khoá lưu mới, route khôi phục ở `MainShell`; [[swap-and-feedback]] ghi phần app
+2026-10-01 — Giai đoạn 8 (PLAN.md, BRD v2.8.0): thêm ràng buộc #37 (cách đăng nhập theo `/health`, Google qua lớp `GoogleAuth`, 401 → "Đăng nhập lại", khách thay kế hoạch phải hỏi, Android loại `sharedpref` khỏi sao lưu, không commit cấu hình Google của macOS); [[auth-and-history]] thêm mục "Phía app" và hành vi `google_sign_in` 7.2.0, bỏ ghi chú CORS đã cũ; [[flutter-ui]] thêm màn chào, bảng đăng nhập, tab Lịch sử, xem lại plan cũ, tài khoản, khoá `smartfit.welcome_done.v1`, sao lưu Android, 174 test; [[reference-materials]] thêm `google_sign_in`; wiki-triggers có đường dẫn và từ khoá mới
+2026-10-01 — Thử Google Sign-In thật trên bản web (Client ID thật, backend `AUTH_MODE=google`): [[auth-and-history]] thêm mục "Đã thử với Google thật"; [[flutter-ui]] ghi chuyện Flutter web không vẽ khi cửa sổ Chrome bị che; SETUP mục 3.2 đổi gợi ý cổng 5000 → 5050 (AirPlay Receiver của macOS chiếm cổng 5000)
```

### Task 4 — `CLAUDE.md`, README

```diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -20,11 +20,11 @@
 
 This is a monorepo with three components:
 
-- **`frontend_app/`** — Flutter app, wired to `backend_api` since phase 6: 3-step onboarding, loading, the 3-day plan (meal/exercise swap via the API), grocery checklist and profile tab all read and write through the providers; no hardcoded data left. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. The end-of-day feedback sheet is built (phase 7); login/history (phase 8) are not built yet.
+- **`frontend_app/`** — Flutter app, wired to `backend_api` since phase 6: 3-step onboarding, loading, the 3-day plan (meal/exercise swap via the API), grocery checklist and profile tab all read and write through the providers; no hardcoded data left. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. The end-of-day feedback sheet is built (phase 7), and so are the first-launch welcome screen, login (a "demo" email login when the backend runs `AUTH_MODE=mock`, `google_sign_in` 7.x otherwise — chosen from `/health`, not at build time), the history tab, sign-out and account deletion (phase 8). Real Google sign-in was tried on the web build with a real Client ID (2026-10-01); Android and macOS have only been tested against fakes ([docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md) §3).
 - **`backend_api/`** — NestJS (TypeScript) service, scaffolded and working: `GET /health` and `POST /api/v1/generate-plan` (see Backend architecture below). Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to the bundled 3-day `sample-plan.json` when `GEMINI_API_KEY` is unset, Gemini times out, or its output fails contract validation (BRD NFR-2, NFR-4) — the response's `source` field (`gemini` / `sample`) says which one was used. Accounts (Google Sign-In, mock mode by default), `DELETE /api/v1/me`, and plan history on SQLite/TypeORM are built (BRD FR-6, FR-7; PLAN.md phase 3). Meal/exercise swap and end-of-day feedback (BRD §6.4) are built too (PLAN.md phase 4): stateless endpoints that take `{ profile, plan, … }` and return the whole new plan.
 - **`ai_workspace/`** — standalone Node/TypeScript project (own `package.json`, unrelated to `backend_api/`'s dependencies) for iterating on the Gemini prompt via `npm run experiment` before copying the finalized prompt into `backend_api/src/plan/gemini.service.ts`.
 
-Screens read and write through `PlanProvider`/`AuthProvider`/`GroceryProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).
+Screens read and write through `PlanProvider`/`AuthProvider`/`GroceryProvider`/`HistoryProvider` (never call `ApiClient` or `http` directly) and show `ApiException.message` on failure. The web build needs the backend's CORS (`CORS_ORIGINS`, see Backend architecture).
 
 ## Commands
 
@@ -35,6 +35,7 @@
 flutter run -d chrome           # run on Chrome; backend defaults to http://localhost:3000 (Android emulator: 10.0.2.2)
 flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000   # real phone: LAN IP of the machine running backend_api
 flutter run                     # run on a connected device/emulator
+flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=<web client id>   # real Google sign-in (backend AUTH_MODE=google); per-platform setup: docs/SETUP_CREDENTIALS.md §3
 flutter analyze                 # static analysis (flutter_lints, default rule set)
 flutter test                    # run all tests (no backend needed; fixtures in test/fixtures/)
 flutter test test/services/api_client_test.dart   # run a single test file
@@ -94,16 +95,17 @@
 
 ## Frontend architecture
 
-- `lib/main.dart` — `main()` enables `SystemUiMode.edgeToEdge`, awaits `SharedPreferences.getInstance()`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())` and the three providers; `SmartFitApp(auth:, plans:, grocery:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart` via `test/app_harness.dart`). `MainShell` owns navigation: onboarding → loading (`_generate(profile)`) → home with 4 tabs (plan, grocery, history placeholder, profile); it opens home if `PlanProvider.hasPlan`, else onboarding, and re-renders on app resume so the plan day follows the calendar.
+- `lib/main.dart` — `main()` enables `SystemUiMode.edgeToEdge`, awaits `SharedPreferences.getInstance()`, builds one `ApiClient(baseUrl: resolveApiBaseUrl())`, `AuthProvider(google: PluginGoogleAuth())` and the other providers; `SmartFitApp(auth:, plans:, grocery:, history:)` wraps `MaterialApp` in a `MultiProvider` (tests inject providers backed by `test/fake_backend.dart` and `test/fake_google_auth.dart` via `test/app_harness.dart`, which skips the welcome screen unless `firstLaunch: true`). `MainShell` owns navigation: welcome (first launch only, `AuthProvider.showWelcome`) → onboarding → loading (`_generate(profile)`) → home with 4 tabs (plan, grocery, history, profile); it opens home if `PlanProvider.hasPlan`, else onboarding, and re-renders on app resume so the plan day follows the calendar. Every "create a new plan" goes through `_createPlan()`, which asks a guest before replacing the current plan (it would be gone for good). The login sheet is a `RestorableRouteFuture` (`loginSheetRoute`); signing in after a 401 on generate-plan retries it.
 - `lib/config/api_config.dart` — `resolveApiBaseUrl()`: `--dart-define=API_BASE_URL`, else `http://10.0.2.2:3000` on Android, `http://localhost:3000` elsewhere.
 - `lib/models/api/` — hand-written models for BRD §6. `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
 - `lib/models/profile_rules.dart` (limits + safety rules mirroring the backend), `restriction_options.dart` (D5 chips; every allergy/injury chip must be a label the backend keyword matcher knows — checked against `test/fixtures/restriction_labels.json`), `plan_schedule.dart` (plan start date → today's day number), `search_text.dart` (`matchesSearch()`: typed without accents → compare without accents on both sides, typed with accents → exact, like the backend matcher).
 - `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text; a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
-- `lib/providers/` — `PlanProvider` (profile of the current plan + plan + schedule + profile draft in `shared_preferences` keys `smartfit.profile.v1` / `.plan.v1` / `.plan_schedule.v1` / `.profile_draft.v1`; edits in the profile tab stay a draft so swaps keep sending the plan's own profile and never hit 409; a stored profile that breaks the v2.6.0 rules drops the plan; `busy` flag, calls while busy are ignored; injectable clock `now:`), `GroceryProvider` (bought / already-have per plan, key = category + name + quantity), `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401). `PlanProvider.feedbackDays` = days of the current plan that already got end-of-day feedback, stored as `smartfit.feedback.v1` `{plan_id, days}` — never the answers (health data); set only after the server answered, cleared by a new plan (#36).
-- `lib/screens/` — onboarding (3 steps), loading, dashboard, grocery, profile; `lib/widgets/profile_form.dart` — form shared by onboarding and the profile tab; `lib/widgets/feedback_sheet.dart` — end-of-day feedback bottom sheet (D2 questions, danger advice shown immediately, `safety_warning` closes only via "Tôi đã hiểu", result from `describeFeedbackChanges()` in `lib/models/feedback_summary.dart`), opened by `MainShell` through a `RestorableRouteFuture` (not the Dashboard — it is rebuilt when the plan changes) from the card that `canReviewDay()` (`lib/models/feedback_rules.dart`: today, yesterday, day 3 after the plan ended) allows; `lib/theme/app_colors.dart` — palette. `lib/widgets/app_frame.dart` (`AppFrame`, set in `MaterialApp.builder`) keeps the whole app in a centred column at most 640 wide on web/desktop windows and narrows `MediaQuery.size` to match. Wrap `ListTile`s in `Material` (not a coloured `Container`) or Flutter asserts in debug.
+- `lib/providers/` — `PlanProvider` (profile of the current plan + plan + schedule + profile draft in `shared_preferences` keys `smartfit.profile.v1` / `.plan.v1` / `.plan_schedule.v1` / `.profile_draft.v1`; edits in the profile tab stay a draft so swaps keep sending the plan's own profile and never hit 409; a stored profile that breaks the v2.6.0 rules drops the plan; `busy` flag, calls while busy are ignored; injectable clock `now:`), `GroceryProvider` (bought / already-have per plan, key = category + name + quantity), `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`, `smartfit.welcome_done.v1`; signs out on 401; `loginMode()` reads `auth_mode` from `/health`; `signInDemo()` sends `mock:<lowercased email>`; `signInWithGoogle()` → `GoogleAuth`), `HistoryProvider` (history list in memory only, cleared on sign-out/account switch; keeps a 401 error so the tab can say why). `PlanProvider.feedbackDays` = days of the current plan that already got end-of-day feedback, stored as `smartfit.feedback.v1` `{plan_id, days}` — never the answers (health data); set only after the server answered, cleared by a new plan (#36).
+- `lib/services/google_auth.dart` — `GoogleAuth` (abstract) and `PluginGoogleAuth` on `google_sign_in` 7.x: `support` (`unsupported` on Windows/Linux — no plugin there; `notConfigured` without `--dart-define=GOOGLE_WEB_CLIENT_ID`; `button` on web; `interactive` on Android/macOS), the web client ID is `clientId` on web and `serverClientId` elsewhere, cancel → `null`, SDK errors → `GoogleAuthException` with Vietnamese text (never the SDK description). The web button (`renderButton()` from `google_sign_in_web/web_only.dart`, which needs `dart:js_interop`) sits behind a conditional import (`google_button_stub.dart` / `google_button_web.dart`). Tests use `FakeGoogleAuth`; `PluginGoogleAuth` itself is tested against a fake `GoogleSignInPlatform`. macOS also needs `GIDClientID`, a URL scheme and keychain sharing, which need a signing team — not committed (CI builds macOS unsigned).
+- `lib/screens/` — welcome, onboarding (3 steps), loading (401 → "Đăng nhập lại"), dashboard (`PlanDayView` = one read-only day, reused by the history detail), grocery, history + `plan_detail_screen.dart` (read-only: history keeps no profile, so swaps would 409), profile (account card: sign out, delete account with confirmation; guest banner); `lib/widgets/login_panel.dart` — `LoginPanel` (demo email or Google button per `loginMode()`), `LoginSheet`, `GuestBanner`; `lib/widgets/profile_form.dart` — form shared by onboarding and the profile tab; `lib/widgets/feedback_sheet.dart` — end-of-day feedback bottom sheet (D2 questions, danger advice shown immediately, `safety_warning` closes only via "Tôi đã hiểu", result from `describeFeedbackChanges()` in `lib/models/feedback_summary.dart`), opened by `MainShell` through a `RestorableRouteFuture` (not the Dashboard — it is rebuilt when the plan changes) from the card that `canReviewDay()` (`lib/models/feedback_rules.dart`: today, yesterday, day 3 after the plan ended) allows; `lib/theme/app_colors.dart` — palette. `lib/widgets/app_frame.dart` (`AppFrame`, set in `MaterialApp.builder`) keeps the whole app in a centred column at most 640 wide on web/desktop windows and narrows `MediaQuery.size` to match. Wrap `ListTile`s in `Material` (not a coloured `Container`) or Flutter asserts in debug.
 - App name/icon/splash: `tool/update_icons.sh` (macOS: `swift` + `sips`) redraws `assets/icon/*.png` with `tool/make_icon.swift` and copies every size for Android (incl. adaptive icon), iOS, macOS, web, and packs the Windows `app_icon.ico` with `tool/make_ico.swift` — deterministic. Windows name: `BINARY_NAME` `smartfit_ai`, window title in `windows/runner/main.cpp`, file info in `Runner.rc`. Android 12+ splash background is the brand green (`values-v31/styles.xml`); the Android themes set `windowDrawsSystemBarBackgrounds` so the status bar is not painted black.
-- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16), iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements. Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). CI builds all four targets, so a plugin that breaks one platform's build fails CI.
-- Unfinished input is never written to `shared_preferences` (#35): `MaterialApp.restorationScopeId` + `RestorationMixin` in `OnboardingScreen` (step + form via `ProfileFormController.toSnapshot()`/`restoreSnapshot()`), `ProfileScreen` (edit in progress) and `MainShell` (tab), so a system kill in the background restores it and a force-quit clears it; Android `MainActivity.popSystemNavigator()` moves the task to the back instead of finishing on Back at the root. Tests use `tester.restartAndRestore()`.
+- Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16), iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements. Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). The Android manifest points `dataExtractionRules`/`fullBackupContent` at `res/xml/` rules that exclude `sharedpref` from cloud backup and device transfer (health data, JWT) — keep them. CI builds all four targets, so a plugin that breaks one platform's build fails CI.
+- Unfinished input is never written to `shared_preferences` (#35): `MaterialApp.restorationScopeId` + `RestorationMixin` in `OnboardingScreen` (step + form via `ProfileFormController.toSnapshot()`/`restoreSnapshot()`), `ProfileScreen` (edit in progress), `MainShell` (tab, feedback and login sheets), `LoginPanel` (typed email), so a system kill in the background restores it and a force-quit clears it; Android `MainActivity.popSystemNavigator()` moves the task to the back instead of finishing on Back at the root. Tests use `tester.restartAndRestore()`.
 - Files written since phase 6 follow `dart format --line-length 120`; older files are not formatted — don't reformat them wholesale. CI doesn't check format.
 
 UI strings, labels, and comments are in Vietnamese throughout the existing code — match this when adding to the same screens/widgets.
```

````diff
--- a/README.md
+++ b/README.md
@@ -48,6 +48,8 @@
 flutter test integration_test -d macos
 ```
 
+Đăng nhập: backend giả lập (mặc định) → app hiện "Đăng nhập demo", nhập email bất kỳ là có lịch sử riêng. Đăng nhập Google thật cần Client ID và build với `--dart-define=GOOGLE_WEB_CLIENT_ID=<Web Client ID>` — từng nền tảng ở [docs/SETUP_CREDENTIALS.md](docs/SETUP_CREDENTIALS.md) mục 3 (Windows chưa đăng nhập Google được, dùng như khách).
+
 Nền tảng nhắm tới: Android, web, Windows, macOS (iOS tạm bỏ — PLAN D7). Mỗi lần push, CI build bản release của cả bốn; tải về ở tab Actions → lần chạy "Frontend CI" → mục Artifacts (`smartfit-apk`, `smartfit-web`, `smartfit-windows`, `smartfit-macos`). Các bản này gọi backend ở `localhost:3000`.
 
 App gọi backend ở `http://localhost:3000` (máy ảo Android: `http://10.0.2.2:3000`). Chạy trên điện thoại thật thì chỉ địa chỉ máy đang chạy backend, hai máy cùng Wi-Fi:
@@ -88,6 +90,12 @@
 
 Đối chiếu theo phiên bản BRD (mục "Phiên bản" trong [BRD.md](BRD.md)), để giảng viên/trợ giảng theo dõi tiến độ trực tiếp trên repo mà không cần đọc từng commit.
 
+### BRD v2.8.0 — 2026-10-01
+- Giai đoạn 8 — tài khoản & lịch sử: lần đầu mở app có màn chào — đăng nhập hoặc "Dùng ngay, không cần đăng nhập". App tự hỏi backend cách đăng nhập: chế độ giả lập → "Đăng nhập demo" bằng email; chế độ thật → nút Google (Android, macOS, web; Windows dùng như khách)
+- Tab Lịch sử: các kế hoạch đã tạo khi đăng nhập (ngày giờ, calo mục tiêu, nhãn "Đang dùng"), bấm vào xem lại 3 ngày (chỉ xem). Tab Cá nhân: tên, email, đăng xuất, xoá tài khoản (hỏi lại; xoá cả lịch sử trên máy chủ)
+- Phiên đăng nhập hết hạn → app báo rõ và có nút "Đăng nhập lại" thay vì âm thầm thành khách. Dùng không đăng nhập → dải nhắc "kế hoạch chỉ lưu trên máy này"; tạo kế hoạch mới thì app hỏi lại vì kế hoạch cũ sẽ mất
+- Android không còn đưa dữ liệu của app (hồ sơ sức khoẻ, token) lên bản sao lưu Google Drive hay chép sang máy mới. Hướng dẫn Google Sign-In cho app: `docs/SETUP_CREDENTIALS.md` mục 3. Kiểm thử: 174 test Flutter; chạy thật trên máy ảo Android 16 và macOS (đăng nhập demo → kế hoạch → lịch sử → xoá tài khoản). Đăng nhập Google thật đã thử trên bản web (Chrome); Android và macOS chưa thử với Client ID thật
+
 ### BRD v2.7.1 — 2026-09-30
 - Giai đoạn 7 — đánh giá cuối ngày: cuối mỗi ngày có thẻ "Đánh giá cuối ngày" mở bảng 3 câu hỏi (cường độ, tình trạng cơ thể, ăn uống). Gửi xong app báo đúng điều đã đổi ở ngày kế tiếp (ví dụ bớt hiệp, thêm giãn cơ, buổi tập ngắn lại; thực đơn cân đối lại hay giữ nguyên); ngày 3 tạo kế hoạch mới bắt đầu từ ngày mai
 - Báo chóng mặt, khó thở hay đau ngực → khuyến cáo ngừng tập hiện ngay (cả khi mất mạng); ngày kế tiếp thành ngày nghỉ; cảnh báo chỉ đóng khi bấm "Tôi đã hiểu"
````
