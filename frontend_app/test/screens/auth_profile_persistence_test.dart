import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/auth/welcome_screen.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_harness.dart';
import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  testWidgets('Đăng nhập tự động nạp hồ sơ từ CSDL: không phải nhập lại tuổi, chiều cao, cân nặng', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final profileJson = loadFixture('profile');
    backend.responses['/api/v1/me/profile'] = {'profile': profileJson};
    backend.responses['/api/v1/plans/history'] = <Map<String, dynamic>>[];

    final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => planStart);
    await plans.finishRestore();
    final auth = AuthProvider(api: backend.api, prefs: prefs);
    final grocery = GroceryProvider(prefs: prefs, plans: plans);

    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);

    // Mở bảng đăng nhập
    await scrollTo(tester, find.byKey(const Key('welcome-signin-button')));
    await tester.tap(find.byKey(const Key('welcome-signin-button')));
    await tester.pumpAndSettle();

    // Điền tài khoản và đăng nhập
    await tester.enterText(find.byKey(const Key('auth-email-input')), 'minh@vku.edu.vn');
    await tester.enterText(find.byKey(const Key('auth-password-input')), 'secret123');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    // Xác nhận đã đăng nhập và vào màn hình BasicInfoScreen
    expect(auth.isSignedIn, isTrue);
    expect(find.byType(BasicInfoScreen), findsOneWidget);

    // Xác nhận thông tin tuổi, chiều cao, cân nặng từ CSDL đã được tự động điền sẵn
    final ageFinder = find.byKey(const Key('age-input'));
    final heightFinder = find.byKey(const Key('height-input'));
    final weightFinder = find.byKey(const Key('weight-input'));

    expect(ageFinder, findsOneWidget);
    expect(heightFinder, findsOneWidget);
    expect(weightFinder, findsOneWidget);

    final ageField = tester.widget<TextField>(ageFinder);
    final heightField = tester.widget<TextField>(heightFinder);
    final weightField = tester.widget<TextField>(weightFinder);

    expect(ageField.controller?.text, '${profileJson['age']}');
    expect(heightField.controller?.text, '${profileJson['height_cm']}');
    expect(weightField.controller?.text, '${profileJson['weight_kg']}');
  });
}
