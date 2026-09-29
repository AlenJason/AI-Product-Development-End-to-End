import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_ai_app/config/api_config.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/services/api_client.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/app_harness.dart' show fillOnboarding, scrollTo;

// Chạy TAY trên máy ảo hoặc điện thoại thật, khi backend_api đang chạy ở chế độ giả lập — không chạy trong CI
// (`flutter test` chỉ chạy thư mục test/):
//
//   cd backend_api && npm run start:dev          # .env không có GEMINI_API_KEY, AUTH_MODE=mock
//   cd frontend_app && flutter test integration_test -d emulator-5554
//   (điện thoại thật: thêm --dart-define=API_BASE_URL=http://<IP LAN máy chạy backend>:3000)
//
// Gọi backend THẬT qua mạng của thiết bị, nên kiểm được thứ test trong test/ không chạm tới: quyền mạng, HTTP không
// mã hoá ở bản debug, địa chỉ 10.0.2.2, shared_preferences thật trên máy, lỗi mạng thật. Xoá dữ liệu đã lưu của
// app trên thiết bị đó.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const profile = Profile(
    age: 22,
    gender: Gender.female,
    heightCm: 168,
    weightKg: 62,
    activityLevel: ActivityLevel.light,
    goal: Goal.cut,
    restrictions: Restrictions(allergies: 'Hải sản', injuries: 'Đau gối'),
  );

  testWidgets('app trên thiết bị gọi được backend thật: tạo plan, đổi món, đổi bài, feedback, lịch sử, lưu trên máy',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final api = ApiClient(baseUrl: resolveApiBaseUrl());

    final health = await api.health();
    expect(health.status, 'ok');
    // Có khoá Gemini thì mỗi lần chạy tốn hạn mức thật (20 lần/ngày) — test không bao giờ gọi Gemini thật (#17).
    expect(health.gemini, 'fallback', reason: 'Tắt GEMINI_API_KEY trong backend_api/.env rồi khởi động lại backend');
    expect(health.authMode, 'mock', reason: 'Test đăng nhập bằng mock:<email> — cần AUTH_MODE=mock');

    final auth = AuthProvider(api: api, prefs: prefs);
    final plans = PlanProvider(api: api, prefs: prefs);
    await auth.signIn('mock:android-smoke@example.com');
    expect(auth.isSignedIn, isTrue);

    await plans.generate(profile);
    final plan = plans.plan!;
    expect(plan.days, hasLength(3));
    // Dị ứng hải sản: thực đơn mẫu có "Nước mắm" — backend phải thay món đó (bộ khớp từ khoá, #23).
    final ingredients = plan.days.expand((day) => day.meals).expand((meal) => meal.ingredients).map((i) => i.name);
    expect(ingredients, everyElement(allOf(isNot(contains('Nước mắm')), isNot(contains('Tôm')))));

    final history = await api.history();
    expect(history.map((entry) => entry.id), contains(plan.planId));

    final oldMeal = plan.days.first.meals[1];
    await plans.swapMeal(oldMeal.mealId);
    expect(plans.plan!.planId, plan.planId);
    expect(plans.plan!.days.first.meals[1].name, isNot(oldMeal.name));

    // Động tác thứ 3 (chống đẩy nghiêng, mức 2): đau gối nên squat ở vị trí 2 đã thành động tác mức 1 — không còn
    // gì nhẹ hơn để đổi (BRD v2.7.0).
    final oldExercise = plans.plan!.days.first.workout.exercises[2];
    await plans.swapExercise(oldExercise.exerciseId);
    expect(plans.plan!.days.first.workout.exercises[2].name, isNot(oldExercise.name));

    final feedback = await plans.submitFeedback(const FeedbackAnswers(
        dayNumber: 1, intensity: Intensity.hard, bodyStates: {BodyState.sore}, eating: Eating.onPlan));
    expect(feedback!.safetyWarning, isNull);

    // Lưu thật trên thiết bị: đọc lại từ shared_preferences ra đúng plan đang có.
    final reloaded = PlanProvider(api: api, prefs: prefs);
    expect(reloaded.plan!.toJson(), plans.plan!.toJson());
    expect(AuthProvider(api: ApiClient(baseUrl: resolveApiBaseUrl()), prefs: prefs).isSignedIn, isTrue);

    // Lỗi của server qua mạng thật → đúng loại lỗi, câu tiếng Việt của server.
    await expectLater(
      api.swapMeal(const Profile(age: 22, gender: Gender.female, heightCm: 168, weightKg: 62,
          activityLevel: ActivityLevel.light, goal: Goal.bulk), plans.plan!, oldMeal.mealId),
      throwsA(isA<PlanOutdatedException>().having((e) => e.message, 'message', contains('Kế hoạch'))),
    );

    // Có plan đã lưu → app mở thẳng Dashboard.
    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: GroceryProvider(prefs: prefs, plans: plans)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DashboardScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await auth.deleteAccount();
    expect(auth.isSignedIn, isFalse);
    await plans.clearPlan();
    await prefs.clear();
  });

  testWidgets('không tới được máy chủ → NetworkException, không crash', (tester) async {
    final base = Uri.parse(resolveApiBaseUrl());
    final closedPort = ApiClient(baseUrl: base.replace(port: 1).toString());
    await expectLater(closedPort.health(), throwsA(isA<NetworkException>()));
  });

  // Thao tác giao diện thật trên thiết bị (giai đoạn 6, 7): Onboarding → backend thật tạo plan → Dashboard → đổi món
  // → feedback cuối ngày 1 (bảng trượt, báo điều đã đổi, khoá ngày).
  testWidgets('giao diện trên thiết bị: Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final api = ApiClient(baseUrl: resolveApiBaseUrl());
    final plans = PlanProvider(api: api, prefs: prefs);
    await tester.pumpWidget(SmartFitApp(
      auth: AuthProvider(api: api, prefs: prefs),
      plans: plans,
      grocery: GroceryProvider(prefs: prefs, plans: plans),
    ));
    await fillOnboarding(tester);
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    await pumpUntil(tester, find.text('Hôm nay là Ngày 1'));
    expect(find.text('BỮA SÁNG'), findsOneWidget);

    await tester.tap(find.text('Đổi món').first);
    await pumpUntil(tester, find.textContaining('Đã đổi bữa sáng sang'));
    // SnackBar nổi đè lên thẻ cuối trang khi cửa sổ thấp (macOS 800×600) — ẩn trước khi bấm.
    tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Đánh giá ngày 1'));
    await tester.tap(find.text('Đánh giá ngày 1'));
    await tester.pumpAndSettle();
    for (final label in ['Rất mệt', 'Căng mỏi cơ', 'Đúng thực đơn', 'Gửi và điều chỉnh ngày 2']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await pumpUntil(tester, find.text('Đã lưu đánh giá ngày 1'));
    expect(find.textContaining('Ngày 2: giảm số hiệp'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Đã gửi đánh giá ngày 1'));
    expect(plans.feedbackDays, {1});
    await tester.pumpWidget(const SizedBox());
    await prefs.clear();
  });
}

// Mạng thật: vòng xoay chờ không bao giờ "settle", nên pump tới khi thấy [finder] (tối đa 60 s như timeout của app).
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var waited = 0; waited < 600; waited++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Không thấy $finder sau 60 s');
}
