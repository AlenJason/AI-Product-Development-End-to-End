import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final profile = Profile.fromJson(loadFixture('profile'));
  final saved = {
    PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
  };

  // Đồng hồ giả: test đổi `now` để sang ngày khác.
  var now = DateTime(2026, 9, 26, 9);

  Future<(PlanProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    return (PlanProvider(api: backend.api, prefs: prefs, now: () => now), backend, prefs);
  }

  setUp(() => now = DateTime(2026, 9, 26, 9));

  test('máy chưa có gì → chưa có plan', () async {
    final (provider, _, _) = await create();
    expect(provider.hasPlan, isFalse);
    expect(provider.profile, isNull);
  });

  test('tạo plan → giữ trong bộ nhớ và lưu cả plan lẫn hồ sơ; mở lại app đọc được đúng như cũ', () async {
    final (provider, backend, prefs) = await create();
    await provider.generate(profile);

    expect(backend.paths, ['/api/v1/generate-plan']);
    expect(provider.plan!.toJson(), loadFixture('generate_plan'));
    expect(jsonDecode(prefs.getString(PlanProvider.planKey)!), loadFixture('generate_plan'));
    expect(jsonDecode(prefs.getString(PlanProvider.profileKey)!), loadFixture('profile'));

    final reopened = PlanProvider(api: backend.api, prefs: prefs);
    expect(reopened.plan!.toJson(), loadFixture('generate_plan'));
    expect(reopened.profile!.toJson(), loadFixture('profile'));
  });

  test('đổi món, đổi bài, feedback gửi plan đang có và thay bằng plan server trả', () async {
    final (provider, backend, prefs) = await create(saved);

    await provider.swapMeal('m1_2');
    expect(provider.plan!.toJson(), loadFixture('meals_swap')['plan']);
    expect(jsonDecode(prefs.getString(PlanProvider.planKey)!), loadFixture('meals_swap')['plan']);

    await provider.swapExercise('e1_3');
    expect(provider.plan!.toJson(), loadFixture('exercises_swap')['plan']);

    final result = await provider.submitFeedback(const FeedbackAnswers(
        dayNumber: 1, intensity: Intensity.hard, bodyStates: {BodyState.sore}, eating: Eating.onPlan));
    expect(result!.safetyWarning, isNull);
    expect(provider.plan!.toJson(), loadFixture('feedback')['plan']);

    expect(backend.paths, ['/api/v1/meals/swap', '/api/v1/exercises/swap', '/api/v1/feedback']);
    final lastBody = jsonDecode(utf8.decode(backend.requests.last.bodyBytes)) as Map<String, dynamic>;
    expect(lastBody['plan'], loadFixture('exercises_swap')['plan']);
    expect(lastBody['profile'], loadFixture('profile'));
  });

  test('server báo lỗi → ném ApiException, plan cũ giữ nguyên, hết trạng thái bận', () async {
    final (provider, backend, _) = await create(saved);
    backend.failWith = 409;

    await expectLater(provider.swapMeal('m1_2'), throwsA(isA<PlanOutdatedException>()));
    expect(provider.plan!.toJson(), loadFixture('generate_plan'));
    expect(provider.busy, isFalse);
  });

  test('đang chờ server → bận; bấm lần hai bị bỏ qua, không gọi server lần nữa', () async {
    final (provider, backend, _) = await create(saved);
    backend.hold = Completer<void>();
    final states = <bool>[];
    provider.addListener(() => states.add(provider.busy));

    final first = provider.swapMeal('m1_2');
    expect(provider.busy, isTrue);
    await provider.swapMeal('m1_3');
    expect(await provider.submitFeedback(const FeedbackAnswers(
        dayNumber: 1, intensity: Intensity.easy, bodyStates: {}, eating: Eating.onPlan)), isNull);

    backend.hold!.complete();
    await first;
    expect(backend.paths, ['/api/v1/meals/swap']);
    expect(states, [true, false]);
  });

  group('bản lưu hỏng → bỏ đi, không crash', () {
    test('plan hỏng → xoá plan, giữ hồ sơ', () async {
      final (provider, _, prefs) = await create({...saved, PlanProvider.planKey: '{"plan_id": 1}'});
      expect(provider.hasPlan, isFalse);
      expect(provider.profile!.toJson(), loadFixture('profile'));
      expect(prefs.containsKey(PlanProvider.planKey), isFalse);
    });

    test('hồ sơ hỏng → xoá cả plan (không có hồ sơ thì không đổi món/feedback được)', () async {
      final (provider, _, prefs) = await create({...saved, PlanProvider.profileKey: 'không phải JSON'});
      expect(provider.hasPlan, isFalse);
      expect(provider.profile, isNull);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  test('clearPlan bỏ plan, giữ hồ sơ để điền sẵn form', () async {
    final (provider, _, prefs) = await create(saved);
    await provider.clearPlan();
    expect(provider.hasPlan, isFalse);
    expect(provider.profile, isNotNull);
    expect(prefs.getKeys(), {PlanProvider.profileKey});
  });

  group('ngày trong plan (D6-B1)', () {
    test('tạo plan → bắt đầu hôm nay, lưu lại; mở app hôm sau là ngày 2, quá 3 ngày là > 3', () async {
      final (provider, _, prefs) = await create();
      await provider.generate(profile);
      expect(provider.todayNumber, 1);
      expect(jsonDecode(prefs.getString(PlanProvider.scheduleKey)!),
          {'plan_id': provider.plan!.planId, 'start_date': '2026-09-26'});

      now = DateTime(2026, 9, 27, 7);
      expect(PlanProvider(api: FakeBackend().api, prefs: prefs, now: () => now).todayNumber, 2);
      now = DateTime(2026, 9, 29, 7);
      expect(provider.todayNumber, 4);
    });

    test('đổi món giữ ngày bắt đầu; feedback ngày 3 trả plan mới → plan mới bắt đầu từ ngày mai', () async {
      final (provider, backend, _) = await create();
      await provider.generate(profile);
      now = DateTime(2026, 9, 28, 21);
      await provider.swapMeal('m3_2');
      expect(provider.todayNumber, 3);

      final next = loadFixture('generate_plan')..['plan_id'] = '00000000-0000-4000-8000-0000000000ff';
      backend.responses['/api/v1/feedback'] = {'plan': next, 'safety_warning': null};
      await provider.submitFeedback(const FeedbackAnswers(
          dayNumber: 3, intensity: Intensity.moderate, bodyStates: {BodyState.normal}, eating: Eating.onPlan));
      expect(provider.plan!.planId, next['plan_id']);
      expect(provider.todayNumber, 0);
      now = DateTime(2026, 9, 29, 7);
      expect(provider.todayNumber, 1);
    });

    test('plan lưu từ giai đoạn 5 (chưa có lịch) → coi như bắt đầu hôm nay', () async {
      final (provider, _, _) = await create(saved);
      expect(provider.schedule!.planId, provider.plan!.planId);
      expect(provider.todayNumber, 1);
    });
  });

  group('hồ sơ đang sửa ở tab Cá nhân (bản nháp)', () {
    test('lưu nháp khác hồ sơ của plan → chờ áp dụng; đổi món vẫn gửi hồ sơ cũ (không bị 409)', () async {
      final (provider, backend, prefs) = await create(saved);
      final edited = Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'});
      await provider.saveDraft(edited);

      expect(provider.hasPendingProfile, isTrue);
      expect(provider.editableProfile!.goal, Goal.bulk);
      expect(prefs.containsKey(PlanProvider.draftKey), isTrue);

      await provider.swapMeal('m1_2');
      final body = jsonDecode(utf8.decode(backend.requests.last.bodyBytes)) as Map<String, dynamic>;
      expect(body['profile'], loadFixture('profile'));
    });

    test('lưu nháp giống hồ sơ của plan → không còn gì chờ; tạo plan mới → bỏ nháp', () async {
      final (provider, _, prefs) = await create(saved);
      await provider.saveDraft(Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'}));
      await provider.saveDraft(profile);
      expect(provider.hasPendingProfile, isFalse);
      expect(prefs.containsKey(PlanProvider.draftKey), isFalse);

      final edited = Profile.fromJson({...loadFixture('profile'), 'goal': 'maintain'});
      await provider.saveDraft(edited);
      await provider.generate(edited);
      expect(provider.hasPendingProfile, isFalse);
      expect(provider.profile!.goal, Goal.maintain);
      expect(prefs.containsKey(PlanProvider.draftKey), isFalse);
    });
  });

  test('hồ sơ đã lưu nay bị luật v2.6.0 chặn (17 tuổi) → bỏ plan, giữ hồ sơ để sửa ở Onboarding', () async {
    final (provider, _, prefs) = await create({
      ...saved,
      PlanProvider.profileKey: jsonEncode({...loadFixture('profile'), 'age': 17}),
    });
    expect(provider.hasPlan, isFalse);
    expect(provider.editableProfile!.age, 17);
    expect(prefs.containsKey(PlanProvider.planKey), isFalse);
  });
}
