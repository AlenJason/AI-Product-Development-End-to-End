# F03 — Chạy trên thiết bị, tài liệu

## Feature

- `integration_test/backend_smoke_test.dart`: bài thao tác giao diện đi tiếp sau đổi món → mở thẻ "Đánh giá ngày 1", chọn "Rất mệt", "Căng mỏi cơ", "Đúng thực đơn", gửi, thấy "Đã lưu đánh giá ngày 1" và "Ngày 2: giảm số hiệp…", "Xong" → thẻ "Đã gửi đánh giá ngày 1". Chạy tay trên máy ảo Android và macOS với backend giả lập (#17).
- BRD v2.7.1: FR-5.1 phần app (ngày được gửi, khoá, "Bình thường" loại trừ, khuyến cáo ngay, báo điều đã đổi).
- PLAN: tích 7.3, dòng "Chi tiết"; mục "Hiện trạng".
- Wiki: ràng buộc #36; [[flutter-ui]] (cấu trúc, màn feedback, khoá lưu, khôi phục, số test); [[swap-and-feedback]] (phần app); trigger; log. `CLAUDE.md`, README (changelog).

**Phát hiện khi lập plan:**

| # | Phát hiện | Xử lý |
|---|---|---|
| P12 | Trên macOS (cửa sổ 800×600 đã được khôi phục), SnackBar "Đã đổi bữa sáng sang…" nổi đè thẻ feedback cuối trang → cú bấm trúng SnackBar, bảng không mở | Test ẩn SnackBar trước khi bấm (`hideCurrentSnackBar()`); người dùng thật chờ 4 s hoặc bấm lại |

## Scope

- `frontend_app/integration_test/backend_smoke_test.dart` (sửa)
- `BRD.md`, `docs/PLAN.md`, `docs/knowledge/wiki/critical-constraints.md`, `flutter-ui.md`, `swap-and-feedback.md`, `wiki-triggers.md`, `log.md`, `CLAUDE.md`, `README.md`

## Implementation

### API Routes

Không có.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#17** integration test tự dừng khi backend có khoá Gemini hoặc không ở `auth_mode: mock`.
- BRD "Approved": làm rõ FR-5.1 → nâng v2.7.1, ghi "bổ sung bản 2.7.1".

## Definition of Done

- [ ] `flutter test integration_test -d emulator-5554` → `+3: All tests passed!`
- [ ] `flutter test integration_test -d macos` → `+3: All tests passed!`
- [ ] `grep -c '^| 36 |' docs/knowledge/wiki/critical-constraints.md` → `1`
- [ ] `grep -c '^- \[x\] \*\*7\.3\*\*' docs/PLAN.md` → `1`

## Test Checklist

1. **@device**: Android 16 (máy ảo Pixel 8) và macOS — luồng giao diện gửi feedback thật qua backend giả lập, khoá ngày sau khi gửi
2. **@docs**: ràng buộc #36, 7.3 đã tích, BRD v2.7.1
3. **@auth**, **@timeout**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Integration test

```diff
--- a/frontend_app/integration_test/backend_smoke_test.dart
+++ b/frontend_app/integration_test/backend_smoke_test.dart
@@ -1,4 +1,4 @@
-import 'package:flutter/widgets.dart';
+import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:integration_test/integration_test.dart';
 import 'package:my_ai_app/config/api_config.dart';
@@ -14,7 +14,7 @@
 import 'package:my_ai_app/services/api_exception.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 
-import '../test/app_harness.dart' show fillOnboarding;
+import '../test/app_harness.dart' show fillOnboarding, scrollTo;
 
 // Chạy TAY trên máy ảo hoặc điện thoại thật, khi backend_api đang chạy ở chế độ giả lập — không chạy trong CI
 // (`flutter test` chỉ chạy thư mục test/):
@@ -111,8 +111,9 @@
     await expectLater(closedPort.health(), throwsA(isA<NetworkException>()));
   });
 
-  // Thao tác giao diện thật trên thiết bị (giai đoạn 6): Onboarding → backend thật tạo plan → Dashboard → đổi món.
-  testWidgets('giao diện trên thiết bị: điền Onboarding → plan thật → Dashboard → đổi món', (tester) async {
+  // Thao tác giao diện thật trên thiết bị (giai đoạn 6, 7): Onboarding → backend thật tạo plan → Dashboard → đổi món
+  // → feedback cuối ngày 1 (bảng trượt, báo điều đã đổi, khoá ngày).
+  testWidgets('giao diện trên thiết bị: Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1', (tester) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
     final api = ApiClient(baseUrl: resolveApiBaseUrl());
@@ -129,6 +130,24 @@
 
     await tester.tap(find.text('Đổi món').first);
     await pumpUntil(tester, find.textContaining('Đã đổi bữa sáng sang'));
+    // SnackBar nổi đè lên thẻ cuối trang khi cửa sổ thấp (macOS 800×600) — ẩn trước khi bấm.
+    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
+    await tester.pumpAndSettle();
+
+    await scrollTo(tester, find.text('Đánh giá ngày 1'));
+    await tester.tap(find.text('Đánh giá ngày 1'));
+    await tester.pumpAndSettle();
+    for (final label in ['Rất mệt', 'Căng mỏi cơ', 'Đúng thực đơn', 'Gửi và điều chỉnh ngày 2']) {
+      await tester.ensureVisible(find.text(label));
+      await tester.tap(find.text(label));
+      await tester.pump();
+    }
+    await pumpUntil(tester, find.text('Đã lưu đánh giá ngày 1'));
+    expect(find.textContaining('Ngày 2: giảm số hiệp'), findsOneWidget);
+    await tester.tap(find.text('Xong'));
+    await tester.pumpAndSettle();
+    await scrollTo(tester, find.text('Đã gửi đánh giá ngày 1'));
+    expect(plans.feedbackDays, {1});
     await tester.pumpWidget(const SizedBox());
     await prefs.clear();
   });
```

```bash
cd backend_api && GEMINI_API_KEY= npm run start:dev   # backend giả lập
cd frontend_app
flutter test integration_test -d emulator-5554   # +3: All tests passed!
flutter test integration_test -d macos           # +3: All tests passed!
```

### Task 2 — Tài liệu

```diff
--- a/BRD.md
+++ b/BRD.md
@@ -3,8 +3,8 @@
 **Tên sản phẩm:** Trợ lý AI Gợi ý & Điều chỉnh Thực đơn, Lịch tập Thông minh  
 **Môn học:** AI Product Development End-to-End (Đồ án Kỹ sư / Cử nhân Năm 4)  
 **Đơn vị thực hiện:** Trường Đại học Công nghệ Thông tin và Truyền thông Việt - Hàn (VKU)  
-**Phiên bản:** 2.7.0 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
-**Ngày cập nhật:** 29/09/2026  
+**Phiên bản:** 2.7.1 (Dành cho Sinh viên thực hành: Flutter & NestJS)  
+**Ngày cập nhật:** 30/09/2026  
 **Trạng thái:** Đã phê duyệt (Approved)  
 
 ---
@@ -151,6 +151,7 @@
 | Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều) | Bình thường · Căng mỏi cơ · Đau khớp (gối, cổ tay, vai…) · Uể oải, thiếu ngủ · ⚠️ Chóng mặt, khó thở bất thường, đau ngực |
 | Ăn uống (chọn 1) | Đúng thực đơn / Ăn nhiều hơn / Ăn ít hơn hoặc bỏ bữa |
 
+* **FR-5.1 — trên app** *(bổ sung bản 2.7.1)*: thẻ "Đánh giá cuối ngày" ở cuối mỗi ngày mở bảng 3 câu hỏi. Được gửi cho hôm nay và hôm qua (quên gửi tối qua thì sáng nay vẫn gửi, điều chỉnh đúng hôm nay); ngày 3 vẫn gửi được khi plan đã hết; ngày chưa tới hoặc quá cũ thì không. Mỗi ngày gửi một lần — gửi xong app khoá (máy chỉ ghi số ngày đã gửi, không ghi câu trả lời). "Bình thường" không chọn cùng trạng thái khác. Chọn dấu hiệu nguy hiểm → khuyến cáo hiện ngay, không cần mạng. Gửi xong, app báo đúng điều đã đổi ở ngày kế tiếp (nghỉ ngơi, thay động tác, số hiệp, thời lượng, thực đơn cân đối lại hay giữ nguyên); ngày 3 báo plan mới bắt đầu từ ngày nào.
 * **FR-5.2:** Điều chỉnh ngày kế tiếp:
   * Bài tập theo quy tắc cố định (không cần AI): Nhẹ nhàng và cơ thể bình thường → mỗi động tác tăng 1 hiệp (tối đa 6); Rất mệt hoặc uể oải → mỗi động tác giảm 1 hiệp, buổi tập ngắn đi 25%; Căng mỏi cơ → giảm hiệp cho nhóm cơ vừa tập, thêm giãn cơ; Đau khớp → thay động tác bật nhảy, chống quỳ, gập gối chịu sức nặng (bản 2.7.0) bằng động tác cùng nhóm cơ không có kiểu tải đó.
   * Món ăn cân đối lại theo câu trả lời về ăn uống (cần AI): ăn nhiều hơn → ngày kế tiếp nhẹ hơn (khoảng 90% mục tiêu); ăn ít hơn hoặc bỏ bữa → giữ mục tiêu, không ăn bù. Không bao giờ hạ calo xuống dưới BMR. Chế độ giả lập giữ nguyên món và báo cho người dùng biết. *(chi tiết hoá ở bản 2.5.0)*
```

```diff
--- a/docs/PLAN.md
+++ b/docs/PLAN.md
@@ -32,7 +32,7 @@
 - [x] BRD v2.6.0 (MVP, tính năng nâng cao, tài khoản & lịch sử, hợp đồng API đầy đủ)
 - [x] Backend: `GET /health`, `POST /api/v1/generate-plan` (tính BMR/TDEE, gọi Gemini, kiểm tra khoảng calo, fallback), đổi món, đổi bài tập, feedback, đăng nhập Google (giả lập mặc định), lịch sử kế hoạch (SQLite), validate DTO, Swagger UI, CORS cho bản web
 - [x] `ai_workspace/`: script thử prompt Gemini
-- [x] Frontend: Onboarding 3 bước, màn chờ, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — đọc/ghi qua provider, không còn dữ liệu viết cứng (giai đoạn 6). Chưa có: bảng feedback cuối ngày (giai đoạn 7), đăng nhập và lịch sử (giai đoạn 8)
+- [x] Frontend: Onboarding 3 bước, màn chờ, kế hoạch 3 ngày (đổi món, đổi bài), đi chợ, hồ sơ — đọc/ghi qua provider, không còn dữ liệu viết cứng (giai đoạn 6); feedback cuối ngày (giai đoạn 7). Chưa có: đăng nhập và lịch sử (giai đoạn 8)
 - [x] Wiki nội bộ `docs/knowledge/`, `CLAUDE.md`
 
 ---
@@ -204,8 +204,10 @@
 
 - [x] **7.1** Nút "Đổi món" gọi API (hiện đang xoay vòng trong danh sách món viết cứng); thay cả plan và checklist bằng plan server trả về. 409 → báo hồ sơ đã đổi, gợi ý tạo plan mới; 422 → báo không còn món thay thế phù hợp *(làm ở giai đoạn 6, quyết định Q3)*
 - [x] **7.2** Nút "Đổi bài" gọi API *(làm ở giai đoạn 6, quyết định Q3)*
-- [ ] **7.3** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa. Bỏ câu báo viết sẵn "AI đã cân đối lại thực đơn Ngày 2!" (hiện hiện ra dù không có gì thay đổi)
+- [x] **7.3** Làm lại bảng feedback theo D2 (3 câu hỏi, câu tình trạng cơ thể chọn nhiều); gọi API, cập nhật ngày kế tiếp; nhận `safety_warning` → hiện khuyến cáo ngừng tập, hỏi ý kiến bác sĩ. **Khoá nút sau khi đã gửi feedback cho một ngày** — backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa. Bỏ câu báo viết sẵn "AI đã cân đối lại thực đơn Ngày 2!" (hiện hiện ra dù không có gì thay đổi)
 
+Chi tiết: brainstorm `docs/superpowers/brainstorms/phase-7-feedback.md` (quyết định Q1–Q4 ở mục 8), plan `docs/superpowers/plans/phase-7-feedback/`. Được đánh giá hôm nay và hôm qua; khoá theo ngày lưu `smartfit.feedback.v1` (chỉ số ngày); bảng trượt khôi phục được (D8); app tự so plan trước/sau để báo điều đã đổi (BRD v2.7.1).
+
 ## Giai đoạn 8 — Frontend: Tài khoản & Lịch sử (FR-6, FR-7) · M
 
 - [ ] **8.1** Màn đăng nhập, chọn chế độ bằng `--dart-define=AUTH_MODE`: giả lập → nút "Đăng nhập demo"; thật → package `google_sign_in`. Có nút bỏ qua đăng nhập (đăng nhập là tuỳ chọn theo FR-7)
```

```diff
--- a/docs/knowledge/wiki/critical-constraints.md
+++ b/docs/knowledge/wiki/critical-constraints.md
@@ -45,5 +45,6 @@
 | 33 | Thực đơn mẫu và kho món phải giữ tỉ lệ năng lượng đạm/tinh bột/béo gần mục tiêu BRD FR-1.5 (`MACRO_ENERGY_SPLIT` = 25/45/30, `energySplit()` trong `backend_api/src/plan/daily-target.ts`): mỗi ngày của thực đơn mẫu lệch ≤ 3 điểm ở từng chất — cả khi món vướng từng nhóm dị ứng backend nhận ra được thay bằng món trong kho (`sample-plan.spec.ts`); mỗi món ≤ 8 điểm (`swap-pools.spec.ts`). Thêm hay sửa món → tính lại macro từ nguyên liệu, không chỉ chỉnh calo. | Thực đơn mẫu cũ chỉ được nhân khẩu phần theo calo nên cả ngày ~24/53/23 (xôi đậu xanh 78 % tinh bột); Dashboard hiện tinh bột ~120 %, béo ~69 % mục tiêu. Gemini tự lập thực đơn ra 26/44–46/27–31 (đo 2026-09-27), nên phần lệch nằm ở dữ liệu soạn sẵn — thứ người dùng nhận mỗi khi Gemini chậm, lỗi hay hết hạn mức. |
 | 34 | Tag động tác không chỉ dựa vào tag được ghi: `addImpliedTags()` (`backend_api/src/plan/plan-validation.ts`) thêm tag suy từ tên (`impliedExerciseTags()` trong `restriction-matcher.ts`, từ khoá ở `exercise_name_tags` của `data/restriction-keywords.json`: squat, lunge, ngồi dựa tường… → `knee_bend`; nhảy, burpee → `jumping`; quỳ, khuỵu gối → `kneeling`) sau mọi `plainToInstance` của `parsePlanStructure()` / `parseContent()` và đầu `readClientPlan()`. Không làm bằng `@Transform`: class-transformer không gọi nó khi trường `tags` vắng mặt. Kho động tác và thực đơn mẫu vẫn phải ghi đủ tag (`swap-pools.spec.ts`). "Đau gối" và feedback "Đau khớp" tránh `jumping`, `kneeling`, `knee_bend` (BRD v2.7.0, PLAN D8). | Chạy thử trên máy ảo: người đau gối vẫn được giao Squat, Lunge lùi (luật cũ chỉ tránh bật nhảy, quỳ). Gemini có thể trả "Squat" với `tags: []` hoặc bỏ hẳn `tags` — nếu chỉ tin tag ghi sẵn, squat lọt qua bộ kiểm; plan lưu trên máy từ trước bản 2.7.0 cũng có squat không tag. |
 | 35 | Dữ liệu người dùng đang nhập dở trong app (Onboarding, sửa hồ sơ, tab đang mở) chỉ lưu tạm bằng state restoration (`MaterialApp.restorationScopeId`, `RestorationMixin`), **không** ghi `shared_preferences`; Back ở màn gốc Android chỉ đưa app xuống nền (`MainActivity.popSystemNavigator()` → `moveTaskToBack`). Kết quả: hệ thống tắt app ở nền → khôi phục; force-quit → mất. Test: `widget_test.dart` (`restartAndRestore()`, và kiểm không có khoá nào được ghi). | PLAN D8. Trước đó Back ở bước 1 gọi `finish()` → mất hết. Ghi xuống máy thì force-quit cũng không xoá được — trái quyết định của người dùng. |
+| 36 | Feedback cuối ngày trên app (BRD FR-5.1 v2.7.1, PLAN giai đoạn 7): ngày được gửi theo `canReviewDay()` (`frontend_app/lib/models/feedback_rules.dart`: hôm nay, hôm qua; ngày 3 cả khi plan đã hết). Ngày đã gửi lưu ở `smartfit.feedback.v1` = `{ plan_id, days }` — **chỉ** số ngày, không lưu câu trả lời (tình trạng cơ thể là dữ liệu sức khoẻ); `PlanProvider` chỉ khoá sau khi server trả plan, xoá khi tạo plan mới hoặc feedback ngày 3 trả plan mới. Câu trả lời đang chọn chỉ lưu tạm (#35). Dấu hiệu nguy hiểm: khuyến cáo hiện ngay trong bảng không chờ server; `safety_warning` chỉ đóng bằng nút "Tôi đã hiểu" (`PopScope`, `enableDrag: false`). Báo kết quả bằng `describeFeedbackChanges()` — không có câu viết sẵn kiểu "AI đã cân đối lại thực đơn". | Backend không lưu trạng thái: gửi lại cùng một ngày điều chỉnh thêm lần nữa (BRD 6.4). Khoá trước khi server trả lời thì lỗi mạng làm người dùng không gửi lại được. Bảng feedback cũ (xoá ở giai đoạn 6) báo "AI đã cân đối lại thực đơn Ngày 2!" dù không có gì thay đổi. |
 
 _File này được feature-explore và feature-build load khi phát hiện công việc liên quan tới ràng buộc._
```

```diff
--- a/docs/knowledge/wiki/flutter-ui.md
+++ b/docs/knowledge/wiki/flutter-ui.md
@@ -17,10 +17,12 @@
 | `models/profile_rules.dart` | Giới hạn và luật an toàn giống backend: tuổi 18–100, chiều cao, cân nặng, BMI < 18,5, mang thai → không Giảm mỡ (#30) |
 | `models/restriction_options.dart` | Danh sách chip dị ứng / chấn thương / bệnh nền, ghép và tách chuỗi gửi đi (D5, #32) |
 | `models/plan_schedule.dart` | Ngày bắt đầu của plan, hôm nay là ngày mấy (D6-B1) |
+| `models/feedback_rules.dart` | Ngày nào được gửi feedback (`canReviewDay()`), `FeedbackLog` — ngày đã gửi của một plan (#36) |
+| `models/feedback_summary.dart` | `describeFeedbackChanges()` — so plan trước/sau khi gửi feedback, liệt kê điều đã đổi |
 | `services/` | `ApiClient`, `ApiException` |
 | `providers/` | `PlanProvider` (plan, hồ sơ của plan, lịch, bản nháp hồ sơ), `AuthProvider`, `GroceryProvider` (đã mua / đã có sẵn) |
 | `screens/` | `onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`, `profile_screen.dart` |
-| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart` |
+| `widgets/` | `profile_form.dart` (form hồ sơ dùng chung cho Onboarding và tab Cá nhân), `macro_ring.dart`, `app_frame.dart`, `feedback_sheet.dart` (bảng feedback cuối ngày + `feedbackSheetRoute`) |
 | `theme/app_colors.dart` | Bảng màu dùng chung |
 
 Ngoài `lib/`: `tool/make_icon.swift` + `tool/update_icons.sh` vẽ lại icon, `assets/icon/` là hai ảnh gốc. Chữ trên giao diện và comment viết tiếng Việt; số thập phân hiển thị kiểu Việt ("24,8").
@@ -43,7 +45,7 @@
 | Đi chợ | Dựng từ `grocery_list` (#7), tên nhóm theo BRD FR-3.1; tích "đã mua"; "đã có sẵn" ẩn khỏi danh sách cần mua, "Hiện lại" → "Cần mua"; tìm kiếm (`matchesSearch()` trong `lib/models/search_text.dart`: gõ không dấu "ga" ra "Thịt gà", "Gạo tẻ"; gõ có dấu thì so đúng dấu — "cá" không ra "Cà chua"), lọc nhóm. Không có nút thêm nguyên liệu |
 | Cá nhân | Tóm tắt hồ sơ (BMI, calo mục tiêu); sửa bằng cùng form, lưu thành **bản nháp** — plan đang mở vẫn dùng hồ sơ cũ nên đổi món không bị 409; dải "Tạo kế hoạch mới" dùng bản nháp |
 | Lịch sử | Chỗ giữ — đăng nhập và lịch sử ở giai đoạn 8 |
-| Feedback cuối ngày | Chưa có nút — làm lại theo D2 ở giai đoạn 7 |
+| Feedback cuối ngày | Thẻ "Đánh giá cuối ngày" ở cuối tab ngày được đánh giá (hôm nay, hôm qua; ngày 3 cả khi plan đã hết — #36) → bảng trượt 3 câu hỏi (D2): "Bình thường" loại trừ trạng thái khác; chọn dấu hiệu nguy hiểm → ô đỏ khuyến cáo ngay, không cần mạng; gửi → vòng xoay (ngày 3: "có thể mất tới 40 giây"); lỗi → câu của `ApiException`, giữ lựa chọn; 409 → "Tạo kế hoạch mới". Kết quả trong bảng: `safety_warning` → ô đỏ, chỉ nút "Tôi đã hiểu" đóng được (Back, chạm ra ngoài bị chặn, kéo xuống tắt); tóm tắt điều đã đổi từ `describeFeedbackChanges()`. Đã gửi → thẻ "Đã gửi đánh giá ngày d" |
 
 ## Địa chỉ backend
 
@@ -103,6 +105,7 @@
 | `smartfit.grocery.v1` | `GroceryProvider` | `plan_id` + món đã mua + món đã có sẵn; khoá mỗi dòng = nhóm + tên + lượng (lượng đổi sau khi đổi món → dòng đó bỏ tích); plan mới → xoá |
 | `smartfit.access_token` | `AuthProvider` | JWT của backend (7 ngày) |
 | `smartfit.user.v1` | `AuthProvider` | `id`, `email`, `name` |
+| `smartfit.feedback.v1` | `PlanProvider` | `plan_id` + số ngày đã gửi feedback — **không** có câu trả lời; khoá chỉ đặt sau khi server trả plan; tạo plan mới hoặc feedback ngày 3 → xoá; của plan khác hoặc hỏng → coi như chưa gửi (#36) |
 
 - Số phiên bản trong khoá: đổi định dạng theo cách bản cũ không đọc được thì tăng số.
 - Bản lưu hỏng: plan hỏng → bỏ plan, giữ hồ sơ; hồ sơ hỏng → bỏ cả plan (không có hồ sơ thì không đổi món/feedback được); token không có user → bỏ cả hai; lịch thiếu hoặc của plan khác → coi như bắt đầu hôm nay.
@@ -111,7 +114,7 @@
 
 ### Dữ liệu đang nhập dở (PLAN D8, #35)
 
-Không ghi xuống `shared_preferences` — chỉ lưu tạm bằng state restoration: `MaterialApp.restorationScopeId: 'smartfit'`; `OnboardingScreen` (bước + form), `ProfileScreen` (phần sửa hồ sơ dở), `MainShell` (tab đang mở) dùng `RestorationMixin`. Form được chụp thành JSON bằng `ProfileFormController.toSnapshot()` / `restoreSnapshot()` (cả ô chưa hợp lệ). Android: Back ở màn gốc gọi `MainActivity.popSystemNavigator()` → `moveTaskToBack(true)` (như nút Home) thay vì `finish()`.
+Không ghi xuống `shared_preferences` — chỉ lưu tạm bằng state restoration: `MaterialApp.restorationScopeId: 'smartfit'`; `OnboardingScreen` (bước + form), `ProfileScreen` (phần sửa hồ sơ dở), `MainShell` (tab đang mở, bảng feedback đang mở — `RestorableRouteFuture` + `Navigator.restorablePush(feedbackSheetRoute)`, đặt ở `MainShell` vì Dashboard dựng lại khi plan đổi), `FeedbackSheet` (câu trả lời đang chọn) dùng `RestorationMixin`. Form được chụp thành JSON bằng `ProfileFormController.toSnapshot()` / `restoreSnapshot()` (cả ô chưa hợp lệ). Android: Back ở màn gốc gọi `MainActivity.popSystemNavigator()` → `moveTaskToBack(true)` (như nút Home) thay vì `finish()`.
 
 | Tình huống (đã thử trên Android 16, bản release) | Kết quả |
 |---|---|
@@ -160,14 +163,14 @@
 
 ## Test
 
-- `cd frontend_app && flutter test` — 96 test, không cần backend chạy:
+- `cd frontend_app && flutter test` — 125 test, không cần backend chạy:
   - `test/models/` — vòng tròn fixture (`contract_test.dart`), luật hồ sơ, chip hạn chế so với `restriction_labels.json`, lịch ngày;
   - `test/services/api_client_test.dart` — `MockClient` của `package:http/testing`;
   - `test/providers/` — `SharedPreferences.setMockInitialValues()`, đồng hồ giả;
-  - `test/screens/` — từng màn hình; `test/widget_test.dart` — luồng của cả app;
+  - `test/screens/` — từng màn hình; `test/widgets/feedback_sheet_test.dart` — bảng feedback trong cả app; `test/widget_test.dart` — luồng của cả app;
   - `test/app_harness.dart` — dựng app/màn hình cỡ điện thoại (411×914 dp) với backend giả, dữ liệu đã lưu, đồng hồ giả; `fillOnboarding()`, `scrollTo()` (danh sách chỉ dựng phần đang hiện — cuộn rồi `ensureVisible` trước khi bấm);
   - `test/fake_backend.dart` — backend giả trả fixture theo đường dẫn, `responses` thay JSON cho một đường dẫn, ghi lại request.
-- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (điền Onboarding → plan thật → Dashboard → đổi món). Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`. Máy ảo mở lại từ snapshot đôi khi làm test treo ở màn khởi động (bản debug chờ `flutter` kết nối mãi) — tắt máy ảo rồi khởi động nguội: `emulator -avd <tên> -no-snapshot-load`.
+- `integration_test/backend_smoke_test.dart` — chạy **tay** trên máy ảo/điện thoại khi backend đang chạy ở chế độ giả lập: `flutter test integration_test -d emulator-5554` (điện thoại thật thêm `--dart-define=API_BASE_URL=http://<IP LAN>:3000`). Gọi backend thật qua mạng của thiết bị, dùng `shared_preferences` thật, xoá dữ liệu đã lưu của app trên thiết bị đó; có một test thao tác giao diện (điền Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1). Tự dừng nếu `/health` báo `gemini: configured` (không tốn hạn mức Gemini — #17) hoặc không phải `auth_mode: mock`. `flutter test` (và CI) chỉ chạy thư mục `test/`. Máy ảo mở lại từ snapshot đôi khi làm test treo ở màn khởi động (bản debug chờ `flutter` kết nối mãi) — tắt máy ảo rồi khởi động nguội: `emulator -avd <tên> -no-snapshot-load`.
 - Chưa có máy ảo: Android Studio → Device Manager → tạo thiết bị (ví dụ Pixel 8, API 36).
 - `Container` có màu nền bọc `ListTile`/`SwitchListTile`/`ExpansionTile` → Flutter báo lỗi ở bản debug (hiệu ứng bấm bị che) — dùng `Material` có `shape` thay cho `Container`.
 - CI: `.github/workflows/frontend.yml` chạy `flutter analyze` + `flutter test` với Flutter 3.47.5 khi `frontend_app/**` đổi, rồi build 4 nền tảng (mục "Nền tảng").
@@ -175,6 +178,5 @@
 
 ## Việc của giai đoạn sau
 
-- **7:** bảng feedback cuối ngày theo D2 (3 câu hỏi, chọn nhiều tình trạng cơ thể), khoá sau khi gửi cho một ngày; `FeedbackResult.safetyWarning` → cảnh báo nổi bật. `PlanProvider.submitFeedback()` đã có (plan ngày 3 bắt đầu từ ngày mai).
 - **8:** Google Sign-In → `AuthProvider.signIn(idToken)`; tab Lịch sử.
 - Thực đơn mẫu lệch macro so với mục tiêu (ví dụ tinh bột ~120%, chất béo ~70%) vì chỉ được nhân khẩu phần theo calo; backend không kiểm tỉ lệ macro — Dashboard hiện đúng phần trăm thật. Ghi ở mục "Để sau" của PLAN.
```

```diff
--- a/docs/knowledge/wiki/swap-and-feedback.md
+++ b/docs/knowledge/wiki/swap-and-feedback.md
@@ -55,7 +55,7 @@
 
 **Ngày 3:** `PlanService.generatePlan(profile, { feedbackNote })`, rồi áp quy tắc bài tập cho ngày 1 của plan mới.
 
-**Gửi hai lần cho cùng một ngày sẽ điều chỉnh hai lần** — server không biết, app phải khoá nút.
+**Gửi hai lần cho cùng một ngày sẽ điều chỉnh hai lần** — server không biết, app phải khoá nút. App (giai đoạn 7, [[flutter-ui]]): khoá theo ngày trong `smartfit.feedback.v1`, chỉ đặt sau khi server trả plan; server không trả bản tóm tắt thay đổi và cảnh báo `mealsNotRebalanced` mất ở lần đổi món sau, nên app tự so plan trước/sau để báo (#36).
 
 ## Bộ khớp từ khoá (`restriction-matcher.ts`)
```

```diff
--- a/docs/knowledge/wiki/wiki-triggers.md
+++ b/docs/knowledge/wiki/wiki-triggers.md
@@ -39,7 +39,7 @@
 | BMR / TDEE / calo / macro / dinh dưỡng / mức vận động / Mifflin-St Jeor | `plan-data-contract.md` |
 | gemini / prompt / structured output / JSON schema / ảo giác (hallucination) | `gemini-integration.md` |
 | endpoint / controller / swagger / health / validation / DTO | `plan-data-contract.md`, `auth-and-history.md`, `swap-and-feedback.md` |
-| đổi món / đổi bài / swap / feedback / dị ứng / chấn thương / từ khoá / kho món / kho động tác / dấu hiệu nguy hiểm / khẩu phần | `swap-and-feedback.md` |
+| đổi món / đổi bài / swap / feedback / dị ứng / chấn thương / từ khoá / kho món / kho động tác / dấu hiệu nguy hiểm / khẩu phần | `swap-and-feedback.md`, `flutter-ui.md` và `critical-constraints.md` (#36) khi là phần app |
 | đăng nhập / auth / JWT / token / Google Sign-In / tài khoản / lịch sử / history / SQLite / TypeORM / migration / database / guard | `auth-and-history.md` |
 | screen / widget / onboarding / dashboard / giao diện đi chợ / Flutter | `flutter-ui.md` |
 | CORS / API_BASE_URL / dart-define / ApiClient / provider / shared_preferences / fixture hợp đồng / quyền mạng | `flutter-ui.md`, `critical-constraints.md` |
```

```diff
--- a/docs/knowledge/wiki/log.md
+++ b/docs/knowledge/wiki/log.md
@@ -24,3 +24,4 @@
 2026-09-29 — Quyết định D7 (nền tảng: Android, web, Windows, macOS; iOS tạm bỏ; BRD v2.6.1): [[flutter-ui]] thêm mục "Nền tảng" (CI build 4 bản release, tên và icon Windows, khung giữa màn hình cho cửa sổ rộng), sửa ghi chú CI không build APK
 2026-09-29 — Kiểm lại Android (release APK) và macOS: [[flutter-ui]] ghi kết quả, tìm kiếm đi chợ không dấu (`search_text.dart`), cửa sổ macOS 600×760 và chuyện macOS tự khôi phục cỡ cửa sổ
 2026-09-29 — PLAN D8 (BRD v2.7.0): thêm ràng buộc #34 (tag suy từ tên động tác, `knee_bend`, đau gối tránh gập gối) và #35 (dữ liệu đang nhập chỉ lưu tạm bằng state restoration, Back ở màn gốc Android đưa app xuống nền); [[flutter-ui]] thêm mục "Dữ liệu đang nhập dở"; [[gemini-integration]] thêm lần đo prompt đau gối; [[plan-data-contract]], [[swap-and-feedback]] thêm tag `knee_bend`
+2026-09-30 — Giai đoạn 7 (PLAN.md, BRD v2.7.1): thêm ràng buộc #36 (feedback cuối ngày: ngày được gửi, khoá `smartfit.feedback.v1` chỉ số ngày, cảnh báo an toàn chỉ đóng bằng "Tôi đã hiểu", báo điều đã đổi); [[flutter-ui]] thêm bảng feedback, khoá lưu mới, route khôi phục ở `MainShell`; [[swap-and-feedback]] ghi phần app
```

```diff
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -20,7 +20,7 @@
 
 This is a monorepo with three components:
 
-- **`frontend_app/`** — Flutter app, wired to `backend_api` since phase 6: 3-step onboarding, loading, the 3-day plan (meal/exercise swap via the API), grocery checklist and profile tab all read and write through the providers; no hardcoded data left. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. The end-of-day feedback sheet (phase 7) and login/history (phase 8) are not built yet.
+- **`frontend_app/`** — Flutter app, wired to `backend_api` since phase 6: 3-step onboarding, loading, the 3-day plan (meal/exercise swap via the API), grocery checklist and profile tab all read and write through the providers; no hardcoded data left. Screen navigation is driven by a local enum (`AppScreen` in `lib/main.dart`), not a router package. The end-of-day feedback sheet is built (phase 7); login/history (phase 8) are not built yet.
 - **`backend_api/`** — NestJS (TypeScript) service, scaffolded and working: `GET /health` and `POST /api/v1/generate-plan` (see Backend architecture below). Request/response DTOs validated with `class-validator`; Gemini call is wired but falls back to the bundled 3-day `sample-plan.json` when `GEMINI_API_KEY` is unset, Gemini times out, or its output fails contract validation (BRD NFR-2, NFR-4) — the response's `source` field (`gemini` / `sample`) says which one was used. Accounts (Google Sign-In, mock mode by default), `DELETE /api/v1/me`, and plan history on SQLite/TypeORM are built (BRD FR-6, FR-7; PLAN.md phase 3). Meal/exercise swap and end-of-day feedback (BRD §6.4) are built too (PLAN.md phase 4): stateless endpoints that take `{ profile, plan, … }` and return the whole new plan.
 - **`ai_workspace/`** — standalone Node/TypeScript project (own `package.json`, unrelated to `backend_api/`'s dependencies) for iterating on the Gemini prompt via `npm run experiment` before copying the finalized prompt into `backend_api/src/plan/gemini.service.ts`.
 
@@ -99,8 +99,8 @@
 - `lib/models/api/` — hand-written models for BRD §6. `fromJson(json).toJson()` must equal `json` exactly — swap/feedback send the whole plan back and the server checks every id and number, so numbers are read as `num`; missing fields, wrong types and unknown codes throw `FormatException` naming the field (`json_read.dart`). `test/models/contract_test.dart` round-trips the backend's fixtures.
 - `lib/models/profile_rules.dart` (limits + safety rules mirroring the backend), `restriction_options.dart` (D5 chips; every allergy/injury chip must be a label the backend keyword matcher knows — checked against `test/fixtures/restriction_labels.json`), `plan_schedule.dart` (plan start date → today's day number), `search_text.dart` (`matchesSearch()`: typed without accents → compare without accents on both sides, typed with accents → exact, like the backend matcher).
 - `lib/services/api_client.dart` — `ApiClient` for all 9 endpoints: 60 s timeout for calls that may hit Gemini (the backend gives up at 40 s), 15 s otherwise; bodies decoded as UTF-8 from `bodyBytes`; every failure becomes a sealed `ApiException` (`api_exception.dart`) whose `message` is Vietnamese UI text; a 401 on a request that carried a token calls `onUnauthorized`. Never log request/response bodies — they carry health data.
-- `lib/providers/` — `PlanProvider` (profile of the current plan + plan + schedule + profile draft in `shared_preferences` keys `smartfit.profile.v1` / `.plan.v1` / `.plan_schedule.v1` / `.profile_draft.v1`; edits in the profile tab stay a draft so swaps keep sending the plan's own profile and never hit 409; a stored profile that breaks the v2.6.0 rules drops the plan; `busy` flag, calls while busy are ignored; injectable clock `now:`), `GroceryProvider` (bought / already-have per plan, key = category + name + quantity), `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401).
-- `lib/screens/` — onboarding (3 steps), loading, dashboard, grocery, profile; `lib/widgets/profile_form.dart` — form shared by onboarding and the profile tab; `lib/theme/app_colors.dart` — palette. `lib/widgets/app_frame.dart` (`AppFrame`, set in `MaterialApp.builder`) keeps the whole app in a centred column at most 640 wide on web/desktop windows and narrows `MediaQuery.size` to match. Wrap `ListTile`s in `Material` (not a coloured `Container`) or Flutter asserts in debug.
+- `lib/providers/` — `PlanProvider` (profile of the current plan + plan + schedule + profile draft in `shared_preferences` keys `smartfit.profile.v1` / `.plan.v1` / `.plan_schedule.v1` / `.profile_draft.v1`; edits in the profile tab stay a draft so swaps keep sending the plan's own profile and never hit 409; a stored profile that breaks the v2.6.0 rules drops the plan; `busy` flag, calls while busy are ignored; injectable clock `now:`), `GroceryProvider` (bought / already-have per plan, key = category + name + quantity), `AuthProvider` (`smartfit.access_token`, `smartfit.user.v1`; signs out on 401). `PlanProvider.feedbackDays` = days of the current plan that already got end-of-day feedback, stored as `smartfit.feedback.v1` `{plan_id, days}` — never the answers (health data); set only after the server answered, cleared by a new plan (#36).
+- `lib/screens/` — onboarding (3 steps), loading, dashboard, grocery, profile; `lib/widgets/profile_form.dart` — form shared by onboarding and the profile tab; `lib/widgets/feedback_sheet.dart` — end-of-day feedback bottom sheet (D2 questions, danger advice shown immediately, `safety_warning` closes only via "Tôi đã hiểu", result from `describeFeedbackChanges()` in `lib/models/feedback_summary.dart`), opened by `MainShell` through a `RestorableRouteFuture` (not the Dashboard — it is rebuilt when the plan changes) from the card that `canReviewDay()` (`lib/models/feedback_rules.dart`: today, yesterday, day 3 after the plan ended) allows; `lib/theme/app_colors.dart` — palette. `lib/widgets/app_frame.dart` (`AppFrame`, set in `MaterialApp.builder`) keeps the whole app in a centred column at most 640 wide on web/desktop windows and narrows `MediaQuery.size` to match. Wrap `ListTile`s in `Material` (not a coloured `Container`) or Flutter asserts in debug.
 - App name/icon/splash: `tool/update_icons.sh` (macOS: `swift` + `sips`) redraws `assets/icon/*.png` with `tool/make_icon.swift` and copies every size for Android (incl. adaptive icon), iOS, macOS, web, and packs the Windows `app_icon.ico` with `tool/make_ico.swift` — deterministic. Windows name: `BINARY_NAME` `smartfit_ai`, window title in `windows/runner/main.cpp`, file info in `Runner.rc`. Android 12+ splash background is the brand green (`values-v31/styles.xml`); the Android themes set `windowDrawsSystemBarBackgrounds` so the status bar is not painted black.
 - Network config per platform: `INTERNET` in the main Android manifest, cleartext HTTP only in the debug manifest (Dart's HTTP isn't subject to Android's cleartext policy — checked on Android 16), iOS `NSAllowsLocalNetworking`, macOS `network.client` in both entitlements. Android `compileSdk = 36` (`shared_preferences_android` requires it; `targetSdk` stays 34). CI builds all four targets, so a plugin that breaks one platform's build fails CI.
 - Unfinished input is never written to `shared_preferences` (#35): `MaterialApp.restorationScopeId` + `RestorationMixin` in `OnboardingScreen` (step + form via `ProfileFormController.toSnapshot()`/`restoreSnapshot()`), `ProfileScreen` (edit in progress) and `MainShell` (tab), so a system kill in the background restores it and a force-quit clears it; Android `MainActivity.popSystemNavigator()` moves the task to the back instead of finishing on Back at the root. Tests use `tester.restartAndRestore()`.
```

```diff
--- a/README.md
+++ b/README.md
@@ -88,6 +88,11 @@
 
 Đối chiếu theo phiên bản BRD (mục "Phiên bản" trong [BRD.md](BRD.md)), để giảng viên/trợ giảng theo dõi tiến độ trực tiếp trên repo mà không cần đọc từng commit.
 
+### BRD v2.7.1 — 2026-09-30
+- Giai đoạn 7 — đánh giá cuối ngày: cuối mỗi ngày có thẻ "Đánh giá cuối ngày" mở bảng 3 câu hỏi (cường độ, tình trạng cơ thể, ăn uống). Gửi xong app báo đúng điều đã đổi ở ngày kế tiếp (ví dụ bớt hiệp, thêm giãn cơ, buổi tập ngắn lại; thực đơn cân đối lại hay giữ nguyên); ngày 3 tạo kế hoạch mới bắt đầu từ ngày mai
+- Báo chóng mặt, khó thở hay đau ngực → khuyến cáo ngừng tập hiện ngay (cả khi mất mạng); ngày kế tiếp thành ngày nghỉ; cảnh báo chỉ đóng khi bấm "Tôi đã hiểu"
+- Mỗi ngày chỉ gửi một lần (gửi lại sẽ bị điều chỉnh hai lần); được gửi cho hôm nay và hôm qua. Máy chỉ ghi ngày đã gửi, không ghi câu trả lời. Kiểm thử: 125 test Flutter; chạy thật trên máy ảo Android 16 và macOS
+
 ### BRD v2.7.0 — 2026-09-29
 - Không mất dữ liệu đang nhập: nhấn Back ở bước đầu Onboarding thì app lui xuống nền thay vì đóng; điện thoại tự tắt app ở nền thì mở lại còn nguyên bước và dữ liệu (cả phần sửa hồ sơ dở). Chỉ khi người dùng tự tắt hẳn app (vuốt khỏi đa nhiệm) mới xoá
 - Người đau gối không còn bị giao squat, lunge, ngồi dựa tường… (trước đây chỉ tránh bật nhảy và quỳ gối). Backend nhận ra động tác gập gối qua tên nên kể cả khi AI ghi thiếu thông tin vẫn loại được; thêm 2 bài chân an toàn cho gối. Kiểm thử: 390 unit và 74 e2e backend, 96 test Flutter; chạy thật trên máy ảo Android 16
```
