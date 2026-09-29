import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/profile_rules.dart';

import '../fixture_loader.dart';

// Giới hạn và luật an toàn phải giống backend (BRD 6.1, FR-1.3 v2.6.0) — lệch thì app khoá sai hoặc backend trả 400.
void main() {
  test('tuổi 18–100, số nguyên; chiều cao 100–250 cm; cân nặng 30–250 kg; nhận dấu phẩy thập phân', () {
    expect(ageError('17'), isNotNull);
    expect(ageError('18'), isNull);
    expect(ageError('100'), isNull);
    expect(ageError('101'), isNotNull);
    expect(ageError('22.5'), isNotNull);
    expect(ageError(''), isNotNull);
    expect(heightError('99'), isNotNull);
    expect(heightError('168'), isNull);
    expect(weightError('62,5'), isNull);
    expect(parseNumber('62,5'), 62.5);
    expect(weightError('251'), isNotNull);
  });

  test('khoá Giảm mỡ khi thiếu cân — so BMI chưa làm tròn như backend', () {
    expect(bodyMassIndex(160, 42), closeTo(16.4, 0.05));
    expect(cutBlockReason(heightCm: 160, weightKg: 42, pregnantOrBreastfeeding: false), underweightCutMessage);
    expect(cutBlockReason(heightCm: 170, weightKg: 53.35, pregnantOrBreastfeeding: false), underweightCutMessage);
    expect(cutBlockReason(heightCm: 170, weightKg: 53.5, pregnantOrBreastfeeding: false), isNull);
  });

  test('khoá Giảm mỡ khi mang thai / cho con bú', () {
    expect(cutBlockReason(heightCm: 160, weightKg: 70, pregnantOrBreastfeeding: true), pregnantCutMessage);
  });

  test('hồ sơ đã lưu: hồ sơ fixture hợp lệ; hồ sơ trước v2.6.0 dưới 18 tuổi hoặc thiếu cân + Giảm mỡ thì không', () {
    final valid = Profile.fromJson(loadFixture('profile'));
    expect(profileProblems(valid), isEmpty);

    Profile variant({int age = 22, num weight = 62, Gender gender = Gender.female, bool pregnant = false}) => Profile(
      age: age,
      gender: gender,
      heightCm: 168,
      weightKg: weight,
      activityLevel: ActivityLevel.light,
      goal: Goal.cut,
      pregnantOrBreastfeeding: pregnant,
    );
    expect(profileProblems(variant(age: 17)), isNotEmpty);
    expect(profileProblems(variant(weight: 45)), [underweightCutMessage]);
    expect(profileProblems(variant(pregnant: true)), [pregnantCutMessage]);
    expect(profileProblems(variant(gender: Gender.male, pregnant: true)), hasLength(2));
  });
}
