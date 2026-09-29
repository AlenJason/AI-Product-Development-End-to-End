import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/models/plan_schedule.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fixture_loader.dart';

// Dựng app hoặc một màn hình với backend giả (fixture hợp đồng), dữ liệu đã lưu và đồng hồ giả, trên màn hình cỡ
// điện thoại (411×914 dp — Pixel 8). Không gọi mạng thật.
class Harness {
  Harness._(this.backend, this.prefs, this.auth, this.plans, this.grocery);

  final FakeBackend backend;
  final SharedPreferences prefs;
  final AuthProvider auth;
  final PlanProvider plans;
  final GroceryProvider grocery;

  static Future<Harness> create(WidgetTester tester, {Map<String, Object> saved = const {}, DateTime? now}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final clock = now ?? planStart;
    final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => clock);
    return Harness._(
      backend,
      prefs,
      AuthProvider(api: backend.api, prefs: prefs),
      plans,
      GroceryProvider(prefs: prefs, plans: plans),
    );
  }

  Widget app() => SmartFitApp(auth: auth, plans: plans, grocery: grocery);

  // Một màn hình đứng riêng, có Scaffold để hiện SnackBar.
  Widget screen(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: plans),
      ChangeNotifierProvider.value(value: grocery),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// Plan fixture bắt đầu ngày 26/9/2026.
final planStart = DateTime(2026, 9, 26, 9);

Map<String, Object> savedPlan({Map<String, dynamic>? profile}) {
  final plan = loadFixture('generate_plan');
  return {
    PlanProvider.profileKey: jsonEncode(profile ?? loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(plan),
    PlanProvider.scheduleKey: jsonEncode(PlanSchedule.startingOn(plan['plan_id'] as String, planStart).toJson()),
  };
}

Finder field(String label) => find.widgetWithText(TextField, label);

// Danh sách chỉ dựng phần đang hiện: cuộn danh sách chính (không phải vùng cuộn của ô nhập) tới [finder].
// scrollUntilVisible dừng khi widget đã được dựng dù còn sát ngoài mép — ensureVisible kéo hẳn vào màn hình.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String buttonText) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(of: find.text(buttonText), matching: find.bySubtype<ButtonStyleButton>()).first,
    )
    .enabled;

// Điền đủ 3 bước Onboarding: nữ 22 tuổi, 168 cm, 62 kg, vận động nhẹ, Giảm mỡ, dị ứng hải sản, đau gối.
Future<void> fillOnboarding(WidgetTester tester) async {
  await tester.tap(find.text('Nữ'));
  await tester.enterText(field('Tuổi'), '22');
  await tester.enterText(field('Chiều cao (cm)'), '168');
  await tester.enterText(field('Cân nặng (kg)'), '62');
  await tester.pump();
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vận động nhẹ'));
  await tester.tap(find.text('Giảm mỡ & giữ cơ'));
  await tester.pump();
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tôi có dị ứng thực phẩm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hải sản'));
  await tester.tap(find.text('Tôi có chấn thương'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đầu gối'));
  await tester.pump();
}
