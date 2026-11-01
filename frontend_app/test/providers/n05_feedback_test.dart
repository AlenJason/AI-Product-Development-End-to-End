import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  late FakeBackend backend;
  late SharedPreferences prefs;
  late PlanProvider plans;
  late DateTime now;
  PlanProvider reopen({Future<bool> Function(String, String)? write}) =>
      PlanProvider(
        api: backend.api,
        prefs: prefs,
        now: () => now,
        write: write,
      );
  FeedbackAnswers answer(int day) => FeedbackAnswers(
    dayNumber: day,
    intensity: Intensity.hard,
    bodyStates: {BodyState.normal},
    eating: Eating.onPlan,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
    now = DateTime(2026, 9, 26, 20);
    plans = reopen();
    await plans.generate(Profile.fromJson(loadFixture('profile')));
    backend.requests.clear();
  });
  test(
    'receipt survives restart, duplicate and future feedback cannot call HTTP',
    () async {
      await expectLater(plans.submitFeedback(answer(2)), throwsStateError);
      expect(backend.requests, isEmpty);
      await plans.submitFeedback(answer(1));
      final restored = reopen();
      expect(restored.hasFeedback(1), isTrue);
      await expectLater(restored.submitFeedback(answer(1)), throwsStateError);
      expect(backend.requests.length, 1);
    },
  );
  test('ambiguous failure freezes request across restart and preserves plan/draft/checklist', () async {
    final groceries = GroceryProvider(prefs: prefs, plans: plans);
    addTearDown(groceries.dispose);
    final group = plans.plan!.groceryList.first,
        key = GroceryProvider.keyOf(group.category, group.items.first);
    await groceries.toggleBought(key);
    await plans.saveDraft(
      Profile.fromJson({...loadFixture('profile'), 'age': 29}),
    );
    final original = plans.plan!.toJson();
    backend.failWith = 500;
    await expectLater(plans.submitFeedback(answer(1)), throwsException);
    expect(plans.hasFeedback(1), isFalse);
    expect(plans.pendingFeedback, isNotNull);
    expect(plans.plan!.toJson(), original);
    expect(groceries.isBought(key), isTrue);
    plans = reopen();
    expect(plans.pendingFeedback, isNotNull);
    expect(plans.draft!.age, 29);
    await expectLater(plans.swapMeal('m1_1'), throwsStateError);
    backend.failWith = null;
    await plans.retryFeedback();
    expect(backend.requests[0].body, backend.requests[1].body);
    expect(plans.pendingFeedback, isNull);
    expect(plans.hasFeedback(1), isTrue);
  });
  test(
    'failed initial write does not call HTTP or mark feedback completed',
    () async {
      plans = reopen(write: (_, _) async => false);
      await expectLater(plans.submitFeedback(answer(1)), throwsStateError);
      expect(backend.requests, isEmpty);
      expect(plans.pendingFeedback, isNull);
      expect(plans.hasFeedback(1), isFalse);
    },
  );
  test('failed final write retains pending and old plan; replay commits once storage recovers', () async {
    var writes = 0;
    plans = reopen(
      write: (k, v) async {
        writes++;
        return writes == 2 ? false : prefs.setString(k, v);
      },
    );
    final before = plans.plan!.toJson();
    await expectLater(plans.submitFeedback(answer(1)), throwsStateError);
    expect(plans.plan!.toJson(), before);
    expect(plans.pendingFeedback, isNotNull);
    expect(plans.hasFeedback(1), isFalse);
    plans = reopen();
    await plans.retryFeedback();
    expect(plans.hasFeedback(1), isTrue);
    expect(backend.requests.first.body, backend.requests.last.body);
  });
  test('three days preserve past days, queue tomorrow, restore offline and archive old checklist', () async {
    var groceries = GroceryProvider(prefs: prefs, plans: plans);
    final old = plans.plan!.planId,
        group = plans.plan!.groceryList.first,
        key = GroceryProvider.keyOf(group.category, group.items.first);
    await groceries.markHave(key);
    await plans.submitFeedback(answer(1));
    final days = plans.plan!.days;
    now = DateTime(2026, 9, 27, 20);
    await plans.submitFeedback(answer(2));
    expect(plans.plan!.days[0].toJson(), days[0].toJson());
    expect(plans.plan!.days[1].toJson(), days[1].toJson());
    now = DateTime(2026, 9, 28, 20);
    await plans.submitFeedback(answer(3));
    expect(plans.plan!.planId, old);
    expect(plans.todayNumber, 3);
    expect(plans.nextCycle!.schedule.startDate, DateTime.utc(2026, 9, 29));
    expect(plans.history.single.plan.planId, old);
    expect(groceries.isHave(key), isTrue);
    groceries.dispose();
    plans = reopen();
    await plans.finishRestore();
    expect(plans.plan!.planId, old);
    groceries = GroceryProvider(prefs: prefs, plans: plans);
    backend.failWith = 500;
    final calls = backend.requests.length;
    now = DateTime(2026, 9, 29, 1);
    await plans.activateScheduledCycle();
    await pumpEventQueue();
    expect(plans.plan!.planId, isNot(old));
    expect(plans.todayNumber, 1);
    expect(plans.nextCycle, isNull);
    expect(backend.requests.length, calls);
    expect(groceries.isHave(key), isFalse);
    expect(groceries.checklistFor(old)!['have'], contains(key));
    expect(reopen().feedbackFor(old, 3), isNotNull);
    groceries.dispose();
  });
  test('invalid API mutation of past days is rejected and exact pending body retained', () async {
    final bad = loadFixture('feedback');
    bad['plan']['days'][0]['meals'][0]['name'] = 'Unexpected overwrite';
    backend.responses['/api/v1/feedback'] = bad;
    final original = plans.plan!.toJson();
    await expectLater(plans.submitFeedback(answer(1)), throwsFormatException);
    expect(plans.plan!.toJson(), original);
    expect(plans.pendingFeedback, isNotNull);
    expect(
      jsonDecode(prefs.getString(PlanProvider.stateKey)!)['plan'],
      original,
    );
  });
  test(
    'due activation write failure keeps both cycles and succeeds on retry',
    () async {
      now = DateTime(2026, 9, 28, 20);
      await plans.submitFeedback(answer(3));
      final old = plans.plan!.planId;
      now = DateTime(2026, 9, 29);
      plans = reopen(write: (_, _) async => false);
      await plans.finishRestore();
      expect(plans.plan!.planId, old);
      expect(plans.nextCycle, isNotNull);
      expect(plans.restoreWarning, isNotNull);
      plans = reopen();
      await plans.finishRestore();
      expect(plans.plan!.planId, isNot(old));
    },
  );
}
