import 'api/json_read.dart';

// Feedback cuối ngày (BRD FR-5, PLAN giai đoạn 7). Backend không lưu trạng thái: gửi hai lần cho cùng một ngày sẽ
// điều chỉnh hai lần (BRD 6.4) — nên app nhớ ngày nào của plan đã gửi và khoá nút.

// Ngày thứ [day] có được gửi feedback không (quyết định Q2): hôm nay và hôm qua nếu chưa gửi; ngày 3 vẫn được khi
// plan đã hết (feedback ngày 3 tạo plan mới — FR-5.3). Ngày chưa tới, hoặc quá cũ đến mức điều chỉnh rơi vào một
// ngày đã qua, thì không.
bool canReviewDay(int day, {required int today, required Set<int> sent}) {
  if (day < 1 || day > 3 || day > today || sent.contains(day)) return false;
  return day >= today - 1 || day == 3;
}

// Những ngày đã gửi feedback của một plan. Chỉ lưu số ngày — không lưu câu trả lời (dữ liệu sức khoẻ, NFR-7).
class FeedbackLog {
  const FeedbackLog({required this.planId, this.days = const {}});

  final String planId;
  final Set<int> days;

  factory FeedbackLog.fromJson(Json json) => FeedbackLog(
    planId: readString(json, 'plan_id'),
    days: readList(json, 'days', (item) {
      if (item is int && item >= 1 && item <= 3) return item;
      throw const FormatException('"days" chỉ gồm số ngày 1–3');
    }).toSet(),
  );

  Json toJson() => {'plan_id': planId, 'days': days.toList()..sort()};

  FeedbackLog withDay(int day) => FeedbackLog(planId: planId, days: {...days, day});
}
