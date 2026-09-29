# Giai đoạn 7 — Frontend: feedback cuối ngày (FR-5) — Plan

**Status:** ready
**Brainstorm:** `docs/superpowers/brainstorms/phase-7-feedback.md` (quyết định Q1–Q4 ở mục 8)
**Executor:** thực thi trực tiếp theo spec (`/feature-build` bản hiện tại chỉ nhận cấu trúc Next.js).
**Commit:** một commit + push cho cả giai đoạn sau F03, lên nhánh đang làm việc (hiện là `Thien-Source`), không mở pull request. CI chạy sau khi push (`Frontend CI` — analyze, test, build 4 nền tảng).

## Features

| ID | Tên | Phạm vi | Bước PLAN |
|---|---|---|---|
| F01 | Luật ngày được đánh giá (`canReviewDay()`), khoá "đã gửi" (`smartfit.feedback.v1`), tóm tắt thay đổi (`describeFeedbackChanges()`) | UI (logic) | 7.3 (Q2, Q4) |
| F02 | Bảng feedback, thẻ trên Dashboard, route khôi phục được trong `MainShell` | UI | 7.3 (Q1, Q3) |
| F03 | Integration test trên máy ảo Android và macOS; BRD v2.7.1, wiki #36, `CLAUDE.md`, README, PLAN | Thiết bị + Docs | — |

Backend không đổi: hợp đồng BRD 6.4 đủ dùng, không cần `fixtures:update`.

## Thứ tự thực hiện

F01 → F02 → F03. F01 chỉ thêm logic — giao diện ở mốc đó chưa đổi.

## Code trong spec đã được chạy thật

Code của F01–F03 được viết và chạy trên bản sao repo trong thư mục nháp, rồi áp **lần lượt từng feature** lên bản `HEAD` (`git archive`) và chạy cổng kiểm ở mỗi mốc. Code trong spec chép nguyên văn từ bản đã chạy; file sửa được nhúng dạng diff so với `HEAD`. Sau F03, bản áp theo mốc trùng khít bản nháp.

| Mốc | Flutter | Kiểm thêm |
|---|---|---|
| Hiện tại | 96 | — |
| Sau F01 | 115 | `flutter analyze` sạch |
| Sau F02 | 125 | `flutter analyze` sạch; APK debug, web, macOS debug build được |
| Sau F03 | 125 | integration test 3/3 trên máy ảo Android 16 (Pixel 8) và 3/3 trên macOS, backend giả lập — gồm luồng giao diện gửi feedback ngày 1 |

**Kiểm ngược (mutation).** Cố ý làm hỏng 24 hành vi; lần nào cũng có test đỏ, không đột biến nào lọt ngay lần đầu:

- luật ngày: ngày quá cũ vẫn được đánh giá; plan đã hết không gửi được ngày 3; ngày tương lai được đánh giá; đã gửi vẫn được đánh giá lại;
- khoá: không lưu xuống máy; khoá cả khi server lỗi; tạo plan mới không xoá khoá; plan mới từ ngày 3 giữ khoá cũ; đọc khoá của plan khác;
- tóm tắt: dấu hiệu nguy hiểm liệt kê từng động tác; ăn nhiều mà món không đổi thì im lặng; plan mới không nói ngày bắt đầu; không đổi gì thì không nói gì;
- bảng: "Bình thường" không loại trừ; khuyến cáo chỉ hiện sau khi gửi; Back đóng được cảnh báo an toàn; gửi được khi chưa đủ 3 câu; 409 không có nút tạo mới; ngày 3 không báo chờ 40 giây; báo chung chung thay cho điều đã đổi;
- khôi phục: câu trả lời không khôi phục được; bảng không khôi phục được;
- thẻ: thẻ "đã gửi" biến mất; thẻ hiện cả khi không được đánh giá.

## Phát hiện khi lập plan (ngoài brainstorm)

| # | Phát hiện | Xử lý |
|---|---|---|
| P8 | Hàng "Đã gửi đánh giá ngày 1" tràn khi chữ rộng (font test; ngoài đời khi phóng chữ 130%) | `Expanded` (F02) |
| P9 | `FilterChip`/`ChoiceChip` bọc `RawChip` — cả hai là `SelectableChipAttributes` | Test lấy tổ tiên gần nhất (F02) |
| P10 | Danh sách Dashboard dựng dần: kéo một lần chưa tới cuối thật | Test nhảy tới `maxScrollExtent` tới khi hết tăng (F02) |
| P11 | Fixture `generate_plan` giữ nguyên `plan_id` — khoá "đã gửi" không bị xoá khi tạo plan mới nếu chỉ dựa vào `plan_id` đổi; Dashboard mở lại ở vị trí cuộn cũ | `generate()` xoá khoá tường minh (F01); test dùng `plan_id` mới như server thật (F02) |
| P12 | macOS: SnackBar đè thẻ cuối trang khi cửa sổ thấp | Integration test ẩn SnackBar trước khi bấm (F03) |

## Ràng buộc từ wiki

Không có ràng buộc nào mâu thuẫn với quyết định của brainstorm. Ràng buộc được test khoá lại:

| Ràng buộc | Test |
|---|---|
| #12, #28 không lưu câu trả lời, không log | `plan_provider_test.dart` (khoá chỉ có số ngày), `widget_test.dart` (khoá `shared_preferences` không đổi khi đang chọn) |
| #14 dấu hiệu nguy hiểm | `feedback_sheet_test.dart`, `feedback_summary_test.dart` |
| #24 hồ sơ của plan | có sẵn (`plan_provider_test.dart`) |
| #35 lưu tạm, khôi phục | `widget_test.dart` (`restartAndRestore()`) |
| #36 (mới) ngày được gửi, khoá sau khi server trả plan | `feedback_rules_test.dart`, `plan_provider_test.dart`, `dashboard_screen_test.dart` |

## Danh sách file

- `specs/F01-feedback-logic.md`
- `specs/F02-feedback-sheet.md`
- `specs/F03-device-and-docs.md`
- `project.json`
- `README.md`
