import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/plan_schedule.dart';

void main() {
  final schedule = PlanSchedule.startingOn('p1', DateTime(2026, 9, 26, 23, 30));

  test('bỏ giờ phút: tạo plan lúc 23:30 thì ngày mai là ngày 2', () {
    expect(schedule.dayNumberOn(DateTime(2026, 9, 26, 23, 59)), 1);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 27, 0, 1)), 2);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 28, 12)), 3);
  });

  test('chưa tới ngày bắt đầu < 1, quá 3 ngày > 3', () {
    expect(schedule.dayNumberOn(DateTime(2026, 9, 25)), 0);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 29)), 4);
  });

  test('qua tháng, lưu và đọc lại đúng ngày', () {
    final json = PlanSchedule.startingOn('p2', DateTime(2026, 9, 30)).toJson();
    expect(json, {'plan_id': 'p2', 'start_date': '2026-09-30'});
    final restored = PlanSchedule.fromJson(json);
    expect(restored.dateOfDay(3), DateTime.utc(2026, 10, 2));
    expect(vietnameseDate(restored.dateOfDay(1)), 'Thứ Tư, 30/9');
    expect(() => PlanSchedule.fromJson({'plan_id': 'x', 'start_date': 'hôm qua'}), throwsFormatException);
  });
}
