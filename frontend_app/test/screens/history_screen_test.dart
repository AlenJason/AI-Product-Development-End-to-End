import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/screens/history_screen.dart';
import 'package:my_ai_app/screens/plan_detail_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Tab "Lịch sử" và màn xem lại plan cũ (PLAN 8.3, BRD FR-7.2; quyết định Q4, Q6).
void main() {
  const fixtureId = '00000000-0000-4000-8000-000000000002';

  Future<(Harness, List<String>)> pumpHistory(WidgetTester tester, {Map<String, Object>? saved}) async {
    final harness = await Harness.create(tester, saved: saved ?? {...savedPlan(), ...signedIn()});
    final signIns = <String>[];
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () => signIns.add('đăng nhập'))));
    await tester.pumpAndSettle();
    return (harness, signIns);
  }

  testWidgets('chưa đăng nhập → dải nhắc khách + nút đăng nhập, không gọi server', (tester) async {
    final (harness, signIns) = await pumpHistory(tester, saved: savedPlan());
    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
    await tester.tap(find.text('Đăng nhập'));
    expect(signIns, ['đăng nhập']);
  });

  testWidgets('đã đăng nhập → danh sách: ngày giờ trên máy, calo mục tiêu, nhãn "Đang dùng" cho plan hiện tại', (
    tester,
  ) async {
    final (harness, _) = await pumpHistory(tester);
    expect(harness.backend.paths, ['/api/v1/plans/history']);
    expect(harness.backend.requests.single.headers['Authorization'], startsWith('Bearer '));
    expect(find.text(historyTime(DateTime.utc(2026, 9, 24))), findsOneWidget);
    expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
    expect(find.text('Đang dùng'), findsOneWidget, reason: 'fixture lịch sử có đúng plan_id của plan đang dùng');
    expect(find.textContaining('chưa có trong lịch sử'), findsNothing);
  });

  testWidgets('plan đang dùng không có trong lịch sử (tạo lúc chưa đăng nhập) → ghi chú (quyết định Q4)', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.responses['/api/v1/plans/history'] = {
      'plans': [
        {
          'id': '11111111-2222-4333-8444-555555555555',
          'created_at': '2026-09-20T02:05:00.000Z',
          'target_calories': 1500,
        },
      ],
    };
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Đang dùng'), findsNothing);
    expect(find.textContaining('chưa có trong lịch sử của tài khoản này'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('chưa có plan nào → câu mời; lỗi mạng → câu lỗi + "Thử lại"', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.responses['/api/v1/plans/history'] = {'plans': <Object>[]};
    harness.backend.failWith = 503;
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có kế hoạch nào'), findsOneWidget);
  });

  testWidgets('401 (token hết hạn) → về khách, dải nhắc "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.failWith = 401;
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(harness.auth.isSignedIn, isFalse);
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsOneWidget);
  });

  testWidgets('đăng nhập khi đang mở tab → tự tải danh sách', (tester) async {
    final (harness, _) = await pumpHistory(tester, saved: savedPlan());
    await harness.auth.signIn('mock:sv@vku.edu.vn');
    await tester.pumpAndSettle();
    expect(harness.backend.paths.last, '/api/v1/plans/history');
    expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
  });

  testWidgets('bấm một plan → màn chỉ xem: 3 ngày, không có nút đổi món/bài hay đánh giá', (tester) async {
    final (harness, _) = await pumpHistory(tester);
    harness.backend.responses['/api/v1/plans/history/$fixtureId'] = loadFixture('generate_plan');
    await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanDetailScreen), findsOneWidget);
    expect(harness.backend.paths.last, '/api/v1/plans/history/$fixtureId');
    expect(find.text('BỮA SÁNG'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsOneWidget);
    expect(find.text('Đổi món'), findsNothing);
    expect(find.text('Đổi bài'), findsNothing);
    expect(find.textContaining('Đánh giá ngày'), findsNothing);

    await tester.tap(find.text('Ngày 2'));
    await tester.pumpAndSettle();
    expect(find.text('Bánh mì trứng ốp la'), findsOneWidget);
  });

  testWidgets('plan không còn trên server (404) → câu tiếng Việt; "Về danh sách" tải lại danh sách', (tester) async {
    final (harness, _) = await pumpHistory(tester);
    harness.backend.failWith = 404;
    await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Kế hoạch này không còn trong lịch sử.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Về danh sách'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanDetailScreen), findsNothing);
    expect(harness.backend.paths.last, '/api/v1/plans/history');
  });
}
