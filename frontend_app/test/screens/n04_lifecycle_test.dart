import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/auth/welcome_screen.dart';
import 'package:my_ai_app/screens/main_screen.dart';
import 'package:my_ai_app/screens/plan/plan_screen.dart';
import 'package:my_ai_app/screens/profile/edit_profile_sheet.dart';
import 'package:my_ai_app/screens/profile/profile_screen.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/widgets/plan_lifecycle.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_harness.dart';
import '../fake_backend.dart';
import 'ui_restoration_test.dart' show themed;

void main() {
  testWidgets(
    'startup loading then saved Dashboard without API; restart stays Dashboard',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      final ready = Completer<SharedPreferences>();
      await tester.pumpWidget(
        SmartFitBootstrap(
          loadPreferences: () => ready.future,
          createApi: () => h.backend.api,
          now: () => planStart,
        ),
      );
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
      ready.complete(h.prefs);
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);
      expect(h.backend.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      final backend = FakeBackend();
      await tester.pumpWidget(
        SmartFitBootstrap(
          loadPreferences: () async => h.prefs,
          createApi: () => backend.api,
          now: () => planStart,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);
      expect(backend.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('empty startup opens Welcome with no API', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
      SmartFitBootstrap(
        loadPreferences: () async => h.prefs,
        createApi: () => h.backend.api,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(h.backend.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('preference load failure offers retry and preserves saved data', (
    tester,
  ) async {
    final h = await Harness.create(tester, saved: savedPlan());
    final before = h.prefs.getString(PlanProvider.planKey);
    var attempts = 0;
    await tester.pumpWidget(
      SmartFitBootstrap(
        loadPreferences: () async {
          if (attempts++ == 0) throw StateError('disk');
          return h.prefs;
        },
        createApi: () => h.backend.api,
        now: () => planStart,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(h.prefs.getString(PlanProvider.planKey), before);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);
    expect(h.backend.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('midnight and resume notify current date; never auto generate', (
    tester,
  ) async {
    final h = await Harness.create(tester, saved: savedPlan());
    var now = DateTime(2026, 9, 26, 23, 59, 59);
    final p = PlanProvider(api: h.backend.api, prefs: h.prefs, now: () => now);
    var count = 0;
    p.addListener(() => count++);
    await tester.pumpWidget(PlanLifecycle(plans: p, child: const SizedBox()));
    now = DateTime(2026, 9, 27);
    await tester.pump(const Duration(seconds: 1));
    expect(p.todayNumber, 2);
    expect(count, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 9, 29);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(count, 2);
    expect(p.todayNumber, 4);
    expect(h.backend.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
  testWidgets('all calendar days selectable when expired without generating', (
    tester,
  ) async {
    final h = await Harness.create(
      tester,
      saved: savedPlan(),
      now: DateTime(2026, 9, 30),
    );
    await tester.pumpWidget(themed(h, const Scaffold(body: PlanScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('đã hết hạn'), findsOneWidget);
    for (final day in [2, 3, 1]) {
      await tester.tap(find.text('Ngày $day').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(h.backend.requests, isEmpty);
  });
  for (final regenerate in [false, true]) {
    testWidgets(
      'profile editor ${regenerate ? 'regenerate failure' : 'save draft'} keeps old plan',
      (tester) async {
        final h = await Harness.create(tester, saved: savedPlan());
        final original = h.plans.plan!.toJson();
        h.backend.failWith = 500;
        await tester.pumpWidget(
          themed(
            h,
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const EditProfileSheet(),
                  ),
                  child: const Text('edit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('edit'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('edit-age')), '29');
        await tester.pump();
        final button = find.text(
          regenerate ? 'Lưu & tạo lại kế hoạch' : 'Chỉ lưu thông tin',
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(h.plans.draft!.age, 29);
        expect(h.plans.plan!.toJson(), original);
        expect(h.backend.requests.length, regenerate ? 1 : 0);
        if (regenerate) expect(find.text('Thử lại'), findsOneWidget);
        final reopened = PlanProvider(
          api: h.backend.api,
          prefs: h.prefs,
          now: () => planStart,
        );
        expect(reopened.draft!.age, 29);
        expect(reopened.plan!.toJson(), original);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('invalid age disables both editor actions', (tester) async {
    final h = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(
      themed(h, const Scaffold(body: EditProfileSheet())),
    );
    await tester.enterText(find.byKey(const Key('edit-age')), '17');
    await tester.pump();
    expect(enabled(tester, 'Chỉ lưu thông tin'), isFalse);
    expect(enabled(tester, 'Lưu & tạo lại kế hoạch'), isFalse);
    expect(h.backend.requests, isEmpty);
  });
  testWidgets(
    'profile regenerate success applies new profile and clears draft',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      await tester.pumpWidget(
        themed(
          h,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const EditProfileSheet(),
                ),
                child: const Text('edit'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-age')), '29');
      await tester.pump();
      await tester.ensureVisible(find.text('Lưu & tạo lại kế hoạch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu & tạo lại kế hoạch'));
      await tester.pumpAndSettle();
      expect(h.plans.profile!.age, 29);
      expect(h.plans.hasPendingProfile, isFalse);
      expect(h.backend.requests.length, 1);
      expect(PlanProvider(api: h.backend.api, prefs: h.prefs).profile!.age, 29);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('future start shows preview notice without generating', (
    tester,
  ) async {
    final h = await Harness.create(
      tester,
      saved: savedPlan(),
      now: DateTime(2026, 9, 25),
    );
    await tester.pumpWidget(themed(h, const Scaffold(body: PlanScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa bắt đầu'), findsOneWidget);
    await tester.tap(find.text('Ngày 3').first);
    await tester.pumpAndSettle();
    expect(h.backend.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'profile and editor fit Pixel2 text scale $scale and keyboard',
      (tester) async {
        final h = await Harness.create(tester, saved: savedPlan());
        tester.view.physicalSize = const Size(1080, 1920);
        tester.view.devicePixelRatio = 2.625;
        final json = h.plans.profile!.toJson();
        json['restrictions'] = {
          'allergies': 'Dị ứng rất dài ' * 18,
          'injuries': 'Đau đầu gối',
          'health_conditions': 'Thông tin sức khỏe ' * 12,
        };
        await h.plans.saveDraft(Profile.fromJson(json));
        await tester.pumpWidget(
          themed(h, const Scaffold(body: ProfileScreen()), scale: scale),
        );
        await tester.pumpAndSettle();
        await scrollTo(tester, find.text('Chỉnh sửa hồ sơ'));
        await tester.tap(find.text('Chỉnh sửa hồ sơ'));
        await tester.pumpAndSettle();
        expect(find.byType(EditProfileSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          themed(
            h,
            const Scaffold(body: EditProfileSheet()),
            scale: scale,
            keyboard: 280,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Chỉ lưu thông tin'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
