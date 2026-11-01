import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/feedback/daily_feedback_screen.dart';
import 'package:my_ai_app/screens/home/home_screen.dart';
import 'package:my_ai_app/screens/plan/plan_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';
import 'ui_restoration_test.dart' show themed;

void main() {
  testWidgets(
    'Dashboard and day calendar expose feedback; completed feedback opens read-only without HTTP',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      for (final screen in [const HomeScreen(), const PlanScreen()]) {
        await tester.pumpWidget(themed(h, Scaffold(body: screen)));
        await scrollTo(tester, find.text('Hoàn thành ngày & phản hồi'));
        await tester.tap(find.text('Hoàn thành ngày & phản hồi'));
        await tester.pumpAndSettle();
        expect(find.byType(DailyFeedbackScreen), findsOneWidget);
        expect(h.backend.requests, isEmpty);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
      await tester.tap(find.text('Điều chỉnh kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã lưu phản hồi.'), findsOneWidget);
      final calls = h.backend.requests.length;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Điều chỉnh kế hoạch'), findsNothing);
      expect(h.backend.requests.length, calls);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'feedback fits Pixel2 with text scale 2 and pending/error states',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.625;
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen(), scale: 2));
      expect(tester.takeException(), isNull);
      h.backend.failWith = 500;
      await tester.ensureVisible(find.text('Điều chỉnh kế hoạch'));
      await tester.tap(find.text('Điều chỉnh kế hoạch'));
      await tester.pumpAndSettle();
      expect(h.plans.pendingFeedback, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'feedback submits actual plan profile once while busy, persists server result',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      await h.plans.saveDraft(
        Profile.fromJson({...loadFixture('profile'), 'age': 29}),
      );
      h.backend.hold = Completer<void>();
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
      await tester.tap(find.text('Điều chỉnh kế hoạch'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await tester.pump();
      expect(h.backend.paths, ['/api/v1/feedback']);
      final body = jsonDecode(
        utf8.decode(h.backend.requests.single.bodyBytes),
      ) as Map<String, dynamic>;
      expect(body['profile'], loadFixture('profile'));
      expect(body['day_number'], 1);
      expect(body['intensity'], 'moderate');
      expect(body['body_states'], ['normal']);
      expect(body['eating'], 'on_plan');
      h.backend.hold!.complete();
      await tester.pumpAndSettle();
      expect(h.plans.plan!.toJson(), loadFixture('feedback')['plan']);
      final restored = PlanProvider(api: h.backend.api, prefs: h.prefs);
      expect(restored.plan!.toJson(), h.plans.plan!.toJson());
      expect(restored.draft!.age, 29);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed feedback shows error, keeps old persistence and can retry',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      await h.plans.finishRestore();
      final before = h.prefs.getString(PlanProvider.stateKey);
      h.backend.failWith = 500;
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
      await tester.tap(find.text('Điều chỉnh kế hoạch'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Máy chủ đang gặp sự cố'), findsOneWidget);
      expect(
        jsonDecode(h.prefs.getString(PlanProvider.stateKey)!)['plan'],
        jsonDecode(before!)['plan'],
      );
      expect(h.plans.pendingFeedback, isNotNull);
      expect(h.plans.plan!.toJson(), loadFixture('generate_plan'));
      h.backend.failWith = null;
      await tester.tap(find.text('Thử lại phản hồi'));
      await tester.pumpAndSettle();
      expect(h.backend.paths.length, 2);
      expect(h.plans.plan!.toJson(), loadFixture('feedback')['plan']);
    },
  );
  testWidgets(
    'danger labels map to danger_sign and server warning is shown before leaving',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      h.backend.responses['/api/v1/feedback'] = {
        ...loadFixture('feedback'),
        'safety_warning': {'message': 'Cảnh báo từ máy chủ'},
      };
      await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
      await scrollTo(tester, find.text('Đau ngực'));
      await tester.tap(find.text('Đau ngực'));
      await tester.pump();
      await tester.tap(find.text('Điều chỉnh kế hoạch'));
      await tester.pumpAndSettle();
      final body = jsonDecode(
        utf8.decode(h.backend.requests.single.bodyBytes),
      ) as Map<String, dynamic>;
      expect(body['body_states'], ['danger_sign']);
      expect(find.text('Cảnh báo từ máy chủ'), findsWidgets);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('expired cycle cannot submit feedback', (tester) async {
    final h = await Harness.create(
      tester,
      saved: savedPlan(),
      now: DateTime(2026, 9, 30),
    );
    await tester.pumpWidget(themed(h, const DailyFeedbackScreen()));
    expect(enabled(tester, 'Điều chỉnh kế hoạch'), isFalse);
    expect(h.backend.requests, isEmpty);
  });
}
