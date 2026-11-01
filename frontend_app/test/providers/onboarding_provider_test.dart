import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/providers/onboarding_provider.dart';

void main() {
  test('hồ sơ form thành JSON API, giữ nguyên chỉ số và hạn chế', () {
    final form = OnboardingProvider()
      ..updateBasicInfo(newAge: 35, newGender: 'Nữ', newHeight: 165, newWeight: 64.5)
      ..updateActivity('Vận động nhiều')
      ..updateGoal('Tăng cơ')
      ..updateRestrictions(newAllergies: 'Trứng', newInjuries: 'Đau vai', conditions: 'Gout');
    final snapshot = form.toProfile();
    expect(snapshot.toJson(), {
      'age': 35,
      'gender': 'female',
      'height_cm': 165,
      'weight_kg': 64.5,
      'activity_level': 'active',
      'goal': 'bulk',
      'pregnant_or_breastfeeding': false,
      'restrictions': {'allergies': 'Trứng', 'injuries': 'Đau vai', 'health_conditions': 'Gout'},
    });
    form.updateGoal('Duy trì');
    expect(form.toProfile().toJson()['goal'], 'maintain');
    expect(snapshot.toJson()['goal'], 'bulk');
  });

  test('mọi lựa chọn vận động và mục tiêu dùng đúng enum backend', () {
    final form = OnboardingProvider()
      ..updateBasicInfo(newAge: 22, newGender: 'Nam', newHeight: 168, newWeight: 62)
      ..updateActivity('Vận động nhẹ')
      ..updateGoal('Duy trì');
    for (final entry in {'Ít vận động': 'sedentary', 'Vận động nhẹ': 'light', 'Vận động nhiều': 'active'}.entries) {
      form.updateActivity(entry.key);
      expect(form.toProfile().toJson()['activity_level'], entry.value);
    }
    for (final entry in {'Giảm mỡ': 'cut', 'Tăng cơ': 'bulk', 'Duy trì': 'maintain'}.entries) {
      form.updateGoal(entry.key);
      expect(form.toProfile().toJson()['goal'], entry.value);
    }
    expect(form.toProfile().toJson()['gender'], 'male');
  });

  test('mã lựa chọn không biết không bị thay bằng hồ sơ mặc định', () {
    final form = OnboardingProvider()..updateActivity('mã lạ');
    expect(form.toProfile, throwsFormatException);
    form.updateActivity('Vận động nhẹ');
    form.updateGoal('mã lạ');
    expect(form.toProfile, throwsFormatException);
    form.updateGoal('Duy trì');
    form.gender = 'mã lạ';
    expect(form.toProfile, throwsFormatException);
  });
}
