import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/feedback_rules.dart';

void main() {
  // Quyết định Q2 giai đoạn 7: hôm nay và hôm qua nếu chưa gửi; ngày 3 vẫn được khi plan đã hết.
  group('canReviewDay', () {
    Set<int> reviewable(int today, [Set<int> sent = const {}]) => {
      for (var day = 1; day <= 3; day++)
        if (canReviewDay(day, today: today, sent: sent)) day,
    };

    test('plan chưa bắt đầu → không ngày nào', () => expect(reviewable(0), isEmpty));
    test('ngày 1 → chỉ ngày 1', () => expect(reviewable(1), {1}));
    test('ngày 2 → hôm qua (1) và hôm nay (2)', () => expect(reviewable(2), {1, 2}));
    test('ngày 3 → ngày 2 và 3; ngày 1 đã quá cũ (điều chỉnh ngày 2 đã qua)', () => expect(reviewable(3), {2, 3}));
    test('plan đã hết → vẫn gửi được ngày 3 để tạo plan mới', () {
      expect(reviewable(4), {3});
      expect(reviewable(9), {3});
    });
    test('đã gửi → khoá ngày đó', () {
      expect(reviewable(2, {1}), {2});
      expect(reviewable(9, {3}), isEmpty);
    });
  });

  group('FeedbackLog', () {
    test('lưu plan_id và số ngày, không lưu câu trả lời', () {
      final log = const FeedbackLog(planId: 'p1').withDay(2).withDay(1).withDay(2);
      expect(log.toJson(), {
        'plan_id': 'p1',
        'days': [1, 2],
      });
      expect(FeedbackLog.fromJson(log.toJson()).days, {1, 2});
    });

    test('ngày ngoài 1–3 hoặc sai kiểu → FormatException', () {
      for (final days in [
        [4],
        [0],
        ['1'],
      ]) {
        expect(() => FeedbackLog.fromJson({'plan_id': 'p1', 'days': days}), throwsFormatException);
      }
    });
  });
}
