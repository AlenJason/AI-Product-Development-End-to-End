import 'package:flutter/material.dart';

import '../models/api/codes.dart';
import '../models/api/profile.dart';
import '../models/profile_rules.dart';
import '../models/restriction_options.dart';

class OnboardingProvider extends ChangeNotifier {
  void loadProfile(Profile profile, {bool notify = true}) {
    ageText = '${profile.age}';
    heightText = '${profile.heightCm}';
    weightText = '${profile.weightKg}';
    age = profile.age;
    heightCm = profile.heightCm;
    weightKg = profile.weightKg;
    gender = profile.gender == Gender.female ? 'Nữ' : 'Nam';
    activityLevel = switch (profile.activityLevel) {
      ActivityLevel.sedentary => 'Ít vận động',
      ActivityLevel.light => 'Vận động nhẹ',
      ActivityLevel.active => 'Vận động nhiều',
    };
    goal = switch (profile.goal) {
      Goal.cut => 'Giảm mỡ',
      Goal.bulk => 'Tăng cơ',
      Goal.maintain => 'Duy trì',
    };
    pregnantOrBreastfeeding = profile.pregnantOrBreastfeeding;
    final values = {
      RestrictionKind.allergies: profile.restrictions.allergies,
      RestrictionKind.injuries: profile.restrictions.injuries,
      RestrictionKind.healthConditions: profile.restrictions.healthConditions,
    };
    for (final entry in values.entries) {
      final parsed = RestrictionSelection.parse(entry.value, entry.key);
      _selections[entry.key] = parsed;
      _otherEnabled[entry.key] = parsed.other.isNotEmpty;
    }
    if (notify) notifyListeners();
  }

  // Text gốc là nguồn của form. Số bên dưới giữ tương thích với tab profile cũ,
  // không được dùng làm fallback khi text trống/sai.
  String ageText = '';
  String heightText = '';
  String weightText = '';
  int age = 0;
  num heightCm = 0;
  num weightKg = 0;
  String gender = '';
  String activityLevel = '';
  String goal = '';
  bool pregnantOrBreastfeeding = false;

  final _selections = {
    for (final kind in RestrictionKind.values)
      kind: const RestrictionSelection(),
  };
  final _otherEnabled = {
    for (final kind in RestrictionKind.values) kind: false,
  };

  RestrictionSelection selection(RestrictionKind kind) => _selections[kind]!;
  bool otherEnabled(RestrictionKind kind) => _otherEnabled[kind]!;
  RestrictionSelection _submittedSelection(RestrictionKind kind) =>
      selection(kind)
          .copyWith(other: otherEnabled(kind) ? selection(kind).other : '');
  String restrictionText(RestrictionKind kind) =>
      _submittedSelection(kind).compose(kind);
  String? restrictionError(RestrictionKind kind) =>
      _submittedSelection(kind).lengthError(kind);
  String get allergies => restrictionText(RestrictionKind.allergies);
  String get injuries => restrictionText(RestrictionKind.injuries);
  String get healthConditions =>
      restrictionText(RestrictionKind.healthConditions);

  List<String> get bodyProblems => [
    ?ageError(ageText),
    ?heightError(heightText),
    ?weightError(weightText),
    if (gender != 'Nam' && gender != 'Nữ') 'Chọn giới tính',
    if (pregnantOrBreastfeeding && gender != 'Nữ')
      'Chỉ nữ mới khai báo mang thai / cho con bú',
  ];
  bool get bodyValid => bodyProblems.isEmpty;
  String? get cutReason => bodyValid
      ? cutBlockReason(
          heightCm: parseNumber(heightText)!,
          weightKg: parseNumber(weightText)!,
          pregnantOrBreastfeeding: pregnantOrBreastfeeding,
        )
      : null;
  String? get activityError =>
      ['Ít vận động', 'Vận động nhẹ', 'Vận động nhiều'].contains(activityLevel)
      ? null
      : 'Chọn mức độ vận động';
  String? get goalError {
    if (!['Giảm mỡ', 'Tăng cơ', 'Duy trì'].contains(goal)) {
      return 'Chọn mục tiêu';
    }
    return goal == 'Giảm mỡ' ? cutReason : null;
  }

  bool get goalsValid =>
      bodyValid && activityError == null && goalError == null;
  bool get canSubmit =>
      goalsValid &&
      RestrictionKind.values.every((kind) => restrictionError(kind) == null);

  Profile toProfile() {
    if (!canSubmit) throw const FormatException('Hồ sơ chưa hợp lệ');
    final profile = Profile(
      age: int.parse(ageText.trim()),
      gender: gender == 'Nam' ? Gender.male : Gender.female,
      heightCm: parseNumber(heightText)!,
      weightKg: parseNumber(weightText)!,
      activityLevel: switch (activityLevel) {
        'Ít vận động' => ActivityLevel.sedentary,
        'Vận động nhẹ' => ActivityLevel.light,
        'Vận động nhiều' => ActivityLevel.active,
        _ => throw const FormatException('Mức vận động chưa hợp lệ'),
      },
      goal: switch (goal) {
        'Giảm mỡ' => Goal.cut,
        'Tăng cơ' => Goal.bulk,
        'Duy trì' => Goal.maintain,
        _ => throw const FormatException('Mục tiêu chưa hợp lệ'),
      },
      pregnantOrBreastfeeding: pregnantOrBreastfeeding,
      restrictions: Restrictions(
        allergies: allergies,
        injuries: injuries,
        healthConditions: healthConditions,
      ),
    );
    final problems = profileProblems(profile);
    if (problems.isNotEmpty) throw FormatException(problems.join('\n'));
    return profile;
  }

  void updateBodyText({
    required String newAge,
    required String newHeight,
    required String newWeight,
  }) {
    ageText = newAge;
    heightText = newHeight;
    weightText = newWeight;
    final parsedAge = int.tryParse(newAge.trim());
    final parsedHeight = parseNumber(newHeight);
    final parsedWeight = parseNumber(newWeight);
    if (parsedAge != null) age = parsedAge;
    if (parsedHeight != null && parsedHeight.isFinite) heightCm = parsedHeight;
    if (parsedWeight != null && parsedWeight.isFinite) weightKg = parsedWeight;
    notifyListeners();
  }

  void updateBasicInfo({
    required int newAge,
    required String newGender,
    required num newHeight,
    required num newWeight,
  }) {
    gender = newGender;
    updateBodyText(
      newAge: '$newAge',
      newHeight: '$newHeight',
      newWeight: '$newWeight',
    );
  }

  void updateGender(String value) {
    gender = value;
    notifyListeners();
  }

  void updatePregnancy(bool value) {
    pregnantOrBreastfeeding = value;
    notifyListeners();
  }

  void updateActivity(String value) {
    activityLevel = value;
    notifyListeners();
  }

  void updateGoal(String value) {
    goal = value;
    notifyListeners();
  }

  void enableRestriction(RestrictionKind kind, bool enabled) {
    _selections[kind] = selection(kind).copyWith(enabled: enabled);
    notifyListeners();
  }

  void chooseRestriction(RestrictionKind kind, String label, bool selected) {
    final chosen = {...selection(kind).chosen};
    if (selected) {
      chosen.add(label);
    } else {
      chosen.remove(label);
    }
    _selections[kind] = selection(kind).copyWith(chosen: chosen);
    notifyListeners();
  }

  void enableOther(RestrictionKind kind, bool enabled) {
    _otherEnabled[kind] = enabled;
    notifyListeners();
  }

  void updateOther(RestrictionKind kind, String value) {
    _selections[kind] = selection(kind).copyWith(other: value);
    notifyListeners();
  }

  void updateRestrictions({
    required String newAllergies,
    required String newInjuries,
    required String conditions,
  }) {
    final values = {
      RestrictionKind.allergies: newAllergies,
      RestrictionKind.injuries: newInjuries,
      RestrictionKind.healthConditions: conditions,
    };
    for (final entry in values.entries) {
      final parsed = RestrictionSelection.parse(entry.value, entry.key);
      _selections[entry.key] = parsed;
      _otherEnabled[entry.key] = parsed.other.isNotEmpty;
    }
    notifyListeners();
  }
}
