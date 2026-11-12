import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/services/api_client.dart';

import '../fixture_loader.dart';

class _RealHttp extends HttpOverrides {}

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('N05_BACKEND_URL');
  test(
    'Flutter providers → actual Nest HTTP → mocked AI/rules → SQLite → local restart and next cycle',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(
        baseUrl: url,
        httpClient: IOClient(_RealHttp().createHttpClient(null)),
      );
      addTearDown(api.close);
      // Bridge health must be mock auth; do not aim this test at a live deployment.
      expect((await api.health()).authMode, 'mock');
      var now = DateTime(2026, 9, 26, 20);
      var plans = PlanProvider(api: api, prefs: prefs, now: () => now);
      await plans.generate(Profile.fromJson(loadFixture('profile')));
      final old = plans.plan!.planId;
      expect(plans.plan!.source, PlanSource.groq);
      await plans.swapMeal('m1_2');
      final swapped = plans.plan!.days.first.meals[1].name;
      final groceries = GroceryProvider(prefs: prefs, plans: plans);
      addTearDown(groceries.dispose);
      final group = plans.plan!.groceryList.first,
          key = GroceryProvider.keyOf(group.category, group.items.first);
      await groceries.toggleBought(key);
      for (var day = 1; day <= 3; day++) {
        now = DateTime(2026, 9, 25 + day, 20);
        await plans.submitFeedback(
          FeedbackAnswers(
            dayNumber: day,
            intensity: Intensity.hard,
            bodyStates: {BodyState.normal},
            eating: Eating.onPlan,
          ),
        );
        expect(plans.hasFeedback(day), isTrue);
        expect(plans.plan!.planId, old);
        expect(plans.plan!.days.first.meals[1].name, swapped);
      }
      final next = plans.nextCycle!.plan.planId;
      expect(next, isNot(old));
      expect(groceries.isBought(key), isTrue);
      plans = PlanProvider(api: api, prefs: prefs, now: () => now);
      await plans.finishRestore();
      expect(plans.plan!.planId, old);
      now = DateTime(2026, 9, 29, 1);
      await plans.activateScheduledCycle();
      expect(plans.plan!.planId, next);
      expect(plans.todayNumber, 1);
      expect(plans.history.single.plan.planId, old);
      expect(plans.feedbackFor(old, 3), isNotNull);
    },
    skip: url.isEmpty
        ? 'Opt-in isolated local Nest bridge; see docs/N05_FEEDBACK.md'
        : false,
  );
}
