import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/services/api_client.dart';
import 'package:my_ai_app/routes.dart';
import 'package:my_ai_app/screens/onboarding/generating_plan_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  // I/O thật cần đồng hồ thật; widget tests với MockClient nằm ở file dùng fake clock riêng.
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  const baseUrl = String.fromEnvironment('N01_BACKEND_URL');
  test('N01: hồ sơ → backend local thật → parse/lưu/restore; hồ sơ khác đổi target', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: baseUrl, httpClient: IOClient(_RealHttpOverrides().createHttpClient(null)));
    addTearDown(api.close);
    final health = await api.health();
    // Chỉ backend mock/no-key: test không được tiêu quota Gemini/Google hoặc ghi DB người dùng.
    expect(health.gemini, 'fallback');
    expect(health.authMode, 'mock');
    final plans = PlanProvider(api: api, prefs: prefs);
    final form = OnboardingProvider()
      ..updateBasicInfo(newAge: 22, newGender: 'Nam', newHeight: 168, newWeight: 62)
      ..updateActivity('Vận động nhẹ')
      ..updateGoal('Duy trì');
    await plans.generate(form.toProfile());
    final first = plans.plan!;
    expect(first.days, hasLength(3));
    expect(first.days.every((day) => day.meals.length == 3), isTrue);
    form.updateBasicInfo(newAge: 35, newGender: 'Nữ', newHeight: 165, newWeight: 64.5);
    await plans.generate(form.toProfile());
    expect(plans.plan!.planId, isNot(first.planId));
    expect(plans.plan!.dailyTarget.targetCalories, isNot(first.dailyTarget.targetCalories));
    final restored = PlanProvider(api: api, prefs: prefs);
    expect(restored.profile!.toJson(), form.toProfile().toJson());
    expect(restored.plan!.toJson(), plans.plan!.toJson());
    // N02: contract thai kỳ và restrictions vẫn hoạt động qua backend thật.
    form.updatePregnancy(true);
    form.updateRestrictions(newAllergies: 'Trứng', newInjuries: 'Đầu gối', conditions: 'Gout');
    await plans.generate(form.toProfile());
    expect(plans.profile!.pregnantOrBreastfeeding, isTrue);
    expect(plans.profile!.restrictions.allergies, 'Trứng');
    expect(plans.plan!.warnings.any((message) => message.toLowerCase().contains('mang thai')), isTrue);
  }, skip: baseUrl.isEmpty ? 'Chạy tay với --dart-define=N01_BACKEND_URL=http://127.0.0.1:<port>' : false);

  testWidgets('N01: loading widget → HTTP backend thật → persistence → màn kết quả thật', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final wire = IOClient(_RealHttpOverrides().createHttpClient(null));
    addTearDown(wire.close);
    final guard = ApiClient(baseUrl: baseUrl, httpClient: wire);
    final health = await tester.runAsync(guard.health);
    expect(health!.gemini, 'fallback');
    expect(health.authMode, 'mock');
    final responseReceived = Completer<void>();
    // Adapter chỉ ghi nhận completion; response lấy nguyên từ HTTP thật, không dùng fixture/fallback.
    final api = ApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        // MockClient đã finalize request khi gọi handler; tạo bản gửi HTTP từ cùng body/headers.
        final outbound = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        final response = await http.Response.fromStream(await wire.send(outbound));
        responseReceived.complete();
        return response;
      }),
    );
    addTearDown(api.close);
    final plans = PlanProvider(api: api, prefs: prefs);
    final form = OnboardingProvider()
      ..updateBasicInfo(newAge: 22, newGender: 'Nam', newHeight: 168, newWeight: 62)
      ..updateActivity('Vận động nhẹ')
      ..updateGoal('Duy trì');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: plans,
        child: MaterialApp(
          onGenerateRoute: appGenerateRoute,
          home: GeneratingPlanScreen(profile: form.toProfile()),
        ),
      ),
    );
    expect(find.byKey(const Key('generate-loading')), findsOneWidget);
    await tester.runAsync(() => responseReceived.future.timeout(const Duration(seconds: 15)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('generated-plan')), findsOneWidget);
    expect(plans.plan!.days, hasLength(3));
    expect(prefs.getString(PlanProvider.planKey), isNotNull);
    final restored = PlanProvider(api: api, prefs: prefs);
    expect(restored.plan!.toJson(), plans.plan!.toJson());
  }, skip: baseUrl.isEmpty);
}
