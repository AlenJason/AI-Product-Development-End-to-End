import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/history/history_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_harness.dart';
import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  Future<(FakeBackend, AuthProvider, PlanProvider, GroceryProvider)> buildState(
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
    return (backend, auth, plans, grocery);
  }

  testWidgets('Chế độ khách -> mở Lịch sử từ Cá nhân -> đăng nhập và tự động tải danh sách', (tester) async {
    final (backend, auth, plans, grocery) = await buildState(
      tester,
      saved: savedPlan(),
    );
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Đăng nhập để xem lịch sử'), findsOneWidget);
    expect(backend.requests, isEmpty);

    await tester.tap(find.byKey(const Key('history-signin-button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-email-input')), 'minh@vku.edu.vn');
    await tester.enterText(find.byKey(const Key('auth-password-input')), 'secret123');
    await tester.tap(find.byKey(const Key('auth-submit-button')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isTrue);
    expect(backend.paths, ['/api/v1/auth/login', '/api/v1/plans/history']);
    expect(find.text('1624 kcal/ngày'), findsOneWidget);
  });

  testWidgets('Đã đăng nhập -> hiển thị danh sách, gắn nhãn Đang mở, mở chi tiết 3 ngày và đi chợ', (tester) async {
    final login = loadFixture('auth_login');
    final planFixture = loadFixture('generate_plan');
    const historyId = '00000000-0000-4000-8000-000000000002';
    final (backend, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    backend.responses['/api/v1/plans/history/$historyId'] = planFixture;

    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();

    expect(find.text('1624 kcal/ngày'), findsOneWidget);
    if (planFixture['plan_id'] == historyId) {
      expect(find.text('Đang mở'), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('history-item-$historyId')));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryDetailScreen), findsOneWidget);
    expect(backend.paths.last, '/api/v1/plans/history/$historyId');
    expect(find.text('Ngày 1'), findsOneWidget);
    expect(find.text('Ngày 2'), findsOneWidget);
    expect(find.text('Ngày 3'), findsOneWidget);

    await tester.tap(find.text('Ngày 2'));
    await tester.pumpAndSettle();
    final day2Meal = ((planFixture['days'] as List)[1]['meals'] as List).first['name'] as String;
    expect(find.text(day2Meal), findsOneWidget);

    await scrollTo(tester, find.text('Danh sách đi chợ của kế hoạch này'));
    await tester.tap(find.text('Danh sách đi chợ của kế hoạch này'));
    await tester.pumpAndSettle();
    final firstGrocery =
        (((planFixture['grocery_list'] as List).first['items'] as List).first['name']) as String;
    expect(find.text(firstGrocery), findsOneWidget);
  });

  testWidgets('Danh sách trống hiển thị hướng dẫn và nút Tạo kế hoạch mới', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    backend.responses['/api/v1/plans/history'] = {'plans': []};

    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();

    expect(find.text('Chưa có kế hoạch nào được lưu'), findsOneWidget);
    expect(find.byKey(const Key('history-create-plan-button')), findsOneWidget);
  });

  testWidgets('Lỗi server hiển thị thông báo và nút Thử lại phục hồi được', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    backend.failWith = 500;

    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history-retry-button')), findsOneWidget);

    backend.failWith = null;
    await tester.tap(find.byKey(const Key('history-retry-button')));
    await tester.pumpAndSettle();

    expect(find.text('1624 kcal/ngày'), findsOneWidget);
  });

  testWidgets('Token hết hạn 401 khi mở lịch sử -> nhắc đăng nhập lại', (tester) async {
    final login = loadFixture('auth_login');
    final (backend, auth, plans, grocery) = await buildState(
      tester,
      saved: {
        ...savedPlan(),
        AuthProvider.tokenKey: login['access_token'] as String,
        AuthProvider.userKey: jsonEncode(login['user']),
      },
    );
    backend.failWith = 401;

    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: grocery));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-history-button')));
    await tester.pumpAndSettle();

    expect(auth.isSignedIn, isFalse);
    expect(find.byKey(const Key('relogin-button')), findsOneWidget);
    expect(find.byKey(const Key('history-signin-button')), findsOneWidget);
  });
}

