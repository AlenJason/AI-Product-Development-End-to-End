import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/feedback_state.dart';
import 'package:my_ai_app/models/plan_schedule.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  late SharedPreferences prefs;
  late FakeBackend backend;
  late Map<String, dynamic> snapshot;
  late DateTime now;
  PlanProvider open() =>
      PlanProvider(api: backend.api, prefs: prefs, now: () => now);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
    now = DateTime(2026, 9, 26, 20);
    final plans = open();
    await plans.generate(Profile.fromJson(loadFixture('profile')));
    final cycle = PlanCycle(plans.profile!, plans.plan!, plans.schedule!);
    final nextJson = plans.plan!.toJson()..['plan_id'] = 'next-cycle';
    snapshot = jsonDecode(
      prefs.getString(PlanProvider.stateKey)!,
    ) as Map<String, dynamic>;
    snapshot['feedback_pending'] = PendingFeedback(
      cycle,
      const FeedbackAnswers(
        dayNumber: 1,
        intensity: Intensity.hard,
        bodyStates: {BodyState.normal},
        eating: Eating.onPlan,
      ),
    ).toJson();
    snapshot['next_cycle'] = {
      'profile': cycle.profile.toJson(),
      'plan': nextJson,
      'schedule': PlanSchedule.startingOn(
        'next-cycle',
        DateTime(2026, 9, 29),
      ).toJson(),
    };
    snapshot['history'] = [cycle.toJson()];
    snapshot['feedback_receipts'] = {
      '${cycle.plan.planId}:2': LocalFeedbackReceipt(
        planId: cycle.plan.planId,
        answers: const FeedbackAnswers(
          dayNumber: 2,
          intensity: Intensity.moderate,
          bodyStates: {BodyState.normal},
          eating: Eating.onPlan,
        ),
        savedAt: now,
        changed: false,
      ).toJson(),
    };
    backend.requests.clear();
  });
  Future<void> seed() =>
      prefs.setString(PlanProvider.stateKey, jsonEncode(snapshot));
  test('corrupt history isolates failure and retains pending, queued cycle and receipts', () async {
    snapshot['history'] = 'not a list';
    await seed();
    final raw = prefs.getString(PlanProvider.stateKey);
    final plans = open();
    await plans.finishRestore();
    expect(plans.pendingFeedback?.toJson(), snapshot['feedback_pending']);
    expect(plans.nextCycle?.toJson(), snapshot['next_cycle']);
    expect(plans.hasFeedback(2), isTrue);
    expect(plans.restoreWarning, isNotNull);
    expect(prefs.getString(PlanProvider.stateKey), raw);
    expect(backend.requests, isEmpty);
  });
  test(
    'invalid pending profile does not discard valid next cycle or history',
    () async {
      snapshot['feedback_pending']['cycle']['profile']['age'] = 10;
      await seed();
      final plans = open();
      expect(plans.pendingFeedback, isNull);
      expect(plans.nextCycle?.toJson(), snapshot['next_cycle']);
      expect(plans.history, hasLength(1));
      expect(plans.hasPlan, isTrue);
    },
  );
  test(
    'invalid next cycle does not discard valid pending and history',
    () async {
      snapshot['next_cycle']['plan']['days'] = [];
      await seed();
      final plans = open();
      expect(plans.nextCycle, isNull);
      expect(plans.pendingFeedback?.toJson(), snapshot['feedback_pending']);
      expect(plans.history, hasLength(1));
      expect(plans.hasFeedback(2), isTrue);
    },
  );
  test(
    'bad receipt or history entry cannot hide subsequent valid entries',
    () async {
      snapshot['feedback_receipts'] = {
        'broken': {'answers': null},
        ...snapshot['feedback_receipts'],
      };
      snapshot['history'] = [
        {'plan': null},
        ...snapshot['history'],
      ];
      await seed();
      final plans = open();
      expect(plans.hasFeedback(2), isTrue);
      expect(plans.history, hasLength(1));
      expect(plans.pendingFeedback, isNotNull);
      expect(plans.nextCycle, isNotNull);
    },
  );
  test('explicit save after partial restore preserves valid state across another restart', () async {
    snapshot['history'] = 'broken';
    await seed();
    final plans = open();
    await plans.saveDraft(
      Profile.fromJson({...loadFixture('profile'), 'age': 29}),
    );
    final restored = open();
    expect(restored.pendingFeedback?.toJson(), snapshot['feedback_pending']);
    expect(restored.nextCycle?.toJson(), snapshot['next_cycle']);
    expect(restored.draft!.age, 29);
    expect(restored.hasFeedback(2), isTrue);
    expect(
      prefs.getKeys().where(
        (k) => k.startsWith('${PlanProvider.stateKey}.recovery.'),
      ),
      isNotEmpty,
    );
  });
  test('restart restores exact pending request without new HTTP or a changed plan/day key', () async {
    await seed();
    final plans = open();
    await plans.finishRestore();
    final again = open();
    expect(again.pendingFeedback?.toJson(), snapshot['feedback_pending']);
    expect(again.plan!.planId, snapshot['plan']['plan_id']);
    expect(backend.requests, isEmpty);
  });
  test('N04 snapshot without extension fields remains compatible', () async {
    for (final k in [
      'feedback_pending',
      'feedback_receipts',
      'next_cycle',
      'history',
    ]) {
      snapshot.remove(k);
    }
    await seed();
    final plans = open();
    await plans.finishRestore();
    expect(plans.hasPlan, isTrue);
    expect(plans.pendingFeedback, isNull);
    expect(plans.nextCycle, isNull);
    expect(plans.restoreWarning, isNull);
    expect(backend.requests, isEmpty);
  });
  test(
    'queued cycle is not activated before start after isolated corruption',
    () async {
      snapshot['feedback_pending'] = null;
      snapshot['history'] = 'broken';
      await seed();
      final plans = open();
      await plans.finishRestore();
      await plans.activateScheduledCycle();
      expect(plans.plan!.planId, snapshot['plan']['plan_id']);
      expect(plans.nextCycle?.plan.planId, 'next-cycle');
      expect(backend.requests, isEmpty);
    },
  );
  test('corrupt grocery archive cannot hide valid current checklist', () async {
    snapshot['feedback_pending'] = null;
    snapshot['next_cycle'] = null;
    await seed();
    final plans = open();
    final group = plans.plan!.groceryList.first,
        key = GroceryProvider.keyOf(group.category, group.items.first);
    await prefs.setString(
      GroceryProvider.stateKey,
      jsonEncode({
        'plan_id': plans.plan!.planId,
        'bought': [key],
        'have': [],
        'history': {
          'broken': {'bought': 42, 'have': []},
        },
      }),
    );
    final grocery = GroceryProvider(prefs: prefs, plans: plans);
    addTearDown(grocery.dispose);
    expect(grocery.isBought(key), isTrue);
    expect(grocery.restoreWarning, isNotNull);
  });

  test('recovery backup failure blocks overwrite and retains the original snapshot', () async {
    snapshot['history'] = 'broken';
    await seed();
    final raw = prefs.getString(PlanProvider.stateKey);
    final plans = PlanProvider(
      api: backend.api,
      prefs: prefs,
      now: () => now,
      write: (key, value) async =>
          key.contains('.recovery.') ? false : prefs.setString(key, value),
    );
    await expectLater(
      plans.saveDraft(Profile.fromJson({...loadFixture('profile'), 'age': 29})),
      throwsStateError,
    );
    expect(prefs.getString(PlanProvider.stateKey), raw);
    expect(plans.pendingFeedback?.toJson(), snapshot['feedback_pending']);
    expect(plans.nextCycle?.toJson(), snapshot['next_cycle']);
    expect(backend.requests, isEmpty);
  });

  test('successful recovery backup keeps exact original bytes and a repeat save does not duplicate it', () async {
    snapshot['history'] = 'broken';
    await seed();
    final raw = prefs.getString(PlanProvider.stateKey);
    final plans = open();
    await plans.saveDraft(
      Profile.fromJson({...loadFixture('profile'), 'age': 29}),
    );
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('${PlanProvider.stateKey}.recovery.'))
        .toList();
    expect(keys, hasLength(1));
    expect(prefs.getString(keys.single), raw);
    await plans.saveDraft(
      Profile.fromJson({...loadFixture('profile'), 'age': 30}),
    );
    expect(
      prefs.getKeys().where(
        (k) => k.startsWith('${PlanProvider.stateKey}.recovery.'),
      ),
      hasLength(1),
    );
  });

  test('corrupt grocery field preserves other field through explicit save and restart', () async {
    snapshot['feedback_pending'] = null;
    snapshot['next_cycle'] = null;
    await seed();
    final plans = open();
    final group = plans.plan!.groceryList.first;
    final key = GroceryProvider.keyOf(group.category, group.items.first);
    final raw = jsonEncode({
      'plan_id': plans.plan!.planId,
      'bought': [key],
      'have': 123,
    });
    await prefs.setString(GroceryProvider.stateKey, raw);
    final grocery = GroceryProvider(prefs: prefs, plans: plans);
    addTearDown(grocery.dispose);
    expect(grocery.isBought(key), isTrue);
    await grocery.markHave(key);
    final again = GroceryProvider(prefs: prefs, plans: plans);
    addTearDown(again.dispose);
    expect(again.isHave(key), isTrue);
    final backup = prefs.getKeys().singleWhere(
      (k) => k.startsWith('${GroceryProvider.stateKey}.recovery.'),
    );
    expect(prefs.getString(backup), raw);
  });
}
