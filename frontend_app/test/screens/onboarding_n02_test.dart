import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/profile_rules.dart';
import 'package:my_ai_app/models/restriction_options.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/routes.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:my_ai_app/screens/onboarding/generating_plan_screen.dart';
import 'package:my_ai_app/screens/onboarding/restrictions_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../providers/onboarding_validation_test.dart' show validOnboarding;

void main() {
  late FakeBackend backend;
  late PlanProvider plans;
  late OnboardingProvider form;
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
    plans = PlanProvider(api: backend.api, prefs: prefs);
    form = OnboardingProvider();
  });
  tearDown(() => backend.api.close());

  Future<void> pump(WidgetTester tester, {Widget? screen}) async {
    // Pixel 2, 411×731dp: nội dung cuộn, nút tiếp tục luôn trong viewport.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: plans),
          ChangeNotifierProvider.value(value: form),
        ],
        child: MaterialApp(
          onGenerateRoute: appGenerateRoute,
          home: screen ?? const BasicInfoScreen(),
        ),
      ),
    );
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    final chips = find.ancestor(of: finder, matching: find.byType(ChoiceChip));
    final target = chips.evaluate().isEmpty ? finder : chips.first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> body(
    WidgetTester tester, {
    String weight = '62',
    bool pregnancy = false,
  }) async {
    await tester.enterText(find.byKey(const Key('age-input')), '22');
    await tester.enterText(find.byKey(const Key('height-input')), '168');
    await tester.enterText(find.byKey(const Key('weight-input')), weight);
    await tap(tester, find.text('Nữ'));
    if (pregnancy) {
      await tap(tester, find.text('Đang mang thai hoặc cho con bú'));
    }
    await tap(tester, find.text('Tiếp tục'));
  }

  Future<void> goals(WidgetTester tester) async {
    await tap(tester, find.text('Duy trì'));
    await tap(tester, find.text('Vận động nhẹ'));
    await tap(tester, find.text('Tiếp tục'));
  }

  ElevatedButton testerButton(String label) =>
      (find.widgetWithText(ElevatedButton, label).evaluate().single.widget
          as ElevatedButton);
  ElevatedButton next() => testerButton('Tiếp tục');

  testWidgets('body trống/sai chặn API; error gần field biến mất khi sửa', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('1/3'), findsOneWidget);
    expect(next().onPressed, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('age-input')))
          .controller!
          .text,
      '',
    );
    await tester.enterText(find.byKey(const Key('age-input')), '17');
    await tester.pump();
    expect(find.text(ageError('17')!), findsOneWidget);
    await tester.enterText(find.byKey(const Key('age-input')), '18');
    await tester.pump();
    expect(find.text(ageError('17')!), findsNothing);
    await tester.enterText(find.byKey(const Key('height-input')), 'NaN');
    await tester.pump();
    expect(find.text(heightError('NaN')!), findsOneWidget);
    expect(next().onPressed, isNull);
    expect(backend.requests, isEmpty);
  });

  for (final pregnancy in [false, true]) {
    testWidgets(
      'khóa cut thực sự khi ${pregnancy ? 'pregnancy' : 'thiếu cân'}; không đổi goal ngầm',
      (tester) async {
        await pump(tester);
        await body(
          tester,
          weight: pregnancy ? '62' : '42',
          pregnancy: pregnancy,
        );
        expect(find.text('2/3'), findsOneWidget);
        final cut = tester.widget<ChoiceChip>(
          find.byKey(const Key('goal-Giảm mỡ')),
        );
        expect(cut.onSelected, isNull);
        expect(form.goal, '');
        expect(find.byKey(const Key('cut-block-reason')), findsOneWidget);
        await goals(tester);
        expect(find.text('3/3'), findsOneWidget);
        expect(form.toProfile().pregnantOrBreastfeeding, pregnancy);
        expect(backend.requests, isEmpty);
      },
    );
  }

  testWidgets(
    'ba bước back/forward giữ raw decimal, goal/activity, pregnancy, chips/Khác và toggle',
    (tester) async {
      await pump(tester);
      await body(tester, weight: '62,5', pregnancy: true);
      await goals(tester);
      final toggle = find.byKey(const Key('restriction-allergies'));
      await tap(tester, toggle);
      await tap(tester, find.widgetWithText(FilterChip, 'Trứng'));
      await tap(tester, find.byKey(const Key('other-toggle-allergies')));
      await tester.enterText(
        find.byKey(const Key('other-input-allergies')),
        ' thịt vịt ',
      );
      await tester.pump();
      Navigator.of(tester.element(find.byType(RestrictionsScreen))).pop();
      await tester.pumpAndSettle();
      expect(form.goal, 'Duy trì');
      expect(form.activityLevel, 'Vận động nhẹ');
      Navigator.of(tester.element(find.text('Mục tiêu và vận động'))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('weight-input')))
            .controller!
            .text,
        '62,5',
      );
      expect(form.pregnantOrBreastfeeding, isTrue);
      await tap(tester, find.text('Tiếp tục'));
      await tap(tester, find.text('Tiếp tục'));
      await tester.ensureVisible(
        find.byKey(const Key('other-input-allergies')),
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('other-input-allergies')))
            .controller!
            .text,
        ' thịt vịt ',
      );
      expect(form.toProfile().restrictions.allergies, 'Trứng, thịt vịt');
      await tap(tester, toggle);
      expect(form.toProfile().restrictions.allergies, '');
      await tap(tester, toggle);
      expect(form.toProfile().restrictions.allergies, 'Trứng, thịt vịt');
    },
  );

  testWidgets(
    'restriction counter chặn >300, không truncate; sửa thành300 mới submit được',
    (tester) async {
      form = validOnboarding();
      await pump(tester, screen: const RestrictionsScreen());
      await tap(tester, find.byKey(const Key('restriction-allergies')));
      await tap(tester, find.byKey(const Key('other-toggle-allergies')));
      await tester.enterText(
        find.byKey(const Key('other-input-allergies')),
        'a' * 301,
      );
      await tester.pump();
      expect(find.text('301/300 ký tự'), findsOneWidget);
      expect(testerButton('Tạo kế hoạch của tôi').onPressed, isNull);
      expect(form.selection(RestrictionKind.allergies).other.length, 301);
      expect(backend.requests, isEmpty);
      await tester.enterText(
        find.byKey(const Key('other-input-allergies')),
        'a' * 300,
      );
      await tester.pump();
      expect(
        find.byKey(const Key('restriction-error-allergies')),
        findsNothing,
      );
      expect(testerButton('Tạo kế hoạch của tôi').onPressed, isNotNull);
    },
  );

  testWidgets(
    'đổi Nữ sang Nam không xóa pregnancy ngầm; chặn đến khi người dùng bỏ chọn',
    (tester) async {
      await pump(tester);
      await body(tester, pregnancy: true);
      Navigator.of(tester.element(find.text('Mục tiêu và vận động'))).pop();
      await tester.pumpAndSettle();
      await tap(tester, find.text('Nam'));
      expect(form.pregnantOrBreastfeeding, isTrue);
      expect(
        find.text('Chỉ nữ mới khai báo mang thai / cho con bú'),
        findsOneWidget,
      );
      expect(next().onPressed, isNull);
      await tap(tester, find.text('Đang mang thai hoặc cho con bú'));
      expect(form.pregnantOrBreastfeeding, isFalse);
      expect(next().onPressed, isNotNull);
      expect(backend.requests, isEmpty);
    },
  );

  testWidgets(
    'submit hai lần một request, lỗi backend giữ dữ liệu và quay lại sửa được',
    (tester) async {
      form = validOnboarding()
        ..updateRestrictions(
          newAllergies: 'Trứng',
          newInjuries: 'Vai',
          conditions: 'Gout',
        );
      backend.failWith = 400;
      await pump(tester, screen: const RestrictionsScreen());
      final submit = testerButton('Tạo kế hoạch của tôi');
      submit.onPressed!();
      submit.onPressed!();
      await tester.pumpAndSettle();
      expect(backend.requests, hasLength(1));
      expect(find.byKey(const Key('generated-plan')), findsNothing);
      expect(form.toProfile().restrictions.allergies, 'Trứng');
      await tap(tester, find.text('Sửa hồ sơ'));
      expect(find.byType(RestrictionsScreen), findsOneWidget);
      backend.failWith = null;
      await tap(tester, find.text('Tạo kế hoạch của tôi'));
      expect(find.byKey(const Key('generated-plan')), findsOneWidget);
      expect(backend.requests, hasLength(2));
      expect(
        jsonDecode(backend.requests.first.body),
        jsonDecode(backend.requests.last.body),
      );
    },
  );

  testWidgets('route loading nhận Profile unsafe cũng chặn trước HTTP', (
    tester,
  ) async {
    final unsafe = validOnboarding().toProfile().toJson()..['age'] = 17;
    await pump(
      tester,
      screen: GeneratingPlanScreen(profile: Profile.fromJson(unsafe)),
    );
    await tester.pumpAndSettle();
    expect(backend.requests, isEmpty);
    expect(find.byKey(const Key('generate-error')), findsOneWidget);
    expect(find.byKey(const Key('generated-plan')), findsNothing);
  });
}
