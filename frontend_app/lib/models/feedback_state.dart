import 'api/account.dart';
import 'api/json_read.dart';
import 'api/meal_plan.dart';
import 'api/profile.dart';
import 'plan_schedule.dart';

class PlanCycle {
  const PlanCycle(this.profile, this.plan, this.schedule);
  final Profile profile;
  final MealPlan plan;
  final PlanSchedule schedule;
  factory PlanCycle.fromJson(Json j) {
    final p = MealPlan.fromJson(readMap(j['plan'], 'plan')),
        s = PlanSchedule.fromJson(readMap(j['schedule'], 'schedule'));
    if (p.planId != s.planId) throw const FormatException('Lịch không khớp');
    return PlanCycle(Profile.fromJson(readMap(j['profile'], 'profile')), p, s);
  }
  Json toJson() => {
    'profile': profile.toJson(),
    'plan': plan.toJson(),
    'schedule': schedule.toJson(),
  };
}

class PendingFeedback {
  const PendingFeedback(this.cycle, this.answers);
  final PlanCycle cycle;
  final FeedbackAnswers answers;
  factory PendingFeedback.fromJson(Json j) => PendingFeedback(
    PlanCycle.fromJson(readMap(j['cycle'], 'cycle')),
    FeedbackAnswers.fromJson(readMap(j['answers'], 'answers')),
  );
  Json toJson() => {'cycle': cycle.toJson(), 'answers': answers.toJson()};
}

class LocalFeedbackReceipt {
  const LocalFeedbackReceipt({
    required this.planId,
    required this.answers,
    required this.savedAt,
    required this.changed,
    this.safetyWarning,
    this.nextStart,
  });
  final String planId;
  final FeedbackAnswers answers;
  final DateTime savedAt;
  final bool changed;
  final String? safetyWarning;
  final DateTime? nextStart;
  String get key => '$planId:${answers.dayNumber}';
  String get summary => nextStart != null
      ? 'Đã lưu phản hồi ngày 3. Chu kỳ mới bắt đầu ${vietnameseDate(nextStart!)}.'
      : changed
      ? 'Đã lưu phản hồi. Ngày ${answers.dayNumber + 1} đã được điều chỉnh.'
      : 'Đã lưu phản hồi. Kế hoạch không cần thay đổi.';
  Json toJson() => {
    'plan_id': planId,
    'answers': answers.toJson(),
    'saved_at': savedAt.toIso8601String(),
    'changed': changed,
    'safety_warning': safetyWarning,
    'next_start': nextStart?.toIso8601String(),
  };
  factory LocalFeedbackReceipt.fromJson(Json j) => LocalFeedbackReceipt(
    planId: readString(j, 'plan_id'),
    answers: FeedbackAnswers.fromJson(readMap(j['answers'], 'answers')),
    savedAt: DateTime.parse(readString(j, 'saved_at')),
    changed: readBool(j, 'changed'),
    safetyWarning: j['safety_warning'] == null
        ? null
        : readString(j, 'safety_warning'),
    nextStart: j['next_start'] == null
        ? null
        : DateTime.parse(readString(j, 'next_start')),
  );
}
