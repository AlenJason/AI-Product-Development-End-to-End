import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';
import 'package:my_ai_app/screens/plan_detail_screen.dart';
import 'package:my_ai_app/screens/welcome_screen.dart';
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

  testWidgets('thanh điều hướng: Đi chợ, Lịch sử, Cá nhân', (tester) async {
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

  // PLAN D8: dữ liệu đang nhập chỉ lưu tạm (state restoration) — hệ thống tắt app ở nền thì mở lại còn nguyên,
  // không ghi gì xuống máy nên force-quit là mất.
  testWidgets('hệ thống tắt app giữa Onboarding → mở lại đúng bước, đủ dữ liệu; không ghi xuống máy', (tester) async {
    final harness = await Harness.create(tester);
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Nam'));
    await tester.enterText(field('Tuổi'), '30');
    await tester.enterText(field('Chiều cao (cm)'), '172');
    await tester.enterText(field('Cân nặng (kg)'), '68');
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vận động nhẹ'));
    await tester.pump();
    expect(harness.prefs.getKeys(), {AuthProvider.welcomeKey});

    await tester.restartAndRestore();
    expect(find.textContaining('Bước 2/3'), findsOneWidget);
    await tester.tap(find.text('Duy trì vóc dáng'));
    await tester.pump();
    expect(enabled(tester, 'Tiếp tục'), isTrue, reason: 'mức vận động đã chọn trước khi bị tắt vẫn còn');
    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Tuổi')).controller!.text, '30');
    expect(tester.widget<TextField>(field('Chiều cao (cm)')).controller!.text, '172');
    expect(tester.widget<TextField>(field('Cân nặng (kg)')).controller!.text, '68');
  });

  testWidgets('đang sửa hồ sơ dở ở tab Cá nhân, hệ thống tắt app → mở lại đúng tab, còn phần đang sửa', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Cân nặng (kg)'), '70');
    await tester.pump();

    await tester.restartAndRestore();
    expect(find.text('Hồ sơ của bạn'), findsOneWidget);
    expect(tester.widget<TextField>(field('Cân nặng (kg)')).controller!.text, '70');
  });

  // PLAN giai đoạn 7 + D8: câu trả lời đang chọn trong bảng feedback chỉ lưu tạm.
  testWidgets('bảng feedback đang mở dở, hệ thống tắt app → mở lại vẫn thấy bảng và lựa chọn; không ghi xuống máy', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    await scrollTo(tester, find.text('Đánh giá ngày 1'));
    await tester.tap(find.text('Đánh giá ngày 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rất mệt'));
    await tester.tap(find.text('Đau khớp (gối, cổ tay, vai…)'));
    await tester.pump();
    final keys = harness.prefs.getKeys();

    await tester.restartAndRestore();
    expect(find.text('Đánh giá cuối ngày 1'), findsOneWidget);
    for (final label in ['Rất mệt', 'Đau khớp (gối, cổ tay, vai…)']) {
      final chip = tester.widget(
        find
            .ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is SelectableChipAttributes))
            .first,
      ) as SelectableChipAttributes;
      expect(chip.selected, isTrue, reason: label);
    }
    expect(harness.prefs.getKeys(), keys);
  });

  // Giai đoạn 8 — tài khoản & lịch sử (FR-6, FR-7; quyết định Q1–Q7).
  group('đăng nhập và lịch sử', () {
    Future<void> signInDemo(WidgetTester tester, String email) async {
      await tester.enterText(field('Email'), email);
      await tester.pump();
      await tester.tap(find.text('Đăng nhập demo'));
      await tester.pumpAndSettle();
    }

    testWidgets('lần đầu mở app → màn chào, chỉ hỏi /health; "Dùng ngay" → Onboarding, lần sau không hiện lại', (
      tester,
    ) async {
      final harness = await Harness.create(tester, firstLaunch: true);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Đăng nhập demo'), findsOneWidget, reason: 'backend giả lập (fixture health: auth_mode mock)');
      expect(harness.backend.paths, ['/health']);

      await tester.tap(find.text('Dùng ngay, không cần đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(harness.auth.isSignedIn, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness.app());
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('màn chào: đăng nhập demo → Onboarding; tạo plan gửi kèm token (server lưu vào lịch sử)', (
      tester,
    ) async {
      final harness = await Harness.create(tester, firstLaunch: true);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await signInDemo(tester, 'sv@vku.edu.vn');
      expect(harness.auth.isSignedIn, isTrue);
      expect(find.byType(OnboardingScreen), findsOneWidget);

      await fillOnboarding(tester);
      await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
      await tester.pumpAndSettle();
      expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
      expect(harness.backend.requests.last.url.path, '/api/v1/generate-plan');
      expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
    });

    testWidgets('khách có plan bấm "Tạo kế hoạch mới" → hỏi lại (Q5); Huỷ → giữ plan, không gọi server', (
      tester,
    ) async {
      final harness = await Harness.create(tester, saved: savedPlan(), now: planStart.add(const Duration(days: 4)));
      await tester.pumpWidget(harness.app());
      await tester.tap(find.text('Tạo kế hoạch mới'));
      await tester.pumpAndSettle();
      expect(find.text('Thay kế hoạch hiện tại?'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(harness.backend.requests, isEmpty);
      expect(find.textContaining('Kế hoạch 3 ngày đã hết'), findsOneWidget);

      await tester.tap(find.text('Tạo kế hoạch mới'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thay kế hoạch'));
      await tester.pumpAndSettle();
      expect(harness.backend.paths, ['/api/v1/generate-plan']);
    });

    testWidgets('đã đăng nhập → tạo kế hoạch mới không hỏi (plan cũ nằm trong lịch sử)', (tester) async {
      final harness = await Harness.create(
        tester,
        saved: {...savedPlan(), ...signedIn()},
        now: planStart.add(const Duration(days: 4)),
      );
      await tester.pumpWidget(harness.app());
      await tester.tap(find.text('Tạo kế hoạch mới'));
      await tester.pumpAndSettle();
      expect(find.text('Thay kế hoạch hiện tại?'), findsNothing);
      expect(harness.backend.paths, ['/api/v1/generate-plan']);
    });

    testWidgets('tạo plan bị 401 (phiên hết hạn) → "Đăng nhập lại" → đăng nhập xong tự tạo tiếp, có token', (
      tester,
    ) async {
      final harness = await Harness.create(
        tester,
        saved: {...savedPlan(), ...signedIn()},
        now: planStart.add(const Duration(days: 4)),
      );
      await tester.pumpWidget(harness.app());
      harness.backend.failWith = 401;
      await tester.tap(find.text('Tạo kế hoạch mới'));
      await tester.pumpAndSettle();
      expect(find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'), findsOneWidget);
      expect(find.text('Tạo không cần đăng nhập'), findsOneWidget);
      expect(harness.auth.isSignedIn, isFalse);

      harness.backend.failWith = null;
      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();
      await signInDemo(tester, 'sv@vku.edu.vn');
      expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
      expect(harness.backend.paths.sublist(1), ['/health', '/api/v1/auth/google', '/api/v1/generate-plan']);
      expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
    });

    testWidgets('tab Lịch sử trong app: khách → mời đăng nhập; đăng nhập từ đó → danh sách → xem chi tiết → quay lại', (
      tester,
    ) async {
      final harness = await Harness.create(tester, saved: savedPlan());
      harness.backend.responses['/api/v1/plans/history/00000000-0000-4000-8000-000000000002'] = loadFixture(
        'generate_plan',
      );
      await tester.pumpWidget(harness.app());
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      await signInDemo(tester, 'sv@vku.edu.vn');
      expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
      expect(find.text('Đang dùng'), findsOneWidget);

      await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
      await tester.pumpAndSettle();
      expect(find.byType(PlanDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử kế hoạch'), findsOneWidget);
    });

    // #35: bảng đăng nhập là route khôi phục được; email đang gõ chỉ lưu tạm.
    testWidgets('bảng đăng nhập đang mở dở, hệ thống tắt app → mở lại còn bảng và email đang gõ; không ghi xuống máy', (
      tester,
    ) async {
      final harness = await Harness.create(tester, saved: savedPlan());
      await tester.pumpWidget(harness.app());
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Email'), 'sv@vku');
      await tester.pump();
      final keys = harness.prefs.getKeys();

      await tester.restartAndRestore();
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập demo'), findsOneWidget);
      expect(tester.widget<TextField>(field('Email')).controller!.text, 'sv@vku');
      expect(harness.prefs.getKeys(), keys);
    });
  });
}
