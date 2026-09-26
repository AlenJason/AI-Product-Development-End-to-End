import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fixture_loader.dart';

// Màn đầu tiên theo dữ liệu đã lưu (PLAN 5.6). Không gọi mạng: mở app chỉ đọc shared_preferences.
void main() {
  Future<FakeBackend> pumpApp(WidgetTester tester, Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    await tester.pumpWidget(SmartFitApp(
      auth: AuthProvider(api: backend.api, prefs: prefs),
      plans: PlanProvider(api: backend.api, prefs: prefs),
    ));
    return backend;
  }

  testWidgets('chưa có plan → mở Onboarding', (tester) async {
    final backend = await pumpApp(tester, {});
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Thiết lập mục tiêu 3 ngày'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('đã có plan đã lưu → mở thẳng Dashboard, không cần mạng', (tester) async {
    final backend = await pumpApp(tester, {
      PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
      PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
    });
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(backend.requests, isEmpty);
  });

  testWidgets('plan đã lưu bị hỏng → Onboarding, không crash', (tester) async {
    await pumpApp(tester, {
      PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
      PlanProvider.planKey: '{"days": "hỏng"}',
    });
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
