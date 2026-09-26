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

  Future<(PlanProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    return (PlanProvider(api: backend.api, prefs: prefs), backend, prefs);
  }

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

    await provider.swapExercise('e1_2');
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
}
