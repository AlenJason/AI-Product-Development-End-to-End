# Giai đoạn 6 — Frontend: nối MVP (FR-1 → FR-3) — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-6-connect-mvp.md` (quyết định Q1–Q4 ở mục 8; đầu vào D5, D6 trong `docs/PLAN.md`)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F06, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. CI chạy sau khi push (`Backend CI`, `Frontend CI`).

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Backend: hồ sơ an toàn (tuổi ≥ 18; không Giảm mỡ khi thiếu cân / mang thai; trường `pregnant_or_breastfeeding`) + fixture + model Dart `Profile` | API + model | 6.9 (D6 A1–A3, Q1) |
| F02 | Backend: độ khó động tác theo tuổi, mức vận động, thai kỳ — mọi đường ra động tác; prompt; `ai_workspace` | API | 6.10 (D6-A4, Q2) |
| F03 | App: luật hồ sơ, danh sách hạn chế (D5), lịch ngày (D6-B1), `PlanProvider` (lịch, bản nháp), `GroceryProvider` | UI (logic) | 6.11, nền cho 6.1–6.5 |
| F04 | App: Onboarding 3 bước, màn chờ, Kế hoạch (đổi món / đổi bài gọi API), Đi chợ, Cá nhân, khung app, test | UI | 6.1–6.7, 7.1, 7.2 (Q3, Q4) |
| F05 | Tên app, icon vẽ bằng code, màn khởi động, thanh hệ thống | Cấu hình nền tảng | 6.8 |
| F06 | BRD v2.6.0, wiki (#30–#32), CLAUDE.md, README, PLAN | Docs | — |

## Thứ tự thực hiện

F01 → F02 → F03 → F04 → F05 → F06. F01 đổi hợp đồng nên sửa model Dart cùng lúc (#26). F03 chỉ thêm logic — giao diện cũ vẫn chạy ở mốc đó. F04 thay toàn bộ giao diện một lượt (thay một màn hình sẽ làm `main.dart` cũ không biên dịch).

## Code trong spec đã được chạy thật

Code của F01–F05 được viết và chạy trên bản sao repo trong thư mục nháp, rồi áp **lần lượt từng feature** lên bản `HEAD` (`git archive`) và chạy cổng kiểm ở mỗi mốc. Code trong spec chép nguyên văn từ bản đã chạy; file sửa được nhúng dạng diff so với `HEAD`. Sau F05, bản áp theo mốc trùng khít bản nháp.

| Mốc | Backend unit | Backend e2e | Flutter | Kiểm thêm |
|---|---|---|---|---|
| Hiện tại | 264 | 66 (7 file) | 44 | — |
| Sau F01 | 268 | 74 | 45 | fixture sinh lại giống bản nháp; typecheck, build, smoke, lint sạch |
| Sau F02 | 320 | 74 | 45 | fixture không đổi; `ai_workspace` biên dịch; prompt `ai_workspace` trùng từng dòng với backend (27 dòng) |
| Sau F03 | | | 67 | `flutter analyze` sạch |
| Sau F04 | | | 89 | `flutter analyze` sạch |
| Sau F05 | | | 89 | icon sinh lại trùng từng byte (39 file); `plutil`, `xmllint` sạch; APK debug và bản web build được |

**Kiểm ngược (mutation).** Cố ý làm hỏng 25 hành vi; lần nào cũng có test đỏ:

- backend: BMI làm tròn trước khi so; bỏ validator Giảm mỡ an toàn; tuổi tối thiểu vẫn 10; nam khai mang thai được; không cảnh báo mang thai; mang thai không hạ mức; không hạ mức kết quả Gemini; thực đơn mẫu không hạ mức; hạ mức mà bỏ qua chấn thương; đổi bài nhận động tác Gemini vượt mức; đau khớp thay bằng động tác vượt mức; prompt thiếu luật mức;
- app: chip không có trong nhãn backend; tắt công tắc vẫn gửi lựa chọn; app so BMI đã làm tròn; lịch giữ cả giờ phút; plan từ feedback ngày 3 bắt đầu hôm nay; nháp giống hồ sơ vẫn giữ; hồ sơ cũ bị chặn vẫn giữ plan; khoá đi chợ bỏ phần lượng; thiếu cân vẫn chọn được Giảm mỡ; Dashboard luôn mở ngày 1; 409 không có nút tạo mới; sửa hồ sơ ghi thẳng vào hồ sơ của plan; màn chờ lỗi không cho thử lại.

Hai đột biến ban đầu lọt qua — "hạ mức mà bỏ qua chấn thương" (với kho hiện tại ứng viên đầu tiên của mọi nhóm cơ đều không có tag) và "thiếu cân vẫn chọn được Giảm mỡ" (nút tiếp tục vẫn khoá nên test không phân biệt) — đã thêm test cho đúng hai chỗ đó.

**Chạy trên máy ảo Android 16 (Pixel 8, API 36), backend bản build ở chế độ giả lập:**

| Thử | Kết quả |
|---|---|
| `flutter test integration_test -d emulator-5554` | 3/3 xanh, gồm luồng thao tác giao diện: điền Onboarding → backend thật tạo plan → Dashboard → đổi món |
| Onboarding cao 160 cm / 42 kg | bước 2 khoá "Giảm mỡ" kèm câu thiếu cân |
| Dị ứng hải sản + trứng, đau gối | Dashboard: bữa sáng có mặt, buổi tập thay Jumping Jacks → "Đi bộ tại chỗ", chống đẩy quỳ gối → "Chống đẩy nghiêng trên ghế" |
| Launcher, màn khởi động | "SmartFit AI", icon mới; màn khởi động nền xanh |
| Thanh trạng thái | sáng, thấy giờ và pin (trước đó bị tô đen) |

Chưa build iOS/macOS (máy không có Xcode). Chưa đo prompt mới bằng Gemini thật (chạy tay, tốn hạn mức — F02).

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P1 | **Thực đơn mẫu lệch macro so với mục tiêu** — ví dụ tinh bột 213/178 g (~120%), chất béo 36,7/53 g (~69%): thực đơn mẫu chỉ được nhân khẩu phần theo calo, backend không kiểm tỉ lệ macro. Vòng `MacroRing` kẹp ở 100% nên che phần vượt | Dashboard hiện phần trăm thật; ghi "Để sau" trong PLAN (cân macro thực đơn mẫu) |
| P2 | Tab Cá nhân: controller khởi tạo "lười" (`late`) được tạo lần đầu **trong** `dispose()` → đọc provider từ widget đã tháo → lỗi | Chỉ tạo form khi bấm "Sửa hồ sơ", huỷ sau frame |
| P3 | `Container` có màu nền bọc `SwitchListTile` / `CheckboxListTile` / `ExpansionTile` → Flutter báo lỗi ở bản debug | Dùng `Material` + `shape` (F04) |
| P4 | Thanh trạng thái Android bị tô đen: theme template không cho app vẽ nền thanh hệ thống | `windowDrawsSystemBarBackgrounds` + nền trong suốt + `edgeToEdge` (F04, F05) |
| P5 | Màn khởi động Android 12+ vẽ lớp trước icon (trắng) trên nền trắng → biến mất | `windowSplashScreenBackground` xanh (F05) |
| P6 | Script icon hỏng trên bản sạch vì thiếu thư mục `assets/icon` — bản nháp có sẵn nên không lộ | `mkdir -p` (F05) — kiểm theo mốc bắt được |
| P7 | Lỗi 400 của endpoint đổi món/feedback có câu kèm tiền tố `profile.` (ValidationPipe lồng) | App không dựa vào câu 400: khoá lựa chọn theo cùng ngưỡng và kiểm hồ sơ đã lưu (`profileProblems()`) |
| P8 | Test: `scrollUntilVisible` dừng khi widget đã được dựng dù còn ngoài mép; thiếu một `import` trong một file test hiện ra như "Dart compiler exited unexpectedly" ở **file khác** khi chạy song song | `scrollTo()` = cuộn + `ensureVisible`; chạy `flutter analyze` cả thư mục test trước |
| P9 | Dart 3.13 cho phần tử `?x` trong list và tham số có tên riêng tư (`required this._api`) | Dùng trong `profile_rules.dart`, provider |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với quyết định của brainstorm. Ràng buộc được test khoá lại:

| Ràng buộc | Test |
|---|---|
| #12 cờ mang thai không trong response | `generate-plan.e2e-spec.ts` |
| #15 không thêm lần gọi Gemini khi hạ mức | `plan.service.spec.ts` (Gemini được gọi đúng 1 lần) |
| #17 test không gọi dịch vụ thật | Gemini giả, `FakeBackend`; integration test tự dừng khi backend có khoá |
| #24 luật hồ sơ áp mọi endpoint; đổi món gửi hồ sơ của plan | `adjust.e2e-spec.ts`; `plan_provider_test.dart` |
| #26 fixture + model đổi cùng lúc | `contract-fixtures.e2e-spec.ts`, `contract_test.dart` |
| #30 hồ sơ an toàn | `profile-safety.spec.ts`, e2e, `profile_rules_test.dart`, `onboarding_screen_test.dart` |
| #31 mức động tác mọi đường | `exercise-level.spec.ts`, `sample-plan.spec.ts`, `plan.service.spec.ts`, `exercise-swap.service.spec.ts`, `workout-rules.spec.ts`, `gemini-prompt.spec.ts` |
| #32 chip ⊆ nhãn backend | `restriction_options_test.dart` + fixture `restriction_labels.json` |

## Việc chuyển sang giai đoạn sau

- **Giai đoạn 7:** bảng feedback cuối ngày theo D2, khoá sau khi gửi; `safetyWarning` nổi bật (7.1, 7.2 đã làm ở đây).
- **Giai đoạn 8:** đăng nhập, tab Lịch sử.
- **Đo lại Gemini** với prompt mới (`npm run measure:gemini`, chạy tay).
- **Để sau:** cân macro thực đơn mẫu (P1), cùng các mục "Để sau" của D6.

## Danh sách file

- `specs/F01-backend-profile-safety.md`
- `specs/F02-backend-exercise-level.md`
- `specs/F03-app-logic.md`
- `specs/F04-app-screens.md`
- `specs/F05-branding.md`
- `specs/F06-docs.md`
- `project.json`
- `README.md`
