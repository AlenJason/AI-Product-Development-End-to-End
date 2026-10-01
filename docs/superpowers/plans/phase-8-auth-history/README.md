# Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7) — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-8-auth-history.md` (quyết định Q1–Q4 ở mục 8, Q5–Q7 ở mục 9)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F04, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. CI chạy sau khi push (`Frontend CI` — analyze, test, build 4 nền tảng; bản Windows chỉ kiểm được ở đây).

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Lớp `GoogleAuth` (`google_sign_in` 7.x), cách đăng nhập theo `/health`, cờ màn chào, `HistoryProvider` | UI (logic) | 8.1, 8.2 (Q1, Q2, Q3) |
| F02 | Màn chào, bảng đăng nhập, tab Lịch sử, xem lại plan cũ, tài khoản (đăng xuất, xoá), hỏi lại khi khách thay plan, 401 → "Đăng nhập lại" | UI | 8.1–8.3 (Q4, Q5, Q6) |
| F03 | Loại dữ liệu của app khỏi sao lưu Android; integration test trên máy ảo Android và macOS | UI + thiết bị | — (Q7) |
| F04 | `SETUP_CREDENTIALS.md` mục 3, BRD v2.8.0, PLAN, wiki #37, `CLAUDE.md`, README | Docs | 8.4 |

Backend không đổi: các endpoint có từ giai đoạn 3–4 đủ dùng (quyết định Q4 — không lưu plan tạo lúc chưa đăng nhập), không cần `fixtures:update`.

## Thứ tự thực hiện

F01 → F02 → F03 → F04. F01 chỉ thêm logic — giao diện ở mốc đó chưa đổi. Ba file sửa qua hai feature (`lib/main.dart`, `test/app_harness.dart`, `integration_test/backend_smoke_test.dart`) có diff riêng cho từng mốc.

## Code trong spec đã được chạy thật

Code của F01–F04 được viết và chạy trên bản sao repo trong thư mục nháp, rồi áp **lần lượt từng feature** lên bản `HEAD` (`git archive`) và chạy cổng kiểm ở mỗi mốc. F01 chạy đúng lệnh `flutter pub add` trong spec và so `pubspec.yaml`, `pubspec.lock`, `GeneratedPluginRegistrant.swift` với bản nháp. Code trong spec chép nguyên văn từ bản đã chạy; file sửa được nhúng dạng diff. Sau F04, bản áp theo mốc trùng khít bản nháp.

| Mốc | Flutter | Kiểm thêm |
|---|---|---|
| Hiện tại | 125 | — |
| Sau F01 | 145 | `flutter analyze` sạch; web build được (import có điều kiện) |
| Sau F02 | 174 | `flutter analyze` sạch; APK debug, web, macOS debug build được |
| Sau F03 | 174 | APK release có `dataExtractionRules`, `fullBackupContent`; integration test 3/3 trên máy ảo Android 16 (Pixel 8) và 3/3 trên macOS, backend giả lập — gồm đăng nhập demo, lịch sử, xoá tài khoản qua giao diện |
| Sau F04 | — | ràng buộc #37, 8.1–8.4 đã tích, BRD 2.8.0, SETUP mục 3 |

**Kiểm ngược (mutation).** Cố ý làm hỏng 37 hành vi; lần nào cũng có test đỏ, không đột biến nào lọt ngay lần đầu:

- cách đăng nhập: backend Google mà hiện demo; `auth_mode` lạ coi như demo; email demo giữ chữ hoa; email dài hơn backend nhận; huỷ hộp chọn Google vẫn gọi backend;
- màn chào: đăng nhập xong vẫn hiện lại; hiện cả khi đã đăng nhập; không có màn chào;
- đăng xuất không thoát phiên Google;
- lịch sử (provider): khách vẫn gọi server; đăng xuất vẫn giữ danh sách người trước; danh sách của tài khoản cũ hiện cho tài khoản mới; 401 không để lại lý do;
- `PluginGoogleAuth`: Windows coi là đăng nhập được; Android gửi Web Client ID làm `clientId`; huỷ thành lỗi; thiếu keychain sharing báo lỗi chung chung; không có ID token vẫn trả về; đăng xuất gọi SDK khi chưa khởi tạo; web bỏ token của nút;
- bảng đăng nhập: backend từ chối mà báo "phiên hết hạn"; bấm được khi email sai; Windows vẫn có nút Google; web không nghe token; email đang gõ không khôi phục được;
- thay plan: khách không bị hỏi; đã đăng nhập vẫn bị hỏi;
- 401: đăng nhập lại xong không tạo tiếp plan; đổi món không cho đăng nhập lại; màn chờ chỉ có "Thử lại"; bảng feedback không cho đăng nhập lại;
- tab Lịch sử: không có nhãn "Đang dùng"; không ghi chú plan chưa có trong lịch sử; đăng nhập khi đang mở tab không tải; 404 quay về danh sách cũ;
- tab Cá nhân: xoá tài khoản không hỏi lại; khách không thấy dải nhắc.

**Kiểm tay trên thiết bị (ngoài cổng tự động):** bản release trên máy ảo Android 16 — màn chào, đăng nhập demo, Onboarding, tab Lịch sử ("Đang dùng", giờ máy), chi tiết, thẻ Tài khoản, đăng xuất → dải nhắc, bảng đăng nhập; sao lưu bằng `bmgr` + LocalTransport: bản HEAD có `sp/FlutterSharedPreferences.xml`, bản mới không (F03, P21–P22).

**Đăng nhập Google thật (2026-10-01, sau khi plan được commit lần đầu):** bản web của bản nháp, build với Web Client ID thật của nhóm, chạy trên Chrome (macOS), backend `AUTH_MODE=google` với DB tạm — nút Google ở màn chào → chọn tài khoản → màn đồng ý (tên, ảnh, email) → Onboarding; backend tạo tài khoản với `google_sub` của Google; tạo kế hoạch → Lịch sử "Đang dùng" → xem lại; đổi món → bản lưu trên server đổi theo; xoá tài khoản → server còn 0 tài khoản, 0 plan. Tài liệu F04 ghi kết quả này (`edit_docs8b.py`).

**Chưa kiểm được:** đăng nhập Google thật trên Android, macOS (PLAN 9.4). Bản Windows chỉ build trên CI.

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P16 | `setState(() => _mode = …)` trả về `Future` → Flutter ném lỗi khi bấm "Thử lại" | Thân hàm dạng khối (F02) |
| P17 | Fixture `history` chứa đúng `plan_id` của fixture `generate_plan` | Test ghi chú Q4 dùng danh sách khác (F02) |
| P18 | 401 khi tải lịch sử: đăng xuất xảy ra trước `catch` → lỗi bị bỏ như của tài khoản cũ | Nhánh `on UnauthorizedException` riêng (F01) |
| P19 | Test 409 của bảng feedback (giai đoạn 7) đỏ vì khách giờ bị hỏi lại | Test bấm "Thay kế hoạch" (F02) |
| P20 | Hai file test cũ chưa format | Chỉ thêm phần mới (F01, F02) |
| P21 | `bmgr`: bản debug vượt hạn mức; app bị force-stop không được sao lưu | Kiểm bằng bản release, mở app trước (F03) |
| P22 | Bản HEAD sao lưu `FlutterSharedPreferences.xml` (token); bản mới thì không | Giữ luật (F03, #37) |
| P23 | Keychain sharing macOS làm `flutter build macos` không ký thất bại | Không commit; SETUP 3.4 (F03, F04) |
| P24 | `flutter pub get` sửa `macos/Flutter/GeneratedPluginRegistrant.swift`; build macOS sinh hai `Package.resolved` không bị ignore | Commit cả ba (F01) |
| P25 | Thử Google thật: AirPlay Receiver của macOS nghe cổng 5000 (cả IPv4, IPv6) — `localhost:5000` ra trang 403 của AirTunes | SETUP 3.2 gợi ý cổng 5050, `-d web-server` + Chrome thường (F04) |
| P26 | Thử bằng công cụ điều khiển Chrome: cửa sổ bị che → `visibilityState = hidden`, Flutter web dừng vẽ giữa chuyển trang/hộp thoại (thao tác vẫn chạy) | Ghi vào [[flutter-ui]]; kiểm kết quả ở backend/DB (F04) |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với quyết định của brainstorm. Ràng buộc được test khoá lại:

| Ràng buộc | Test |
|---|---|
| #10, #21 demo chỉ khi backend `mock`, không mật khẩu | `auth_provider_test.dart` (`loginMode()`), `login_panel_test.dart` (backend Google → không có ô email) |
| #12, #28 không lưu/log dữ liệu nhạy cảm | `history_provider_test.dart` (không ghi khoá nào), `google_auth_test.dart` (mô tả lỗi của SDK không lộ ra) |
| #17 test không gọi Google thật | `FakeGoogleAuth`; `google_auth_test.dart` chạy `PluginGoogleAuth` trên `GoogleSignInPlatform` giả |
| #22 401 | `history_provider_test.dart`, `history_screen_test.dart`, `dashboard_screen_test.dart`, `feedback_sheet_test.dart`, `widget_test.dart` |
| #35 lưu tạm | `widget_test.dart` (bảng đăng nhập + email, `restartAndRestore()`) |
| #36 khoá feedback | không đổi; `feedback_sheet_test.dart` — lựa chọn còn sau khi đăng nhập lại |
| #37 (mới) | toàn bộ test của F01–F02 ở trên; sao lưu Android kiểm tay (F03) |

## Danh sách file

- `specs/F01-auth-logic.md`
- `specs/F02-auth-history-ui.md`
- `specs/F03-platform-and-device.md`
- `specs/F04-docs.md`
- `project.json`
- `README.md`
