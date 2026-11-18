import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/profile_rules.dart';
import 'package:my_ai_app/models/restriction_options.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';

OnboardingProvider validOnboarding() => OnboardingProvider()
  ..updateBasicInfo(newAge: 22, newGender: 'Nữ', newHeight: 168, newWeight: 62)
  ..updateActivity('Vận động nhẹ')
  ..updateGoal('Duy trì');

void main() {
  test('form mới trống, không hồ sơ mặc định và không hạn chế điền sẵn', () {
    final form = OnboardingProvider();
    expect([
      form.ageText,
      form.heightText,
      form.weightText,
      form.gender,
      form.goal,
      form.activityLevel,
    ], everyElement(''));
    expect(form.bodyValid, isFalse);
    expect(form.canSubmit, isFalse);
    expect(form.toProfile, throwsFormatException);
    expect([form.allergies, form.injuries, form.healthConditions], everyElement(''));
    expect(RestrictionKind.values.every((kind) => !form.selection(kind).enabled), isTrue);
  });

  for (final input in [
    ('17', '168', '62'),
    ('101', '168', '62'),
    ('22.5', '168', '62'),
    ('', '168', '62'),
    ('22', '99', '62'),
    ('22', '251', '62'),
    ('22', '', '62'),
    ('22', 'NaN', '62'),
    ('22', '168', '29'),
    ('22', '168', '251'),
    ('22', '168', ''),
    ('22', '168', 'NaN'),
    ('22', 'Infinity', '62'),
    ('22', '168', '-Infinity'),
  ]) {
    test('chặn body sai ${input.$1}/${input.$2}/${input.$3}, không thay số mặc định', () {
      final form = validOnboarding()..updateBodyText(newAge: input.$1, newHeight: input.$2, newWeight: input.$3);
      expect(form.bodyValid, isFalse);
      expect(form.canSubmit, isFalse);
      expect(form.toProfile, throwsFormatException);
      expect((form.ageText, form.heightText, form.weightText), input);
    });
  }

  for (final input in [('18', '100', '30'), ('100', '250', '250'), (' 22 ', '168,5', '62,5')]) {
    test('giá trị biên/decimal hợp lệ ${input.$1}/${input.$2}/${input.$3}', () {
      final form = validOnboarding()..updateBodyText(newAge: input.$1, newHeight: input.$2, newWeight: input.$3);
      expect(form.canSubmit, isTrue);
      expect(profileProblems(form.toProfile()), isEmpty);
      if (input.$3 == '62,5') expect(form.toProfile().weightKg, 62.5);
    });
  }

  test('mục tiêu/activity/gender bắt buộc, mã lạ không có fallback', () {
    final form = validOnboarding()..updateGoal('');
    expect(form.canSubmit, isFalse);
    form.updateGoal('Duy trì');
    form.updateActivity('');
    expect(form.canSubmit, isFalse);
    form.updateActivity('mã lạ');
    expect(form.toProfile, throwsFormatException);
    form.updateActivity('Vận động nhẹ');
    form.updateGender('');
    expect(form.toProfile, throwsFormatException);
  });

  test('BMI chưa làm tròn: cut bị chặn; giữ nguyên goal để người dùng chọn lại', () {
    final form = validOnboarding()
      ..updateBasicInfo(newAge: 22, newGender: 'Nữ', newHeight: 170, newWeight: 53.35)
      ..updateGoal('Giảm mỡ');
    expect(form.cutReason, underweightCutMessage);
    expect(form.goal, 'Giảm mỡ');
    expect(form.toProfile, throwsFormatException);
    form.updateGoal('Duy trì');
    expect(form.canSubmit, isTrue);
    form.updateBasicInfo(newAge: 22, newGender: 'Nữ', newHeight: 170, newWeight: 53.5);
    form.updateGoal('Giảm mỡ');
    expect(form.canSubmit, isTrue);
  });

  test('pregnancy flag chính xác; male+pregnancy và pregnancy+cut đều chặn, không xóa ngầm', () {
    final form = validOnboarding()..updatePregnancy(true);
    expect(form.toProfile().toJson()['pregnant_or_breastfeeding'], isTrue);
    form.updateGoal('Giảm mỡ');
    expect(form.goalError, pregnantCutMessage);
    expect(form.toProfile, throwsFormatException);
    form.updateGoal('Duy trì');
    form.updateGender('Nam');
    expect(form.pregnantOrBreastfeeding, isTrue);
    expect(form.bodyValid, isFalse);
    expect(form.toProfile, throwsFormatException);
    form.updatePregnancy(false);
    expect(form.canSubmit, isTrue);
  });

  test('300 ký tự tính cả chip/dấu phân cách; không truncate; toggle/Khác giữ dữ liệu', () {
    final form = validOnboarding();
    const kind = RestrictionKind.allergies;
    form.enableRestriction(kind, true);
    form.chooseRestriction(kind, 'Trứng', true);
    form.enableOther(kind, true);
    form.updateOther(kind, 'a' * 293);
    expect(form.allergies.length, 300);
    expect(form.canSubmit, isTrue);
    form.updateOther(kind, 'a' * 294);
    expect(form.allergies.length, 301);
    expect(form.selection(kind).other.length, 294);
    expect(form.restrictionError(kind), isNotNull);
    expect(form.toProfile, throwsFormatException);
    form.enableRestriction(kind, false);
    expect(form.toProfile().restrictions.allergies, '');
    form.enableRestriction(kind, true);
    expect(form.allergies.length, 301);
    form.enableOther(kind, false);
    expect(form.allergies, 'Trứng');
    expect(form.canSubmit, isTrue);
    form.enableOther(kind, true);
    form.updateOther(kind, '   ');
    expect(form.allergies, 'Trứng');
    form.updateOther(kind, '  thịt vịt  ');
    expect(form.toProfile().restrictions.allergies, 'Trứng, thịt vịt');
  });
}
