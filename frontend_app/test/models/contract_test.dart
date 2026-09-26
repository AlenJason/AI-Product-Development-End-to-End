import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/json_read.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/api/profile.dart';

import '../fixture_loader.dart';

// Vòng tròn fromJson → toJson phải ra đúng JSON server đã gửi: đổi món và feedback gửi nguyên plan lên,
// server kiểm từng ID và con số (BRD 6.4, #24). Fixture lệch với backend → test backend
// contract-fixtures.e2e-spec.ts đỏ trước.
void main() {
  group('vòng tròn JSON với fixture của backend', () {
    for (final name in ['generate_plan', 'meals_swap', 'exercises_swap']) {
      test('$name giữ nguyên từng trường và từng con số', () {
        final json = loadFixture(name);
        final plan = name == 'generate_plan' ? json : json['plan'] as Json;
        expect(MealPlan.fromJson(plan).toJson(), equals(plan));
      });
    }

    for (final name in ['feedback', 'feedback_danger']) {
      test('$name giữ nguyên plan và safety_warning', () {
        final json = loadFixture(name);
        expect(FeedbackResult.fromJson(json).toJson(), equals(json));
      });
    }

    test('profile gửi đi đúng request của backend', () {
      final json = loadFixture('profile');
      expect(Profile.fromJson(json).toJson(), equals(json));
    });

    test('auth_login, history, health', () {
      final auth = loadFixture('auth_login');
      expect(AuthResult.fromJson(auth).toJson(), equals(auth));
      final history = loadFixture('history');
      expect({'plans': planSummariesFromJson(history).map((plan) => plan.toJson()).toList()}, equals(history));
      final health = loadFixture('health');
      expect(HealthStatus.fromJson(health).toJson(), equals(health));
    });
  });

  test('giữ đúng kiểu số: macro thập phân vẫn thập phân, calo nguyên vẫn nguyên', () {
    final meal = MealPlan.fromJson(loadFixture('generate_plan')).days.first.meals.first;
    expect(meal.calories, isA<int>());
    expect(meal.proteinG, isA<double>());
    expect(meal.toJson()['protein_g'], same(meal.proteinG));
  });

  group('JSON sai hợp đồng → FormatException nêu rõ trường', () {
    test('mã lạ', () {
      final json = loadFixture('generate_plan');
      final day = (json['days'] as List).first as Json;
      day['meals'] = [
        {...(day['meals'] as List).first as Json, 'meal_type': 'Bữa sáng'},
        ...(day['meals'] as List).skip(1),
      ];
      expect(() => MealPlan.fromJson(json), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('meal_type'))));
    });

    test('thiếu trường', () {
      final json = loadFixture('generate_plan')..remove('daily_target');
      expect(() => MealPlan.fromJson(json), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('daily_target'))));
    });

    test('sai kiểu', () {
      final json = loadFixture('generate_plan')..['plan_id'] = 123;
      expect(() => MealPlan.fromJson(json), throwsFormatException);
    });
  });

  test('FeedbackAnswers gửi đúng mã của BRD 6.4', () {
    const answers = FeedbackAnswers(
      dayNumber: 1,
      intensity: Intensity.hard,
      bodyStates: {BodyState.sore, BodyState.jointPain},
      eating: Eating.onPlan,
    );
    expect(answers.toJson(), {
      'day_number': 1,
      'intensity': 'hard',
      'body_states': ['sore', 'joint_pain'],
      'eating': 'on_plan',
    });
  });
}
