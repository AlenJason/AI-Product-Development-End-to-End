# Brainstorm: Giai đoạn 7 — Frontend: feedback cuối ngày (FR-5)
**Source:** `docs/PLAN.md` (giai đoạn 7, bước 7.3; quyết định D2, D7, D8) + `BRD.md` v2.7.0 (FR-5.1–FR-5.3, FR-2.4, mục 6.4, NFR-2, NFR-7)
**Date:** 2026-09-29

## 1. Phạm vi

Giai đoạn 7 chỉ còn bước **7.3** — 7.1 (đổi món) và 7.2 (đổi bài) đã làm ở giai đoạn 6 (quyết định Q3 giai đoạn 6).

- Bảng feedback cuối ngày theo D2 / FR-5.1: cường độ (chọn 1), tình trạng cơ thể (chọn nhiều, có dấu hiệu nguy hiểm), ăn uống (chọn 1).
- Gửi qua `PlanProvider.submitFeedback()` → `POST /api/v1/feedback`; thay plan bằng plan server trả; ngày 3 → plan mới bắt đầu từ ngày mai (FR-2.4, FR-5.3 — provider đã làm).
- `safety_warning` → khuyến cáo ngừng tập, hỏi ý kiến bác sĩ, hiện nổi bật (FR-5.2, #14).
- **Khoá nút sau khi đã gửi cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa (BRD 6.4).
- Không có câu báo viết sẵn kiểu "AI đã cân đối lại thực đơn Ngày 2!" — chỉ báo điều thật sự đã đổi.

Ngoài phạm vi: nhắc feedback bằng thông báo đẩy (chưa có package), sửa backend (hợp đồng 6.4 đủ dùng), đăng nhập/lịch sử (giai đoạn 8).

## 2. Ngữ cảnh đã nạp

- **Wiki:** `INDEX.md`, `wiki-triggers.md`; khớp từ khoá → [[swap-and-feedback]] (feedback, dấu hiệu nguy hiểm), [[flutter-ui]] (Flutter, dashboard, provider, `shared_preferences`, ngày trong plan), [[plan-data-contract]], [[auth-and-history]] (endpoint), [[critical-constraints]] (đọc hết — việc này gọi API và đụng dữ liệu sức khoẻ).
- **Backend feedback** (`FeedbackService`, `workout-rules.ts`, [[swap-and-feedback]]): ưu tiên `danger_sign` (ngày kế tiếp = `REST_WORKOUT` "Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ", không cân đối món) → `joint_pain` (thay `jumping`/`kneeling`/`knee_bend`) → `hard`/`fatigued` (−1 hiệp, thời lượng ×0,75) → `sore` (−1 hiệp nhóm cơ vừa tập + giãn cơ) → `easy` + chỉ `normal` (+1 hiệp). Ăn uống: có Gemini thì lập lại 3 bữa; không có → giữ món + cảnh báo `mealsNotRebalanced` trong `plan.warnings`. `normal` đi cùng trạng thái khác thì bị bỏ (`normalizeFeedback()`).
- **App đã có:** `FeedbackAnswers` (`dayNumber`, `intensity`, `bodyStates`, `eating`), `FeedbackResult` (`plan`, `safetyWarning`), enum `Intensity`/`BodyState`/`Eating` (`codes.dart`), `PlanProvider.submitFeedback()` (gửi hồ sơ **của plan** — #24, không 409 khi có bản nháp; plan mới từ ngày 3 → lịch bắt đầu ngày mai), `ApiClient.submitFeedback()` (timeout 60 s — #28), fixture `feedback.json`, `feedback_danger.json`, test provider/ApiClient cho feedback. Chưa có: giao diện, trạng thái "đã gửi".
- **Ràng buộc áp dụng:** #12, #28 (không log body; câu trả lời feedback là dữ liệu sức khoẻ — không lưu xuống máy), #14 (dấu hiệu nguy hiểm), #15/#28 (chờ tới 40 s khi ngày 3 gọi Gemini), #24 (plan + hồ sơ của plan gửi nguyên), #26 (không đổi hợp đồng → không đụng model), #35 (dữ liệu đang nhập dở chỉ lưu tạm bằng state restoration), D7 (Android, web, Windows, macOS; `AppFrame` giữ bảng trong cột 640).

## 3. Phát hiện — kiểm chứng ngày 2026-09-29

| # | Phát hiện | Hệ quả |
|---|---|---|
| P1 | Bảng feedback cũ (`feedback_bottom_sheet.dart`, có câu "AI đã cân đối lại thực đơn Ngày 2!", lựa chọn không theo D2) đã bị xoá ở giai đoạn 6; `lib/` không còn câu viết sẵn đó | Làm mới hoàn toàn; phần "bỏ câu viết sẵn" của 7.3 coi như đã xong, nhưng bảng mới phải báo đúng điều đã đổi |
| P2 | Backend không trả bản tóm tắt thay đổi; cảnh báo `mealsNotRebalanced` chỉ nằm trong `warnings` của plan trả về và **mất ở lần đổi món/bài sau** (`rebuildPlan()` tính lại cảnh báo từ hồ sơ) | App tự so plan trước/sau để tóm tắt ngay lúc gửi — không dựa vào `warnings` về sau |
| P3 | `DashboardScreen` được khoá theo `plan_id` (`ValueKey`) → feedback ngày 3 trả plan mới làm Dashboard dựng lại từ đầu | Không đặt trạng thái của bảng feedback (route khôi phục, lựa chọn đang chọn) trong Dashboard; đặt ở `MainShell` hoặc trong chính bảng |
| P4 | `ListView` của Dashboard chỉ dựng phần đang hiện; widget cuộn ra ngoài bị huỷ | Form đặt thẳng trong danh sách (hướng B) sẽ mất lựa chọn khi cuộn nếu không giữ state ở chỗ khác |
| P5 | Flutter có `ModalBottomSheetRoute`, `Navigator.restorablePush`, `RestorableRouteFuture` (kiểm trong SDK 3.47.5) | Bảng trượt từ dưới lên khôi phục được sau khi hệ thống tắt app (#35) |
| P6 | Plan chỉ có ngày 1–3; `todayNumber` có thể < 1 (plan từ feedback ngày 3 bắt đầu ngày mai) hoặc > 3 (plan đã hết) | Cần luật ngày nào được đánh giá — BRD chỉ nói "cuối ngày", chưa nói quên gửi hôm qua thì sao |
| P7 | Feedback ngày 3 gọi `generatePlan()` — có Gemini thì chờ 10–40 s | Bảng phải có trạng thái chờ và câu "có thể mất tới 40 giây", giống màn chờ tạo plan |

## 4. Các hướng tiếp cận

### Hướng A — Bảng trượt từ dưới lên, mở từ thẻ "Đánh giá cuối ngày" *(khuyến nghị)*

Cuối tab mỗi ngày (sau buổi tập) có thẻ "Hôm nay thế nào? Đánh giá 1 phút để điều chỉnh ngày mai" nếu ngày đó được đánh giá; bấm → bảng trượt (`ModalBottomSheetRoute`, `isScrollControlled`) với 3 câu hỏi. Gửi, chờ, xem kết quả đều trong bảng. `MainShell` giữ `RestorableRouteFuture` mở bảng (không bị dựng lại khi plan đổi — P3); bảng tự giữ lựa chọn bằng `RestorationMixin` (#35).

- **+** Đúng kiểu thiết kế gốc (bảng cũ cũng là bottom sheet); tập trung một việc; không làm dài danh sách ngày; kết quả và cảnh báo an toàn hiện ngay chỗ người dùng vừa bấm.
- **−** Khôi phục route phức tạp hơn một chút (builder tĩnh, tham số chỉ là số ngày).

### Hướng B — Thẻ mở rộng ngay trong tab ngày

Thẻ cuối tab mở ra 3 câu hỏi tại chỗ.

- **+** Không có route; dễ test.
- **−** P4: cuộn ra ngoài là mất lựa chọn trừ khi đưa state lên Dashboard — mà Dashboard bị dựng lại khi plan đổi (P3). Danh sách ngày dài thêm; kết quả phải hiện ở giữa danh sách.

### Hướng C — Màn hình riêng

Nút ở đầu Dashboard → đẩy màn "Đánh giá ngày X".

- **+** Nhiều chỗ, dễ khôi phục (route riêng).
- **−** Nặng tay cho form "1 phút" (FR-5.1); thêm một kiểu điều hướng mới trong app không có router.

### Đối chiếu ràng buộc

| Ràng buộc | A | B | C |
|---|---|---|---|
| #14 dấu hiệu nguy hiểm nổi bật | ✓ trong bảng | ✓ | ✓ |
| #35 lựa chọn đang dở khôi phục được | ✓ (P5) | ⚠ phải đưa state lên Dashboard (P3, P4) | ✓ |
| #12/#28 không lưu câu trả lời xuống máy | ✓ | ✓ | ✓ |
| D7 cửa sổ rộng (`AppFrame`) | ✓ bảng nằm trong cột 640 | ✓ | ✓ |
| FR-5.1 "1 phút" | ✓ | ✓ | ⚠ |

## 5. Thiết kế đề xuất (hướng A)

### 5.1 Ngày nào được đánh giá, khoá sau khi gửi

- `PlanProvider` thêm trạng thái "đã gửi feedback" theo plan: khoá `smartfit.feedback.v1` = `{ "plan_id", "days": [1, 2] }` — chỉ số ngày, **không** lưu câu trả lời (#12). Plan mới (tạo mới, feedback ngày 3) → trống; đổi món/bài giữ nguyên `plan_id` → giữ khoá. Bản lưu hỏng hoặc của plan khác → coi như chưa gửi ngày nào.
- `submitFeedback()` đánh dấu ngày đã gửi **sau khi** server trả plan (lỗi mạng → không khoá, người dùng gửi lại được).
- Ngày `d` được đánh giá khi: chưa gửi, `d ≤ hôm nay`, và `d ≥ hôm nay − 1` (quên gửi tối qua vẫn gửi sáng nay — điều chỉnh đúng hôm nay) hoặc `d = 3` khi plan đã hết (feedback ngày 3 tạo plan mới). Ngày tương lai, ngày quá cũ (điều chỉnh một ngày đã qua là vô nghĩa) → không có thẻ. → **Câu hỏi Q2.**
- Thẻ ở ngày đã gửi: "Đã đánh giá ngày d" (không bấm được).

### 5.2 Bảng feedback

- 3 câu hỏi đúng chữ FR-5.1; nút gửi khoá tới khi đủ 3 câu.
- "Bình thường" loại trừ các trạng thái khác (chọn nó bỏ các ô khác và ngược lại) — khớp `normalizeFeedback()` ở backend, người dùng không gửi tổ hợp vô nghĩa.
- Chọn ⚠️ "Chóng mặt, khó thở bất thường, đau ngực" → hiện **ngay** ô đỏ khuyến cáo ngừng tập, hỏi bác sĩ, gọi 115 nếu nặng — có cả khi mất mạng (không chờ server). Câu hỏi ăn uống vẫn hỏi (backend bỏ qua khi có dấu hiệu nguy hiểm — #14).
- Gửi: nút thành vòng xoay, khoá các nút; ngày 3 có câu "có thể mất tới 40 giây" (P7). Lỗi → câu của `ApiException`, giữ nguyên lựa chọn để gửi lại; 409 → câu của server + "Tạo kế hoạch mới" (đóng bảng, gọi `onCreatePlan`).
- Kết quả thay form trong bảng:
  - có `safety_warning` → ô đỏ với đúng câu của server, nút "Tôi đã hiểu";
  - tóm tắt thay đổi do app tự so plan trước/sau (P2) — hàm thuần `describeFeedbackChanges(before, after, day)`: ngày kế tiếp nghỉ ngơi / đổi động tác (tên cũ → mới) / đổi số hiệp / thêm giãn cơ / đổi thời lượng; thực đơn cân đối lại (tổng calo trước → sau) hoặc giữ nguyên kèm lý do (`mealsNotRebalanced` có trong `warnings` vừa trả); không đổi gì → nói đúng như vậy. Ngày 3 → "Đã tạo kế hoạch 3 ngày mới, bắt đầu từ <Thứ, ngày/tháng>". → **Câu hỏi Q4.**
- Lựa chọn đang dở khôi phục được bằng `RestorationMixin` (#35); đã gửi xong mà app bị tắt → mở lại thấy thẻ "Đã đánh giá".

### 5.3 Hiển thị sau khi gửi

- Plan cập nhật qua provider (Dashboard tự vẽ lại). Ngày 3 → Dashboard dựng lại với plan mới, dải "Kế hoạch bắt đầu từ …" đã có.
- Cảnh báo an toàn: ngoài ô đỏ trong bảng, ngày nghỉ đã tự nói rõ ("Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ", "Đi bộ nhẹ (chỉ khi đã hết chóng mặt, khó thở, đau ngực)"). → **Câu hỏi Q3.**

### 5.4 Test

- Unit: `describeFeedbackChanges()` (dùng `feedback.json`, `feedback_danger.json` làm "sau"), luật ngày được đánh giá, lưu/đọc khoá đã gửi (hỏng, plan khác, plan mới).
- Widget: bảng (khoá nút gửi, "Bình thường" loại trừ, ô đỏ khi chọn dấu hiệu nguy hiểm mà không cần mạng, gửi đúng `FeedbackAnswers`, kết quả, lỗi giữ lựa chọn, 409), thẻ trên Dashboard (hiện/ẩn theo ngày, khoá sau khi gửi — cả sau khi mở lại app), khôi phục (`restartAndRestore()`), không ghi câu trả lời xuống máy.
- Integration trên máy ảo Android / macOS: thao tác gửi feedback thật với backend giả lập.
- Kiểm ngược (mutation) như các giai đoạn trước.

## 6. Edge case

| Tình huống | Xử lý |
|---|---|
| Gửi hai lần (bấm nhanh, mạng chậm) | `PlanProvider.busy` bỏ qua lần hai; sau khi xong thì khoá theo ngày |
| Mất mạng / hết giờ | Không khoá, giữ lựa chọn, báo câu của `ApiException` |
| Server đã nhận nhưng app bị tắt trước khi lưu plan | App vẫn giữ plan cũ (app là nơi giữ plan; backend không lưu trạng thái) → gửi lại hợp lệ. Đã đăng nhập thì plan trong lịch sử đã cập nhật — lệch nhẹ, chấp nhận (giai đoạn 8 xem lại) |
| Có bản nháp hồ sơ | Feedback dùng hồ sơ của plan (#24), không 409 |
| Plan bắt đầu ngày mai (sau feedback ngày 3) | Không ngày nào được đánh giá tới ngày mai |
| Plan đã hết (hôm nay > 3) | Ngày 3 chưa gửi → vẫn được đánh giá (tạo plan mới); dải "Kế hoạch 3 ngày đã hết" vẫn có |
| Dấu hiệu nguy hiểm + ngày 3 | Plan mới, ngày 1 là ngày nghỉ (backend); bảng hiện ô đỏ + "đã tạo kế hoạch mới" |
| Thực đơn mẫu, ăn nhiều/ít | Thực đơn giữ nguyên — tóm tắt nói rõ, không giả vờ đã cân đối |
| Web, Windows, macOS | Không có state restoration (D8) — tải lại trang/thoát app mất lựa chọn đang dở; khoá "đã gửi" vẫn lưu |
| Đổi ngày qua nửa đêm khi bảng đang mở | Bảng giữ số ngày lúc mở; gửi bình thường |

## 7. Câu hỏi mở — cần trả lời trước `/feature-plan`

- **Q1 — Kiểu giao diện:** (a) bảng trượt từ dưới lên, mở từ thẻ cuối tab ngày *(khuyến nghị — hướng A)*; (b) thẻ mở rộng tại chỗ; (c) màn hình riêng.
- **Q2 — Ngày nào được đánh giá:** (a) hôm nay và hôm qua (nếu chưa gửi), ngày 3 cả khi plan đã hết *(khuyến nghị)*; (b) chỉ hôm nay; (c) mọi ngày đã bắt đầu mà chưa gửi.
- **Q3 — Cảnh báo an toàn sau khi gửi:** (a) ô đỏ trong bảng, bấm "Tôi đã hiểu" mới đóng + ô đỏ hiện ngay lúc chọn (không cần mạng) *(khuyến nghị)*; (b) thêm dải cảnh báo đỏ ở ngày nghỉ tới hết ngày đó (phải lưu thêm trạng thái); (c) chỉ SnackBar.
- **Q4 — Báo kết quả:** (a) app tự so plan trước/sau, liệt kê điều đã đổi *(khuyến nghị)*; (b) một câu chung "Đã cập nhật ngày X"; (c) không báo, người dùng tự xem.

## 8. Quyết định (2026-09-29)

| # | Quyết định |
|---|---|
| Q1 | Bảng trượt từ dưới lên, mở từ thẻ "Đánh giá cuối ngày" ở cuối tab ngày (hướng A). `MainShell` giữ route khôi phục được; bảng tự giữ lựa chọn (#35) |
| Q2 | Được đánh giá: hôm nay và hôm qua nếu chưa gửi; ngày 3 vẫn được khi plan đã hết. Ngày tương lai, ngày quá cũ: không có thẻ |
| Q3 | Ô đỏ hiện ngay khi chọn dấu hiệu nguy hiểm (không cần mạng); sau khi gửi, ô đỏ với câu của server, bấm "Tôi đã hiểu" mới đóng. Không thêm dải cảnh báo lưu lại trên ngày nghỉ |
| Q4 | App tự so plan trước/sau, liệt kê điều đã đổi (hàm thuần `describeFeedbackChanges()`); ngày 3 báo plan mới bắt đầu từ ngày nào |

**Bước tiếp theo:** `/feature-plan phase-7-feedback`.
