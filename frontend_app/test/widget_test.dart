import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';
import 'package:my_ai_app/widgets/app_frame.dart';

import 'app_harness.dart';
import 'fixture_loader.dart';

// Luồng của app (PLAN 5.6, 6.1–6.3, 6.7). Không gọi mạng thật: backend giả trả fixture hợp đồng.
void main() {
  testWidgets('chưa có plan → Onboarding, không gọi mạng', (tester) async {
    final harness = await Harness.create(tester);
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
  });

  testWidgets('đã có plan đã lưu → mở thẳng Dashboard, không cần mạng', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
  });

  testWidgets('plan đã lưu bị hỏng → Onboarding, không crash', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), PlanProvider.planKey: '{"days": "hỏng"}'});
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('hồ sơ lưu từ trước nay bị luật v2.6.0 chặn (17 tuổi) → Onboarding điền sẵn, báo lỗi tuổi', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: savedPlan(profile: {...loadFixture('profile'), 'age': 17}));
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('SmartFit dành cho người từ 18 tuổi'), findsOneWidget);
  });

  testWidgets('Onboarding → màn chờ → Dashboard với plan server trả; gửi đúng hồ sơ đã chọn', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.hold = Completer<void>();
    await tester.pumpWidget(harness.app());
    await fillOnboarding(tester);
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    await tester.pump();
    expect(find.text('Đang lập kế hoạch 3 ngày cho bạn'), findsOneWidget);

    harness.backend.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(harness.backend.paths, ['/api/v1/generate-plan']);
    final body = jsonDecode(utf8.decode(harness.backend.requests.single.bodyBytes)) as Map<String, dynamic>;
    expect(body['restrictions'], {'allergies': 'Hải sản', 'injuries': 'Đầu gối', 'health_conditions': ''});
    expect(body['pregnant_or_breastfeeding'], isFalse);
  });

  testWidgets('tạo plan lỗi → báo lỗi, không crash; "Thử lại" tạo được plan', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.failWith = 400;
    await tester.pumpWidget(harness.app());
    await fillOnboarding(tester);
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tạo được kế hoạch'), findsOneWidget);
    expect(find.text('Về kế hoạch đang có'), findsNothing);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
  });

  testWidgets('thanh điều hướng: Đi chợ, Lịch sử (sắp có), Cá nhân', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ 3 ngày'), findsOneWidget);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử kế hoạch'), findsOneWidget);
    expect(find.textContaining('1.850'), findsNothing, reason: 'không còn số liệu viết cứng');
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ của bạn'), findsOneWidget);
  });

  testWidgets('cửa sổ rộng (web, Windows, macOS) → app nằm trong cột giữa; đổi cỡ cửa sổ không mất tab đang mở', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    final wide = tester.getRect(find.byType(Scaffold).first);
    expect(wide.width, AppFrame.maxContentWidth);
    expect(wide.center.dx, 640);

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(Scaffold).first).width, 400);
    expect(find.text('Danh sách đi chợ 3 ngày'), findsOneWidget);
  });
}
