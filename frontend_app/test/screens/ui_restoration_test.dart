import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/core/theme/app_theme.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/routes.dart';
import 'package:my_ai_app/screens/auth/welcome_screen.dart';
import 'package:my_ai_app/screens/main_screen.dart';
import 'package:my_ai_app/screens/meal/meal_detail_screen.dart';
import 'package:my_ai_app/screens/workout/workout_detail_screen.dart';
import 'package:my_ai_app/screens/meal/meal_swap_sheet.dart';
import 'package:my_ai_app/screens/workout/workout_swap_sheet.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:my_ai_app/screens/onboarding/activity_screen.dart';
import 'package:my_ai_app/screens/onboarding/restrictions_screen.dart';
import 'package:my_ai_app/screens/onboarding/generating_plan_screen.dart';
import 'package:my_ai_app/screens/plan/generated_plan_screen.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:provider/provider.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

const captureKey = Key('ui-restoration-capture');
const exportScreenshots = bool.fromEnvironment('UI_SCREENSHOTS');

Widget themed(
  Harness h,
  Widget child, {
  double scale = 1,
  double keyboard = 0,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: h.plans),
    ChangeNotifierProvider.value(value: h.grocery),
    ChangeNotifierProvider.value(value: h.auth),
    ChangeNotifierProvider(create: (_) => OnboardingProvider()),
  ],
  child: RepaintBoundary(
    key: captureKey,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      onGenerateRoute: appGenerateRoute,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: ColoredBox(
          color: const Color(0xFFE8EFEB),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: child!,
            ),
          ),
        ),
      ),
      home: child,
    ),
  ),
);

Future<void> snapshot(WidgetTester tester, String name) async {
  if (!exportScreenshots) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  final previousShadows = debugDisableShadows;
  debugDisableShadows = false;
  boundary.markNeedsPaint();
  await tester.pump();
  try {
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('../artifacts/ui-restoration');
      await folder.create(recursive: true);
      await File('${folder.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = previousShadows;
    boundary.markNeedsPaint();
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Manrope');
    for (final weight in [400, 500, 600, 700, 800]) {
      loader.addFont(rootBundle.load('assets/fonts/Manrope-$weight.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  final screens = <String, Widget>{
    '01-welcome': const WelcomeScreen(),
    '03-onboarding-basic': const BasicInfoScreen(),
    '04-onboarding-goal-activity': const ActivityScreen(),
    '06-onboarding-restrictions': const RestrictionsScreen(),
    '08-home': const MainScreen(),
    '09-plan': const MainScreen(initialTab: 1),
    '10-meal-detail': const MealDetailScreen(mealId: 'm1_1'),
    '12-workout-detail': const WorkoutDetailScreen(exerciseId: 'e1_1'),
    '14-grocery': const MainScreen(initialTab: 2),
    'generated-plan': const GeneratedPlanScreen(),
  };
  for (final entry in screens.entries) {
    testWidgets('render ${entry.key} at reference 390x844', (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(themed(h, entry.value));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await snapshot(tester, entry.key);
    });
  }

  for (final meal in [true, false]) {
    testWidgets(
      'render ${meal ? 'meal' : 'workout'} swap loading/error at 390x844',
      (tester) async {
        final h = await Harness.create(tester, saved: savedPlan());
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpWidget(
          themed(
            h,
            meal
                ? const MealDetailScreen(mealId: 'm1_1')
                : const WorkoutDetailScreen(exerciseId: 'e1_1'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(meal ? 'Đổi món' : 'Đổi bài'));
        await tester.pumpAndSettle();
        expect(
          find.byType(meal ? MealSwapSheet : WorkoutSwapSheet),
          findsOneWidget,
        );
        await snapshot(tester, meal ? '11-meal-swap' : '13-workout-swap');
        h.backend.failWith = 422;
        await tester.tap(find.text('Xác nhận đổi'));
        await tester.pumpAndSettle();
        expect(find.text('Thử lại'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await snapshot(tester, meal ? 'meal-swap-error' : 'workout-swap-error');
      },
    );
  }

  testWidgets('generating waits for HTTP; render loading and API error', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    h.backend.hold = Completer<void>();
    await tester.pumpWidget(
      themed(
        h,
        GeneratingPlanScreen(profile: Profile.fromJson(loadFixture('profile'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('generate-loading')), findsOneWidget);
    await snapshot(tester, '07-generating');
    h.backend.failWith = 500;
    h.backend.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('generate-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await snapshot(tester, 'generating-error');
  });

  testWidgets(
    'empty dashboard and web content width preserve no-request state',
    (tester) async {
      final h = await Harness.create(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1360, 900);
      await tester.pumpWidget(themed(h, const MainScreen()));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(MainScreen)).width, 430);
      expect(h.backend.requests, isEmpty);
      expect(find.text('Chưa có kế hoạch.'), findsOneWidget);
      await snapshot(tester, 'web-empty-1360');
    },
  );

  for (final config in [
    (const Size(320, 568), 1.0, 'small'),
    (const Size(411, 731), 1.0, 'pixel2'),
    (const Size(390, 844), 2.0, 'large-text'),
  ]) {
    testWidgets('long content has no overflow: ${config.$3}', (tester) async {
      final saved = savedPlan();
      final json = loadFixture('generate_plan');
      for (final day in json['days'] as List<dynamic>) {
        for (final meal in day['meals'] as List<dynamic>) {
          meal['name'] = 'Món ăn có tên rất dài và nhiều thành phần ' * 5;
          meal['portion'] = 'Khẩu phần theo kế hoạch ' * 5;
        }
        for (final exercise in day['workout']['exercises'] as List<dynamic>) {
          exercise['name'] = 'Động tác với tên dài cần xuống dòng ' * 5;
          exercise['reps_or_duration'] = '12 lần chậm rãi mỗi bên ' * 4;
        }
      }
      for (final group in json['grocery_list'] as List<dynamic>) {
        for (final item in group['items'] as List<dynamic>) {
          item['name'] = 'Nguyên liệu có tên dài cần xuống dòng ' * 5;
          item['quantity'] = 'Định lượng theo khẩu phần hiện tại ' * 4;
        }
      }
      saved[PlanProvider.planKey] = jsonEncode(json);
      final h = await Harness.create(tester, saved: saved);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = config.$1;
      for (final screen in screens.values) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(themed(h, screen, scale: config.$2));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType}, ${config.$3}',
        );
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -1400));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Scrolled ${screen.runtimeType}, ${config.$3}',
          );
        }
      }
    });
  }

  testWidgets('keyboard leaves body form scrollable and action reachable', (
    tester,
  ) async {
    final h = await Harness.create(tester);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(themed(h, const BasicInfoScreen(), keyboard: 240));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(
      tester.getRect(find.text('Tiếp tục')).bottom,
      lessThanOrEqualTo(328),
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
