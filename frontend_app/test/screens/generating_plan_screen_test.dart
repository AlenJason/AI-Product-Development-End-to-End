import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/routes.dart';
import 'package:my_ai_app/screens/onboarding/basic_info_screen.dart';
import 'package:my_ai_app/screens/onboarding/generating_plan_screen.dart';
import 'package:my_ai_app/services/api_client.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixture_loader.dart';

void main() {
  OnboardingProvider validForm() => OnboardingProvider()
    ..updateBasicInfo(newAge: 22, newGender: 'Nam', newHeight: 168, newWeight: 62)
    ..updateActivity('Vận động nhẹ')
    ..updateGoal('Giảm mỡ');
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<(PlanProvider, SharedPreferences, ApiClient)> setup(
    http.Client client, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://api.test', httpClient: client, planTimeout: timeout);
    addTearDown(api.close);
    return (PlanProvider(api: api, prefs: prefs), prefs, api);
  }

  Widget app(PlanProvider plans, OnboardingProvider form, {bool fullForm = false}) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: plans),
      ChangeNotifierProvider.value(value: form),
    ],
    child: MaterialApp(
      onGenerateRoute: appGenerateRoute,
      home: fullForm ? const BasicInfoScreen() : GeneratingPlanScreen(profile: form.toProfile()),
    ),
  );

  http.Response success() => http.Response.bytes(utf8.encode(jsonEncode(loadFixture('generate_plan'))), 200);

  testWidgets('điền onboarding → request đúng → lưu plan thật → mở kết quả, chỉ sau response', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    final (plans, prefs, api) = await setup(
      MockClient((request) {
        requests.add(request);
        return pending.future;
      }),
    );
    final form = OnboardingProvider();
    await tester.pumpWidget(app(plans, form, fullForm: true));
    await tester.enterText(find.byType(TextField).at(0), '35');
    await tester.enterText(find.byType(TextField).at(1), '165');
    await tester.enterText(find.byType(TextField).at(2), '64.5');
    await tester.tap(find.text('Nữ'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vận động nhiều'));
    await tester.tap(find.text('Tăng cơ'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    for (final entry in {'allergies': 'Trứng', 'injuries': 'Vai', 'healthConditions': 'Gout'}.entries) {
      final toggle = find.byKey(Key('restriction-${entry.key}'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final chip = find.widgetWithText(FilterChip, entry.value);
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    final submit = find.text('Tạo kế hoạch của tôi');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/v1/generate-plan');
    expect(jsonDecode(requests.single.body), form.toProfile().toJson());
    expect(jsonDecode(requests.single.body)['weight_kg'], 64.5);
    expect(jsonDecode(requests.single.body)['activity_level'], 'active');
    expect(find.byKey(const Key('generate-loading')), findsOneWidget);
    await tester.pump(const Duration(seconds: 8));
    expect(find.byKey(const Key('generated-plan')), findsNothing);
    expect(prefs.containsKey(PlanProvider.planKey), isFalse);
    pending.complete(success());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('generated-plan')), findsOneWidget);
    expect(find.text(loadFixture('generate_plan')['days'][0]['meals'][0]['name']), findsOneWidget);
    expect(jsonDecode(prefs.getString(PlanProvider.planKey)!), loadFixture('generate_plan'));
    expect(jsonDecode(prefs.getString(PlanProvider.profileKey)!), form.toProfile().toJson());
    expect(prefs.containsKey(PlanProvider.scheduleKey), isTrue);
    final restored = PlanProvider(api: api, prefs: prefs);
    expect(restored.plan!.toJson(), plans.plan!.toJson());
  });

  for (final failure in ['network', 'timeout', 'validation', 'server', 'bad-json']) {
    testWidgets('$failure: không navigate/mock fallback; retry thành công', (tester) async {
      var calls = 0;
      final requests = <http.Request>[];
      final pending = Completer<http.Response>();
      final (plans, prefs, _) = await setup(
        MockClient((request) async {
          requests.add(request);
          if (++calls > 1) return success();
          switch (failure) {
            case 'network':
              throw http.ClientException('offline');
            case 'timeout':
              return pending.future;
            case 'validation':
              return http.Response('{"message":["age invalid"]}', 400);
            case 'server':
              return http.Response('{}', 500);
            default:
              return http.Response('{}', 200);
          }
        }),
        timeout: const Duration(milliseconds: 100),
      );
      final form = validForm();
      await tester.pumpWidget(app(plans, form));
      await tester.pumpAndSettle();
      final expected = switch (failure) {
        'network' => const NetworkException().message,
        'timeout' => const ApiTimeoutException().message,
        'validation' => const ValidationException([]).message,
        _ => const ServerException().message,
      };
      expect(find.text(expected), findsOneWidget);
      expect(find.byKey(const Key('generated-plan')), findsNothing);
      expect(plans.plan, isNull);
      expect(prefs.containsKey(PlanProvider.planKey), isFalse);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(requests.first.body, requests.last.body);
      expect(find.byKey(const Key('generated-plan')), findsOneWidget);
      if (!pending.isCompleted) pending.complete(success());
    });
  }

  testWidgets('bấm retry hai lần chỉ gửi một request và giữ loading tới response', (tester) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final (plans, _, _) = await setup(
      MockClient((_) {
        if (++calls == 1) throw http.ClientException('offline');
        return pending.future;
      }),
    );
    await tester.pumpWidget(app(plans, validForm()));
    await tester.pumpAndSettle();
    final retry = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Thử lại'));
    retry.onPressed!();
    retry.onPressed!();
    await tester.pump();
    expect(calls, 2);
    expect(find.byKey(const Key('generate-loading')), findsOneWidget);
    expect(find.byKey(const Key('generate-error')), findsNothing);
    pending.complete(success());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('generated-plan')), findsOneWidget);
  });

  testWidgets('provider bận không được coi là generate thành công', (tester) async {
    final pending = Completer<http.Response>();
    var calls = 0;
    final (plans, _, _) = await setup(
      MockClient((_) {
        calls++;
        return pending.future;
      }),
    );
    final form = validForm();
    final active = plans.generate(form.toProfile());
    await tester.pumpWidget(app(plans, form));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byKey(const Key('generated-plan')), findsNothing);
    expect(find.text('Thử lại'), findsOneWidget);
    pending.complete(success());
    await active;
  });

  testWidgets('response sau khi màn bị tháo không navigate hoặc setState disposed', (tester) async {
    final pending = Completer<http.Response>();
    final (plans, _, _) = await setup(MockClient((_) => pending.future));
    await tester.pumpWidget(app(plans, validForm()));
    await tester.pumpWidget(const MaterialApp(home: Text('Đã rời màn hình')));
    pending.complete(success());
    await tester.pumpAndSettle();
    expect(find.text('Đã rời màn hình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
