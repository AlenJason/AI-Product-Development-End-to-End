import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

void main() {
  Future<(Harness, List<String>)> pumpDashboard(WidgetTester tester, {DateTime? now}) async {
    final harness = await Harness.create(tester, saved: savedPlan(), now: now);
    final created = <String>[];
    await tester.pumpWidget(harness.screen(DashboardScreen(onCreatePlan: () => created.add('tạo mới'))));
    return (harness, created);
  }

  testWidgets('mở đúng ngày hôm nay: đủ 3 bữa (có bữa sáng), tổng calo so với mục tiêu, lưu ý của plan', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('Thứ Bảy, 26/9'), findsOneWidget);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(find.text('BỮA SÁNG'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsOneWidget);
    expect(find.textContaining('kcal mục tiêu'), findsOneWidget);
    expect(find.text('Lưu ý cho kế hoạch này (2)'), findsOneWidget);
    expect(find.text('Thực đơn mẫu'), findsOneWidget);
  });

  testWidgets('đổi sang ngày khác bằng bộ chọn 3 ngày', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Ngày 2'));
    await tester.pumpAndSettle();
    expect(find.text('Ngày 2 của kế hoạch'), findsOneWidget);
    expect(find.text('Bánh mì trứng ốp la'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsNothing);
  });

  testWidgets('hai ngày sau khi bắt đầu → mở sẵn ngày 3; quá 3 ngày → nhắc tạo kế hoạch mới', (tester) async {
    await pumpDashboard(tester, now: planStart.add(const Duration(days: 2)));
    expect(find.text('Hôm nay là Ngày 3'), findsOneWidget);

    final (_, created) = await pumpDashboard(tester, now: planStart.add(const Duration(days: 4)));
    expect(find.textContaining('Kế hoạch 3 ngày đã hết'), findsOneWidget);
    await tester.tap(find.text('Tạo kế hoạch mới'));
    expect(created, ['tạo mới']);
  });

  testWidgets('đổi món gọi API và hiện món mới (FR-4.1)', (tester) async {
    final (harness, _) = await pumpDashboard(tester);
    await tester.tap(find.text('Đổi món').at(1));
    await tester.pumpAndSettle();

    expect(harness.backend.paths, ['/api/v1/meals/swap']);
    expect(find.text('Đã đổi bữa trưa sang: Cơm đậu phụ nhồi thịt sốt cà'), findsOneWidget);
    expect(find.text('Cơm đậu phụ nhồi thịt sốt cà'), findsOneWidget);
  });

  testWidgets('409 → câu của server + nút tạo kế hoạch mới; món cũ giữ nguyên', (tester) async {
    final (harness, created) = await pumpDashboard(tester);
    harness.backend.failWith = 409;
    final firstExercise = loadFixture('generate_plan')['days'][0]['workout']['exercises'][0]['name'] as String;
    await scrollTo(tester, find.text(firstExercise));
    await tester.tap(find.text('Đổi bài').first);
    await tester.pumpAndSettle();

    expect(find.text(loadFixture('error_409')['message'] as String), findsOneWidget);
    await tester.tap(find.text('Tạo mới'));
    expect(created, ['tạo mới']);
    expect(harness.plans.plan!.toJson(), loadFixture('generate_plan'));
  });

  testWidgets('hồ sơ đã sửa ở tab Cá nhân → dải nhắc tạo kế hoạch mới', (tester) async {
    final (harness, created) = await pumpDashboard(tester);
    await harness.plans.saveDraft(Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'}));
    await tester.pump();
    expect(find.text('Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.'), findsOneWidget);
    await tester.tap(find.text('Tạo kế hoạch mới'));
    expect(created, ['tạo mới']);
  });

  // Giai đoạn 7, quyết định Q2: hôm nay và hôm qua nếu chưa gửi; ngày 3 cả khi plan đã hết; đã gửi thì khoá.
  group('thẻ feedback cuối ngày', () {
    Future<List<int>> pumpWithFeedback(WidgetTester tester, {DateTime? now, Set<int> sent = const {}}) async {
      final saved = savedPlan();
      final planId = jsonDecode(saved[PlanProvider.planKey]! as String)['plan_id'];
      final harness = await Harness.create(
        tester,
        saved: {
          ...saved,
          if (sent.isNotEmpty) PlanProvider.feedbackKey: jsonEncode({'plan_id': planId, 'days': sent.toList()}),
        },
        now: now,
      );
      final opened = <int>[];
      await tester.pumpWidget(harness.screen(DashboardScreen(onCreatePlan: () {}, onFeedback: opened.add)));
      return opened;
    }

    // Danh sách chỉ dựng phần đang hiện và độ dài tăng dần khi dựng thêm: nhảy tới cuối cho tới khi hết tăng.
    Future<void> showDay(WidgetTester tester, int day) async {
      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(SegmentedButton<int>), matching: find.textContaining('Ngày $day')),
      );
      await tester.pumpAndSettle();
      double? end;
      while (end != position.maxScrollExtent) {
        end = position.maxScrollExtent;
        position.jumpTo(end);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('ngày 1: có thẻ, bấm mở đúng ngày; ngày 2 chưa tới → không có thẻ', (tester) async {
      final opened = await pumpWithFeedback(tester);
      await showDay(tester, 1);
      expect(find.text('Hôm nay thế nào? Đánh giá 1 phút để SmartFit điều chỉnh ngày 2.'), findsOneWidget);
      await tester.tap(find.text('Đánh giá ngày 1'));
      expect(opened, [1]);
      await showDay(tester, 2);
      expect(find.text('ĐÁNH GIÁ CUỐI NGÀY'), findsNothing);
    });

    testWidgets('ngày 3: ngày 1 đã quá cũ → không có; hôm qua (ngày 2) và hôm nay (ngày 3) có', (tester) async {
      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 2)));
      await showDay(tester, 1);
      expect(find.text('ĐÁNH GIÁ CUỐI NGÀY'), findsNothing);
      await showDay(tester, 2);
      expect(find.text('Bạn chưa đánh giá ngày 2 — gửi ngay để điều chỉnh hôm nay.'), findsOneWidget);
      await showDay(tester, 3);
      expect(find.text('Đánh giá 1 phút để SmartFit lập kế hoạch 3 ngày tiếp theo.'), findsOneWidget);
    });

    testWidgets('plan đã hết: vẫn đánh giá được ngày 3 (tạo plan mới)', (tester) async {
      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 6)));
      await showDay(tester, 3);
      expect(find.text('Đánh giá ngày 3'), findsOneWidget);
    });

    testWidgets('đã gửi ngày 1 → "Đã gửi đánh giá ngày 1", không còn nút; ngày 2 vẫn gửi được', (tester) async {
      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 1)), sent: {1});
      await showDay(tester, 1);
      expect(find.text('Đã gửi đánh giá ngày 1'), findsOneWidget);
      expect(find.text('Đánh giá ngày 1'), findsNothing);
      await showDay(tester, 2);
      expect(find.text('Đánh giá ngày 2'), findsOneWidget);
    });
  });
}
