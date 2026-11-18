import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/auth/welcome_screen.dart';
import 'package:my_ai_app/screens/onboarding/activity_screen.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:my_ai_app/screens/profile/edit_profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_harness.dart';
import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  group('Profile Automated Flow Tests (Widget Tests)', () {
    testWidgets('1. Đăng nhập thành công tự động nạp hồ sơ thể chất vào BasicInfoScreen', (tester) async {
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

      // Điền thông tin đăng nhập
      await tester.enterText(find.byKey(const Key('auth-email-input')), 'testuser@vku.edu.vn');
      await tester.enterText(find.byKey(const Key('auth-password-input')), 'password123');
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();

      // Đã đăng nhập và mở BasicInfoScreen
      expect(auth.isSignedIn, isTrue);
      expect(find.byType(BasicInfoScreen), findsOneWidget);

      // Kiểm tra các trường dữ liệu tự động điền sẵn
      final ageField = tester.widget<TextField>(find.byKey(const Key('age-input')));
      final heightField = tester.widget<TextField>(find.byKey(const Key('height-input')));
      final weightField = tester.widget<TextField>(find.byKey(const Key('weight-input')));

      expect(ageField.controller?.text, '${profileJson['age']}');
      expect(heightField.controller?.text, '${profileJson['height_cm']}');
      expect(weightField.controller?.text, '${profileJson['weight_kg']}');
    });

    testWidgets('2. Tiếp tục sang ActivityScreen giữ nguyên hồ sơ đã nạp', (tester) async {
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

      // Đăng nhập
      await scrollTo(tester, find.byKey(const Key('welcome-signin-button')));
      await tester.tap(find.byKey(const Key('welcome-signin-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth-email-input')), 'testuser@vku.edu.vn');
      await tester.enterText(find.byKey(const Key('auth-password-input')), 'password123');
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();

      // Bấm tiếp tục từ BasicInfoScreen
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Kiểm tra đã sang màn hình ActivityScreen
      expect(find.byType(ActivityScreen), findsOneWidget);
    });

    testWidgets('3. Người dùng mới (profile: null) không gặp lỗi và hiển thị form rỗng sạch sẽ', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backend = FakeBackend();
      // Server trả về profile null
      backend.responses['/api/v1/me/profile'] = {'profile': null};
      backend.responses['/api/v1/plans/history'] = <Map<String, dynamic>>[];

      final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => planStart);
      await plans.finishRestore();
      final auth = AuthProvider(api: backend.api, prefs: prefs);
      final grocery = GroceryProvider(prefs: prefs, plans: plans);

      await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('welcome-signin-button')));
      await tester.tap(find.byKey(const Key('welcome-signin-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('auth-email-input')), 'newbie@vku.edu.vn');
      await tester.enterText(find.byKey(const Key('auth-password-input')), 'password123');
      await tester.tap(find.byKey(const Key('auth-submit-button')));
      await tester.pumpAndSettle();

      expect(auth.isSignedIn, isTrue);
      expect(find.byType(BasicInfoScreen), findsOneWidget);

      final ageField = tester.widget<TextField>(find.byKey(const Key('age-input')));
      expect(ageField.controller?.text, isEmpty);
    });

    testWidgets('4. Chỉnh sửa hồ sơ qua EditProfileSheet tự động gửi đồng bộ lên server', (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      await h.auth.signIn('mock:user@vku.edu.vn');

      await tester.pumpWidget(h.screen(const EditProfileSheet()));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileSheet), findsOneWidget);

      final saveButton = find.text('Chỉ lưu thông tin');
      await scrollTo(tester, saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(h.backend.requests.any((r) => r.url.path == '/api/v1/me/profile'), isTrue);
    });

    testWidgets('5. Lỗi mạng khi tải hồ sơ không làm sập ứng dụng (Graceful Degradation)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backend = FakeBackend();
      // Giả lập lỗi 500 khi nạp hồ sơ
      backend.failWith = 500;

      final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => planStart);
      await plans.finishRestore();
      final auth = AuthProvider(api: backend.api, prefs: prefs);
      final grocery = GroceryProvider(prefs: prefs, plans: plans);

      await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
