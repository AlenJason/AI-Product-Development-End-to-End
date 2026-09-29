import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/feedback_summary.dart';

import '../fixture_loader.dart';

// Quyết định Q4 giai đoạn 7: báo đúng điều đã đổi, so plan trước (generate_plan) và sau (fixture feedback của backend).
void main() {
  final before = MealPlan.fromJson(loadFixture('generate_plan'));

  FeedbackAnswers answers(
    Set<BodyState> states, {
    Intensity intensity = Intensity.hard,
    Eating eating = Eating.onPlan,
  }) => FeedbackAnswers(dayNumber: 1, intensity: intensity, bodyStates: states, eating: eating);

  test('rất mệt + căng mỏi (feedback.json): liệt kê hiệp giảm, giãn cơ thêm, thời lượng — không nói gì về món', () {
    final after = FeedbackResult.fromJson(loadFixture('feedback')).plan;
    expect(describeFeedbackChanges(before: before, after: after, answers: answers({BodyState.sore})), [
      'Ngày 2: giảm số hiệp — Đi bộ tại chỗ nâng cao gối (khởi động) 2 → 1, Nhón gót (Calf raise) 3 → 2, '
          'Cầu mông (Glute bridge) 3 → 2, Dead bug 3 → 2.',
      'Ngày 2: thêm "Giãn cơ nhẹ các nhóm cơ đã tập".',
      'Ngày 2: buổi tập 20 → 15 phút.',
    ]);
  });

  test('dấu hiệu nguy hiểm (feedback_danger.json): một dòng ngày nghỉ, không báo món dù đã chọn ăn nhiều', () {
    final after = FeedbackResult.fromJson(loadFixture('feedback_danger')).plan;
    final lines = describeFeedbackChanges(
      before: before,
      after: after,
      answers: answers({BodyState.dangerSign}, intensity: Intensity.easy, eating: Eating.over),
    );
    expect(lines, ['Ngày 2: Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ.']);
  });

  test('ăn nhiều mà món không đổi (chưa có Gemini) → nói rõ thực đơn giữ nguyên', () {
    final lines = describeFeedbackChanges(
      before: before,
      after: before,
      answers: answers({BodyState.normal}, intensity: Intensity.moderate, eating: Eating.over),
    );
    expect(lines, ['Thực đơn ngày 2 giữ nguyên — chưa cân đối lại được theo phần ăn uống bạn báo.']);
  });

  test('món đổi → tổng calo trước và sau; không đổi gì → nói ngày đó giữ nguyên', () {
    final json = loadFixture('generate_plan');
    final meal = (((json['days'] as List)[1] as Map)['meals'] as List)[2] as Map<String, dynamic>;
    meal['name'] = 'Canh chua cá lóc, cơm trắng';
    meal['calories'] = 467;
    final rebalanced = MealPlan.fromJson(json);
    expect(
      describeFeedbackChanges(
        before: before,
        after: rebalanced,
        answers: answers({BodyState.normal}, eating: Eating.over),
      ),
      ['Thực đơn ngày 2 đã được cân đối lại: 1624 → 1524 kcal.'],
    );
    expect(
      describeFeedbackChanges(
        before: before,
        after: before,
        answers: answers({BodyState.normal}, intensity: Intensity.moderate),
      ),
      ['Ngày 2 giữ nguyên như kế hoạch.'],
    );
  });

  test('feedback ngày 3 trả plan mới → báo plan mới và ngày bắt đầu', () {
    final json = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    final lines = describeFeedbackChanges(
      before: before,
      after: MealPlan.fromJson(json),
      answers: const FeedbackAnswers(
        dayNumber: 3,
        intensity: Intensity.easy,
        bodyStates: {BodyState.normal},
        eating: Eating.onPlan,
      ),
      newPlanStart: DateTime.utc(2026, 9, 30),
    );
    expect(lines, ['Đã tạo kế hoạch 3 ngày mới, bắt đầu từ Thứ Tư, 30/9, có tính tới đánh giá của bạn.']);
  });

  test('thay động tác (đau khớp) và bỏ động tác → nêu tên cũ và mới', () {
    final json = loadFixture('generate_plan');
    final exercises = ((((json['days'] as List)[1] as Map)['workout'] as Map)['exercises'] as List);
    (exercises[1] as Map)['name'] = 'Nằm ngửa nâng thẳng chân (Straight-leg raise)';
    exercises.removeLast();
    final after = MealPlan.fromJson(json);
    expect(describeFeedbackChanges(before: before, after: after, answers: answers({BodyState.jointPain})), [
      'Ngày 2: thay "Nhón gót (Calf raise)" bằng "Nằm ngửa nâng thẳng chân (Straight-leg raise)".',
      'Ngày 2: bỏ "Dead bug".',
    ]);
  });
}
