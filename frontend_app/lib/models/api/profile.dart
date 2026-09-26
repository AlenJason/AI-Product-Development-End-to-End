import 'codes.dart';
import 'json_read.dart';

// Hồ sơ gửi kèm mọi request tạo/sửa plan (BRD 6.1). Chỉ lưu trên máy — kể cả `restrictions` là dữ liệu sức khoẻ,
// backend không lưu (NFR-7, #12). App không bao giờ in hồ sơ ra log.
class Profile {
  const Profile({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    this.restrictions = const Restrictions(),
  });

  final int age;
  final Gender gender;
  final num heightCm;
  final num weightKg;
  final ActivityLevel activityLevel;
  final Goal goal;
  final Restrictions restrictions;

  factory Profile.fromJson(Json json) => Profile(
        age: readInt(json, 'age'),
        gender: readCode(json, 'gender', Gender.values, (v) => v.code),
        heightCm: readNum(json, 'height_cm'),
        weightKg: readNum(json, 'weight_kg'),
        activityLevel: readCode(json, 'activity_level', ActivityLevel.values, (v) => v.code),
        goal: readCode(json, 'goal', Goal.values, (v) => v.code),
        restrictions: json['restrictions'] == null
            ? const Restrictions()
            : Restrictions.fromJson(readMap(json['restrictions'], 'restrictions')),
      );

  Json toJson() => {
        'age': age,
        'gender': gender.code,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': activityLevel.code,
        'goal': goal.code,
        'restrictions': restrictions.toJson(),
      };
}

// Ba ô nhập tự do, tối đa 300 ký tự mỗi ô (BRD FR-1.4) — giới hạn này kiểm ở form (giai đoạn 6) và ở backend.
class Restrictions {
  const Restrictions({this.allergies = '', this.injuries = '', this.healthConditions = ''});

  final String allergies;
  final String injuries;
  final String healthConditions;

  factory Restrictions.fromJson(Json json) => Restrictions(
        allergies: readString(json, 'allergies'),
        injuries: readString(json, 'injuries'),
        healthConditions: readString(json, 'health_conditions'),
      );

  Json toJson() => {'allergies': allergies, 'injuries': injuries, 'health_conditions': healthConditions};
}
