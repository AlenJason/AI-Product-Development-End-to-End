import 'api/json_read.dart';

// Ngày bắt đầu của plan đang mở (quyết định D6-B1). Plan (BRD 6.2) chỉ có ngày 1–3, không có ngày theo lịch —
// app tự lưu để mở đúng ngày hôm nay. Ngày tính theo giờ trên máy, không có giờ phút.
class PlanSchedule {
  const PlanSchedule({required this.planId, required this.startDate});

  final String planId;
  final DateTime startDate;

  factory PlanSchedule.startingOn(String planId, DateTime day) =>
      PlanSchedule(planId: planId, startDate: dateOnly(day));

  factory PlanSchedule.fromJson(Json json) {
    final start = DateTime.tryParse(readString(json, 'start_date'));
    if (start == null) throw const FormatException('"start_date" phải là ngày yyyy-mm-dd');
    return PlanSchedule(planId: readString(json, 'plan_id'), startDate: dateOnly(start));
  }

  Json toJson() => {
    'plan_id': planId,
    'start_date': '${startDate.year.toString().padLeft(4, '0')}-${_two(startDate.month)}-${_two(startDate.day)}',
  };

  // Ngày thứ mấy của plan vào [now]: < 1 là chưa tới ngày bắt đầu, > 3 là plan đã hết.
  int dayNumberOn(DateTime now) => dateOnly(now).difference(startDate).inDays + 1;

  // Ngày theo lịch của ngày thứ [dayNumber].
  DateTime dateOfDay(int dayNumber) => startDate.add(Duration(days: dayNumber - 1));

  // UTC để phép trừ ngày không lệch vì giờ mùa hè.
  static DateTime dateOnly(DateTime time) => DateTime.utc(time.year, time.month, time.day);

  static String _two(int value) => value.toString().padLeft(2, '0');
}

// "Thứ Bảy, 26/9" — không dùng package intl cho một chuỗi ngắn.
String vietnameseDate(DateTime date) {
  const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
  return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}';
}

