import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/widgets/feedback_sheet.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Bảng feedback cuối ngày (PLAN giai đoạn 7, quyết định Q1–Q4) — mở từ thẻ trên Dashboard, trong cả app.
void main() {
  Future<Harness> openSheet(
    WidgetTester tester, {
    int day = 1,
    DateTime? now,
    Map<String, Object> account = const {},
  }) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...account}, now: now);
    await tester.pumpWidget(harness.app());
    await scrollTo(tester, find.text('Đánh giá ngày $day'));
    await tester.tap(find.text('Đánh giá ngày $day'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá cuối ngày $day'), findsOneWidget);
    return harness;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  bool selected(WidgetTester tester, String label) => (tester.widget(
    find.ancestor(
      of: find.text(label),
      // FilterChip/ChoiceChip bọc một RawChip — cả hai đều là SelectableChipAttributes.
      matching: find.byWidgetPredicate((widget) => widget is SelectableChipAttributes),
    ).first,
  ) as SelectableChipAttributes).selected;

  Map<String, dynamic> lastBody(Harness harness) =>
      jsonDecode(utf8.decode(harness.backend.requests.last.bodyBytes)) as Map<String, dynamic>;

  testWidgets(
    'khoá nút gửi tới khi đủ 3 câu; "Bình thường" loại trừ; gửi đúng câu trả lời; báo điều đã đổi; khoá ngày',
    (tester) async {
      final harness = await openSheet(tester);
      const submit = 'Gửi và điều chỉnh ngày 2';
      await tap(tester, 'Rất mệt');
      await tap(tester, 'Căng mỏi cơ');
      await tap(tester, 'Bình thường');
      expect(selected(tester, 'Căng mỏi cơ'), isFalse);
      expect(selected(tester, 'Bình thường'), isTrue);
      await tap(tester, 'Căng mỏi cơ');
      expect(selected(tester, 'Bình thường'), isFalse);
      expect(enabled(tester, submit), isFalse);
      await tap(tester, 'Đúng thực đơn');
      expect(enabled(tester, submit), isTrue);

      await tap(tester, submit);
      await tester.pumpAndSettle();
      expect(lastBody(harness), containsPair('day_number', 1));
      expect(lastBody(harness), containsPair('intensity', 'hard'));
      expect(lastBody(harness)['body_states'], ['sore']);
      expect(lastBody(harness), containsPair('eating', 'on_plan'));
      expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
      expect(find.textContaining('Ngày 2: giảm số hiệp'), findsOneWidget);
      expect(find.text('Ngày 2: buổi tập 20 → 15 phút.'), findsOneWidget);

      await tap(tester, 'Xong');
      await tester.pumpAndSettle();
      expect(find.text('Đánh giá cuối ngày 1'), findsNothing);
      await scrollTo(tester, find.text('Đã gửi đánh giá ngày 1'));
      expect(find.text('Đánh giá ngày 1'), findsNothing);
    },
  );

  testWidgets('dấu hiệu nguy hiểm → khuyến cáo hiện ngay, chưa gọi mạng; sau khi gửi phải bấm "Tôi đã hiểu"', (
    tester,
  ) async {
    final harness = await openSheet(tester);
    await tap(tester, 'Chóng mặt, khó thở bất thường, đau ngực');
    expect(find.text(dangerSignAdvice), findsOneWidget);
    expect(harness.backend.requests, isEmpty);

    harness.backend.responses['/api/v1/feedback'] = loadFixture('feedback_danger');
    await tap(tester, 'Nhẹ nhàng');
    await tap(tester, 'Ăn nhiều hơn');
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    final warning = (loadFixture('feedback_danger')['safety_warning'] as Map)['message'] as String;
    expect(find.text(warning), findsOneWidget);
    expect(find.text('Ngày 2: Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsOneWidget, reason: 'nút Back và chạm ra ngoài không đóng được cảnh báo');

    await tap(tester, 'Tôi đã hiểu');
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
  });

  testWidgets('server báo lỗi → câu tiếng Việt, giữ lựa chọn, không khoá ngày; gửi lại được', (tester) async {
    final harness = await openSheet(tester);
    for (final label in ['Vừa sức', 'Uể oải, thiếu ngủ', 'Ăn ít hơn hoặc bỏ bữa']) {
      await tap(tester, label);
    }
    harness.backend.failWith = 400;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại hồ sơ.'), findsOneWidget);
    expect(selected(tester, 'Uể oải, thiếu ngủ'), isTrue);
    expect(harness.plans.feedbackDays, isEmpty);

    harness.backend.failWith = null;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
    expect(lastBody(harness)['body_states'], ['fatigued']);
  });

  testWidgets('409 → câu của server + "Tạo kế hoạch mới": đóng bảng và tạo plan', (tester) async {
    final harness = await openSheet(tester);
    for (final label in ['Vừa sức', 'Bình thường', 'Đúng thực đơn']) {
      await tap(tester, label);
    }
    harness.backend.failWith = 409;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text(loadFixture('error_409')['message'] as String), findsOneWidget);

    harness.backend.failWith = null;
    final fresh = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    harness.backend.responses['/api/v1/generate-plan'] = fresh;
    await tap(tester, 'Tạo kế hoạch mới');
    await tester.pumpAndSettle();
    // Khách: plan cũ sẽ mất hẳn → hỏi lại (quyết định Q5 giai đoạn 8).
    expect(find.text('Thay kế hoạch hiện tại?'), findsOneWidget);
    await tester.tap(find.text('Thay kế hoạch'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá cuối ngày 1'), findsNothing);
    expect(harness.backend.paths.last, '/api/v1/generate-plan');
    expect(harness.plans.plan!.planId, fresh['plan_id']);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
  });

  // Giai đoạn 8: token hết hạn giữa chừng → đăng nhập lại ngay trên bảng, câu trả lời vẫn còn để gửi lại.
  testWidgets('401 → "Đăng nhập lại" mở bảng đăng nhập chồng lên; đăng nhập xong gửi lại được, lựa chọn còn nguyên', (
    tester,
  ) async {
    final harness = await openSheet(tester, account: signedIn());
    for (final label in ['Rất mệt', 'Căng mỏi cơ', 'Đúng thực đơn']) {
      await tap(tester, label);
    }
    harness.backend.failWith = 401;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'), findsOneWidget);
    expect(harness.auth.isSignedIn, isFalse);

    harness.backend.failWith = null;
    await tap(tester, 'Đăng nhập lại');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sv@vku.edu.vn');
    await tester.pump();
    await tester.tap(find.text('Đăng nhập demo'));
    await tester.pumpAndSettle();
    expect(harness.auth.isSignedIn, isTrue);
    expect(find.text('Đăng nhập demo'), findsNothing, reason: 'bảng đăng nhập tự đóng');
    expect(selected(tester, 'Rất mệt'), isTrue);

    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
    expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
  });

  testWidgets('ngày 3 → chờ có câu "tới 40 giây"; báo plan mới bắt đầu ngày mai; Dashboard hiện plan mới', (
    tester,
  ) async {
    final harness = await openSheet(tester, day: 3, now: planStart.add(const Duration(days: 2)));
    final next = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    harness.backend.responses['/api/v1/feedback'] = {'plan': next, 'safety_warning': null};
    for (final label in ['Nhẹ nhàng', 'Bình thường', 'Đúng thực đơn']) {
      await tap(tester, label);
    }
    harness.backend.hold = Completer();
    await tap(tester, 'Gửi và lập kế hoạch mới');
    expect(find.text('Đang lập kế hoạch mới — có thể mất tới 40 giây.'), findsOneWidget);
    harness.backend.hold!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Đã tạo kế hoạch 3 ngày mới, bắt đầu từ Thứ Ba, 29/9, có tính tới đánh giá của bạn.'),
      findsOneWidget,
    );

    await tap(tester, 'Xong');
    await tester.pumpAndSettle();
    expect(find.text('Kế hoạch bắt đầu từ Thứ Ba, 29/9.'), findsOneWidget);
    expect(harness.plans.plan!.planId, next['plan_id']);
  });
}
