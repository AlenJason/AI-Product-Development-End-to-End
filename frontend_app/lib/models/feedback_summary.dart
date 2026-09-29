import 'dart:math' as math;

import 'api/account.dart';
import 'api/codes.dart';
import 'api/meal_plan.dart';
import 'plan_schedule.dart';

// Điều feedback vừa làm thay đổi (quyết định Q4 giai đoạn 7), để báo cho người dùng ngay sau khi gửi. Backend không
// trả bản tóm tắt, còn cảnh báo "chưa cân đối món" trong `warnings` mất ở lần đổi món sau — nên so plan trước và
// sau. Chỉ nói điều thật sự đã đổi; không đổi gì thì nói đúng như vậy.
List<String> describeFeedbackChanges({
  required MealPlan before,
  required MealPlan after,
  required FeedbackAnswers answers,
  DateTime? newPlanStart,
}) {
  // Ngày 3 → plan mới (FR-5.3), không có gì để so với plan cũ.
  if (after.planId != before.planId) {
    final start = newPlanStart == null ? '' : ', bắt đầu từ ${vietnameseDate(newPlanStart)}';
    return ['Đã tạo kế hoạch 3 ngày mới$start, có tính tới đánh giá của bạn.'];
  }
  final next = answers.dayNumber + 1;
  final danger = answers.bodyStates.contains(BodyState.dangerSign);
  final lines = [
    ..._workoutChanges(before.days[next - 1].workout, after.days[next - 1].workout, next, danger),
    ..._mealChanges(before.days[next - 1].meals, after.days[next - 1].meals, next, answers.eating, danger),
  ];
  return lines.isEmpty ? ['Ngày $next giữ nguyên như kế hoạch.'] : lines;
}

List<String> _workoutChanges(Workout old, Workout now, int day, bool danger) {
  // Dấu hiệu nguy hiểm: cả buổi thành ngày nghỉ — tên buổi đã nói đủ, không liệt kê từng động tác bị bỏ.
  if (danger) return ['Ngày $day: ${now.title}.'];
  final lines = <String>[];
  final fewer = <String>[];
  final more = <String>[];
  final shared = math.min(old.exercises.length, now.exercises.length);
  for (var i = 0; i < shared; i++) {
    final (a, b) = (old.exercises[i], now.exercises[i]);
    if (a.name != b.name) {
      lines.add('Ngày $day: thay "${a.name}" bằng "${b.name}".');
    } else if (b.sets != a.sets) {
      (b.sets < a.sets ? fewer : more).add('${b.name} ${a.sets} → ${b.sets}');
    }
  }
  if (fewer.isNotEmpty) lines.add('Ngày $day: giảm số hiệp — ${fewer.join(', ')}.');
  if (more.isNotEmpty) lines.add('Ngày $day: tăng số hiệp — ${more.join(', ')}.');
  for (final added in now.exercises.skip(shared)) {
    lines.add('Ngày $day: thêm "${added.name}".');
  }
  for (final removed in old.exercises.skip(shared)) {
    lines.add('Ngày $day: bỏ "${removed.name}".');
  }
  if (now.durationMinutes != old.durationMinutes) {
    lines.add('Ngày $day: buổi tập ${old.durationMinutes} → ${now.durationMinutes} phút.');
  }
  return lines;
}

List<String> _mealChanges(List<Meal> old, List<Meal> now, int day, Eating eating, bool danger) {
  final changed =
      old.length != now.length ||
      [for (var i = 0; i < old.length; i++) old[i].name != now[i].name || old[i].calories != now[i].calories]
          .any((c) => c);
  if (changed) return ['Thực đơn ngày $day đã được cân đối lại: ${_total(old)} → ${_total(now)} kcal.'];
  // Có dấu hiệu nguy hiểm thì server không đụng tới món ăn (#14) — không báo "chưa cân đối được".
  if (eating != Eating.onPlan && !danger) {
    return ['Thực đơn ngày $day giữ nguyên — chưa cân đối lại được theo phần ăn uống bạn báo.'];
  }
  return [];
}

int _total(List<Meal> meals) => meals.fold<num>(0, (sum, meal) => sum + meal.calories).round();
