import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/auth/welcome_screen.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:my_ai_app/screens/profile/profile_screen.dart';
import 'package:my_ai_app/screens/settings/delete_account_sheet.dart';
import 'package:my_ai_app/screens/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_harness.dart';
import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  Future<(FakeBackend, SharedPreferences, AuthProvider, PlanProvider, GroceryProvider)>
  buildState(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => planStart);
    await plans.finishRestore();
    final auth = AuthProvider(api: backend.api, prefs: prefs);
    final grocery = GroceryProvider(prefs: prefs, plans: plans);
    return (backend, prefs, auth, plans, grocery);
  }

  testWidgets('Welcome: đăng nhập bằng email và mật khẩu', (tester) async {
    final (backend, prefs, auth, plans, grocery) = await buildState(tester);
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('welcome-signin-button')));
    await tester.tap(find.byKey(const Key('welcome-signin-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-email-input')), 'minh@vku.edu.vn');
    await tester.enterText(find.byKey(const Key('auth-password-input')), 'secret123');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(backend.paths, ['/api/v1/auth/login']);
    final sent = jsonDecode(backend.requests.single.body) as Map;
    expect(sent, {'email': 'minh@vku.edu.vn', 'password': 'secret123'});
    expect(prefs.getString(AuthProvider.tokenKey), isNotNull);
    expect(find.byType(BasicInfoScreen), findsOneWidget);
  });

  testWidgets('Welcome: chuyển sang tab Đăng ký, kiểm tra xác nhận mật khẩu và đăng ký', (tester) async {
    final (backend, prefs, auth, plans, grocery) = await buildState(tester);
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('welcome-signin-button')));
    await tester.tap(find.byKey(const Key('welcome-signin-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-tab-register')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-name-input')), 'Công Minh');
    await tester.enterText(find.byKey(const Key('auth-email-input')), 'minh@vku.edu.vn');
    await tester.enterText(find.byKey(const Key('auth-password-input')), 'secret123');
    await tester.enterText(find.byKey(const Key('auth-confirm-password-input')), 'khacnhau');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    expect(backend.requests, isEmpty);

    await tester.enterText(find.byKey(const Key('auth-confirm-password-input')), 'secret123');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(backend.paths, ['/api/v1/auth/register']);
    final sent = jsonDecode(backend.requests.single.body) as Map;
    expect(sent, {
      'email': 'minh@vku.edu.vn',
      'name': 'Công Minh',
      'password': 'secret123',
    });
    expect(prefs.getString(AuthProvider.tokenKey), isNotNull);
    expect(find.byType(BasicInfoScreen), findsOneWidget);
  });

  testWidgets('Welcome: bỏ qua đăng nhập đi thẳng vào onboarding ở chế độ khách', (tester) async {
    final (backend, _, auth, plans, grocery) = await buildState(tester);
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('welcome-skip-button')));
    await tester.tap(find.byKey(const Key('welcome-skip-button')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(backend.requests, isEmpty);
    expect(find.byType(BasicInfoScreen), findsOneWidget);
  });

  testWidgets('401 hết phiên -> hiện banner nhắc đăng nhập lại trên ProfileScreen', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, _, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    backend.failWith = 401;
    await expectLater(backend.api.history(), throwsA(anything));

    await tester.pumpWidget(
      SmartFitApp(auth: auth, plans: plans, grocery: grocery),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byKey(const Key('relogin-button')), findsOneWidget);
    expect(find.byKey(const Key('profile-signin-button')), findsOneWidget);
  });

  testWidgets('Settings: đổi mật khẩu gửi API có token và thông báo thành công', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, _, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-change-password-tile')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('change-current-password-input')), 'secret123');
    await tester.enterText(find.byKey(const Key('change-new-password-input')), 'newpass456');
    await tester.enterText(find.byKey(const Key('change-confirm-password-input')), 'newpass456');
    await tester.tap(find.byKey(const Key('change-password-submit')));
    await tester.pumpAndSettle();

    expect(backend.paths, ['/api/v1/auth/change-password']);
    expect(
      backend.requests.single.headers['Authorization'],
      'Bearer ${login['access_token']}',
    );
    expect(jsonDecode(backend.requests.single.body), {
      'current_password': 'secret123',
      'new_password': 'newpass456',
    });
    expect(find.text('Đổi mật khẩu thành công!'), findsOneWidget);
  });

  testWidgets('Settings và DeleteAccountSheet dùng AuthProvider thật', (tester) async {
    final login = loadFixture('auth_login');
    final user = login['user'] as Map<String, dynamic>;
    final (backend, prefs, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(user),
      },
    );
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(user['email'] as String), findsOneWidget);
    expect(find.text('minh.nguyen@gmail.com'), findsNothing);

    await scrollTo(tester, find.byKey(const Key('settings-delete-account-button')));
    await tester.tap(find.byKey(const Key('settings-delete-account-button')));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-delete-account-button')));
    await tester.pumpAndSettle();

    expect(backend.requests.last.method, 'DELETE');
    expect(backend.paths, ['/api/v1/me']);
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getString(AuthProvider.tokenKey), isNull);
    expect(plans.hasPlan, isTrue);
  });

  testWidgets('Settings: đăng xuất chuyển về chế độ khách và giữ plan trên máy', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, prefs, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-signout-tile')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(backend.api.accessToken, isNull);
    expect(prefs.getString(AuthProvider.tokenKey), isNull);
    expect(plans.hasPlan, isTrue);
    expect(find.byKey(const Key('settings-signin-tile')), findsOneWidget);
  });
}
