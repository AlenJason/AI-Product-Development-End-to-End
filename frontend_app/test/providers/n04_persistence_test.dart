import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/plan_schedule.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final profile = Profile.fromJson(loadFixture('profile'));
  final edited = Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'});
  final legacy = <String, Object>{
    PlanProvider.profileKey: jsonEncode(profile.toJson()),
    PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
  };
  late SharedPreferences prefs;
  late FakeBackend backend;
  var now = DateTime(2026, 9, 26, 23, 59, 59);
  PlanProvider open({
    Future<bool> Function(String, String)? write,
    ApiClient? api,
  }) => PlanProvider(
    api: api ?? backend.api,
    prefs: prefs,
    now: () => now,
    write: write,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues(legacy);
    prefs = await SharedPreferences.getInstance();
    backend = FakeBackend();
    now = DateTime(2026, 9, 26, 23, 59, 59);
  });
  test('legacy migration anchors date across restart without HTTP', () async {
    final p = open();
    await p.finishRestore();
    now = DateTime(2026, 9, 27);
    expect(open().todayNumber, 2);
    expect(backend.requests, isEmpty);
  });
  test('swaps, draft and checklist survive snapshot restart; mirrors cannot override', () async {
    final p = open();
    await p.swapMeal('m1_2');
    await p.swapExercise('e1_2');
    await p.saveDraft(edited);
    final g = GroceryProvider(prefs: prefs, plans: p);
    final group = p.plan!.groceryList.first;
    final key = GroceryProvider.keyOf(group.category, group.items.first);
    await g.toggleBought(key);
    await prefs.setString(PlanProvider.planKey, 'broken');
    final restored = open();
    final checklist = GroceryProvider(prefs: prefs, plans: restored);
    expect(restored.plan!.toJson(), p.plan!.toJson());
    expect(restored.draft!.sameAs(edited), isTrue);
    expect(checklist.isBought(key), isTrue);
    expect(restored.restoreWarning, isNull);
    g.dispose();
    checklist.dispose();
  });
  for (final failure in ['false', 'throw']) {
    test(
      'failed $failure write keeps active plan, draft and disk snapshot',
      () async {
        await open().finishRestore();
        final before = prefs.getString(PlanProvider.stateKey);
        final p = open(
          write: (_, _) async {
            if (failure == 'throw') throw StateError('disk');
            return false;
          },
        );
        final original = p.plan!.toJson();
        await expectLater(p.generate(edited), throwsStateError);
        expect(p.plan!.toJson(), original);
        expect(p.profile!.sameAs(profile), isTrue);
        expect(p.busy, isFalse);
        expect(prefs.getString(PlanProvider.stateKey), before);
        expect(open().plan!.toJson(), original);
      },
    );
  }
  test(
    'offline swap and regenerate keep old snapshot and pending draft',
    () async {
      final p = open();
      await p.saveDraft(edited);
      final before = prefs.getString(PlanProvider.stateKey);
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'http://offline.test',
        httpClient: MockClient((_) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      final offline = open(api: api);
      expect(calls, 0);
      expect(offline.hasPlan, isTrue);
      await expectLater(offline.swapMeal('m1_2'), throwsException);
      await expectLater(offline.generate(edited), throwsException);
      expect(calls, 2);
      expect(prefs.getString(PlanProvider.stateKey), before);
      expect(offline.draft!.sameAs(edited), isTrue);
      api.close();
    },
  );
  test('only save does not call API; failed regeneration keeps draft; success applies', () async {
    final p = open();
    final original = p.plan!.toJson();
    await p.saveDraft(edited);
    expect(backend.requests, isEmpty);
    backend.failWith = 500;
    await expectLater(p.generate(edited), throwsException);
    expect(p.plan!.toJson(), original);
    expect(p.hasPendingProfile, isTrue);
    backend.failWith = null;
    await p.generate(edited);
    expect(p.hasPendingProfile, isFalse);
    expect(open().profile!.sameAs(edited), isTrue);
  });
  test('corrupt draft cannot hide valid plan or overwrite snapshot', () async {
    await open().finishRestore();
    final state = jsonDecode(
      prefs.getString(PlanProvider.stateKey)!,
    ) as Map<String, dynamic>;
    state['draft'] = {'bad': true};
    final raw = jsonEncode(state);
    await prefs.setString(PlanProvider.stateKey, raw);
    final p = open();
    await p.finishRestore();
    expect(p.hasPlan, isTrue);
    expect(p.draft, isNull);
    expect(p.restoreWarning, isNotNull);
    expect(prefs.getString(PlanProvider.stateKey), raw);
  });
  test(
    'incompatible snapshot retained without fallback to stale legacy',
    () async {
      await prefs.setString(PlanProvider.stateKey, '{"version":99}');
      final p = open();
      await p.finishRestore();
      expect(p.hasPlan, isFalse);
      expect(p.restoreWarning, isNotNull);
      expect(prefs.getString(PlanProvider.stateKey), '{"version":99}');
      expect(backend.requests, isEmpty);
    },
  );
  test('wrong preference type retained without crash', () async {
    await prefs.setInt(PlanProvider.planKey, 42);
    final p = open();
    await p.finishRestore();
    expect(p.hasPlan, isFalse);
    expect(prefs.getInt(PlanProvider.planKey), 42);
  });
  test(
    'invalid legacy draft prevents automatic migration or deletion',
    () async {
      final raw = jsonEncode({...profile.toJson(), 'age': 17});
      await prefs.setString(PlanProvider.draftKey, raw);
      final p = open();
      await p.finishRestore();
      expect(p.hasPlan, isTrue);
      expect(p.restoreWarning, isNotNull);
      expect(prefs.getString(PlanProvider.draftKey), raw);
      expect(prefs.containsKey(PlanProvider.stateKey), isFalse);
    },
  );
  test(
    'calendar future, midnight, expiry and local date fields do not generate',
    () async {
      final p = open();
      await p.finishRestore();
      var notifications = 0;
      p.addListener(() => notifications++);
      now = DateTime(2026, 9, 25);
      p.refreshDay();
      expect(p.todayNumber, 0);
      now = DateTime(2026, 9, 27);
      p.refreshDay();
      expect(p.todayNumber, 2);
      p.refreshDay();
      expect(notifications, 2);
      now = DateTime(2026, 9, 29);
      p.refreshDay();
      expect(p.todayNumber, 4);
      expect(open().todayNumber, 4);
      expect(backend.requests, isEmpty);
      final s = PlanSchedule.startingOn('p', DateTime(2026, 9, 26, 23, 59));
      expect(s.dayNumberOn(DateTime(2026, 9, 27, 0, 1)), 2);
      expect(s.dateOfDay(3), DateTime.utc(2026, 9, 28));
    },
  );
  for (final date in ['2026-02-30', '2026-09-26T00:00:00Z', 'bad']) {
    test('invalid calendar $date rejected', () {
      expect(
        () => PlanSchedule.fromJson({'plan_id': 'p', 'start_date': date}),
        throwsFormatException,
      );
    });
  }
  test('unsafe edited profile rejected before request and storage', () async {
    final p = open();
    await p.finishRestore();
    final before = prefs.getString(PlanProvider.stateKey);
    final unsafe = Profile.fromJson({...profile.toJson(), 'age': 17});
    await expectLater(p.saveDraft(unsafe), throwsFormatException);
    await expectLater(p.generate(unsafe), throwsFormatException);
    expect(backend.requests, isEmpty);
    expect(prefs.getString(PlanProvider.stateKey), before);
  });
}
