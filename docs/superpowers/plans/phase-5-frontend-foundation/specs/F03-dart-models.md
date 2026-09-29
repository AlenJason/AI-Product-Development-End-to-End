# F03 — Model Dart theo hợp đồng BRD 6 + test vòng tròn (PLAN 5.3)

## Feature

Model viết tay (quyết định Q1) trong `lib/models/api/`, đọc và ghi đúng JSON của BRD mục 6.

**Vì sao phải "vòng tròn" chính xác (phát hiện F6):** đổi món, đổi bài, feedback gửi lại **nguyên** plan; server kiểm ID theo vị trí, `daily_target` phải bằng mục tiêu tính lại, và cả hợp đồng (#24). Nên `MealPlan.fromJson(json).toJson()` phải bằng **đúng** `json`: không rơi trường, không đổi `22.5` thành `22` hay `640` thành `640.0`. Số đọc qua `num` — giữ nguyên `int`/`double` như server gửi.

**Đọc chặt (`json_read.dart`):** thiếu trường, sai kiểu, mã lạ (`meal_type: "Bữa sáng"`) → `FormatException` nêu tên trường. Không đoán, không bỏ qua (cùng tinh thần #2). `ApiClient` (F04) đổi lỗi này thành `ServerException`; provider (F05) đổi thành "bỏ bản lưu hỏng".

**Tên lớp** khác view-model cũ trong `lib/models/meal_plan.dart` (`DayPlan`, `MealItem`, `GroceryCategory`… — phát hiện F7): `PlanDay`, `Meal`, `GroceryGroup`, `GroceryEntry`. Màn hình vẫn dùng view-model cũ tới giai đoạn 6.

| File | Lớp |
|---|---|
| `json_read.dart` | `Json`, `readMap`, `readList`, `readString`, `readNum`, `readInt` (nhận cả `3.0`), `readCode` |
| `codes.dart` | enum mã cố định: `Gender`, `ActivityLevel`, `Goal`, `PlanSource`, `MealType`, `IngredientUnit`, `IngredientCategory`, `MuscleGroup`, `ExerciseTag`, `Intensity`, `BodyState`, `Eating` — mỗi giá trị có `code` đúng như JSON |
| `meal_plan.dart` | `MealPlan`, `DailyTarget`, `PlanDay`, `Meal`, `Ingredient`, `Workout`, `Exercise`, `GroceryGroup`, `GroceryEntry` |
| `profile.dart` | `Profile`, `Restrictions` (mặc định ba chuỗi rỗng; thiếu `restrictions` → mặc định) |
| `account.dart` | `AuthUser`, `AuthResult`, `PlanSummary` (`created_at` → `DateTime` UTC), `planSummariesFromJson`, `FeedbackResult` (`safety_warning: null \| {message}`), `HealthStatus`, `FeedbackAnswers` (chỉ `toJson`) |

## Scope

UI-only (model + test):

- `frontend_app/lib/models/api/json_read.dart`, `codes.dart`, `meal_plan.dart`, `profile.dart`, `account.dart` (mới)
- `frontend_app/test/fixture_loader.dart`, `test/models/contract_test.dart` (mới)

## Implementation

### API Routes

Không có.

### UI Components

Không có — màn hình chuyển sang model mới ở giai đoạn 6.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#16** app không tự tạo ID; `toJson()` gửi lại đúng ID server gán.
- **#24** plan gửi lên phải đúng như server đã trả — test vòng tròn bằng fixture thật khoá điều này.
- **#13** app không tự tính BMR/calo; chỉ đọc `daily_target`.
- Ràng buộc mới #26 (model giữ vòng tròn, fixture cập nhật cùng hợp đồng) ghi vào wiki ở F07.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test test/models` → `All tests passed!` (12 test)
- [ ] Mọi fixture plan (`generate_plan`, `meals_swap`, `exercises_swap`, `feedback`, `feedback_danger`) đi vòng tròn `fromJson` → `toJson` bằng đúng JSON gốc
- [ ] Mã lạ, thiếu trường, sai kiểu → `FormatException` có tên trường

## Test Checklist

1. **@happy**: vòng tròn cho 5 fixture plan, `profile`, `auth_login`, `history`, `health`
2. **@numbers**: `calories` vẫn `int`, `protein_g` vẫn `double` sau vòng tròn
3. **@invalid**: `meal_type: "Bữa sáng"` → `FormatException` chứa `meal_type`; thiếu `daily_target`; `plan_id: 123`
4. **@codes**: `FeedbackAnswers` ghi `joint_pain`, `on_plan` (mã có dấu gạch dưới)
5. **@auth**, **@timeout**, **@partial-fail**, **@token**, **@db**: không áp dụng

## Tasks

### Task 1 — Đọc JSON chặt

`frontend_app/lib/models/api/json_read.dart`:

```dart
// Đọc JSON từ backend một cách chặt chẽ: thiếu trường hoặc sai kiểu → FormatException nêu rõ trường nào,
// thay vì lỗi kiểu `Null is not a subtype of String` khó hiểu. Nơi gọi (ApiClient, provider) bắt FormatException.

typedef Json = Map<String, dynamic>;

Json readMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('"$field" phải là object JSON');
}

List<T> readList<T>(Json json, String field, T Function(Object? item) parse) {
  final value = json[field];
  if (value is! List) throw FormatException('"$field" phải là mảng');
  return List.unmodifiable(value.map(parse));
}

String readString(Json json, String field) {
  final value = json[field];
  if (value is String) return value;
  throw FormatException('"$field" phải là chuỗi');
}

// Giữ nguyên int hay double như server gửi, để gửi lại plan đúng từng con số (đổi món, feedback — BRD 6.4).
num readNum(Json json, String field) {
  final value = json[field];
  if (value is num) return value;
  throw FormatException('"$field" phải là số');
}

int readInt(Json json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('"$field" phải là số nguyên');
}

// Mã cố định (meal_type, unit, muscle_group…): mã lạ → FormatException, không đoán.
T readCode<T extends Enum>(Json json, String field, List<T> values, String Function(T value) code) {
  final value = readString(json, field);
  for (final candidate in values) {
    if (code(candidate) == value) return candidate;
  }
  throw FormatException('"$field" có mã không hợp lệ: $value');
}
```

### Task 2 — Mã cố định

`frontend_app/lib/models/api/codes.dart`:

```dart
// Mã cố định của hợp đồng API (BRD mục 6.1, 6.2, 6.4). `code` là giá trị đúng như trong JSON.

enum Gender {
  male('male'),
  female('female');

  const Gender(this.code);
  final String code;
}

enum ActivityLevel {
  sedentary('sedentary'),
  light('light'),
  active('active');

  const ActivityLevel(this.code);
  final String code;
}

enum Goal {
  cut('cut'),
  bulk('bulk'),
  maintain('maintain');

  const Goal(this.code);
  final String code;
}

enum PlanSource {
  gemini('gemini'),
  sample('sample');

  const PlanSource(this.code);
  final String code;
}

enum MealType {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner');

  const MealType(this.code);
  final String code;
}

enum IngredientUnit {
  g('g'),
  ml('ml'),
  piece('piece'),
  tbsp('tbsp'),
  tsp('tsp');

  const IngredientUnit(this.code);
  final String code;
}

enum IngredientCategory {
  protein('protein'),
  produce('produce'),
  pantry('pantry');

  const IngredientCategory(this.code);
  final String code;
}

enum MuscleGroup {
  legs('legs'),
  chest('chest'),
  back('back'),
  core('core'),
  shoulders('shoulders'),
  arms('arms'),
  fullBody('full_body'),
  cardio('cardio');

  const MuscleGroup(this.code);
  final String code;
}

enum ExerciseTag {
  jumping('jumping'),
  kneeling('kneeling'),
  wristLoad('wrist_load'),
  backLoad('back_load'),
  overhead('overhead');

  const ExerciseTag(this.code);
  final String code;
}

enum Intensity {
  easy('easy'),
  moderate('moderate'),
  hard('hard');

  const Intensity(this.code);
  final String code;
}

enum BodyState {
  normal('normal'),
  sore('sore'),
  jointPain('joint_pain'),
  fatigued('fatigued'),
  dangerSign('danger_sign');

  const BodyState(this.code);
  final String code;
}

enum Eating {
  onPlan('on_plan'),
  over('over'),
  under('under');

  const Eating(this.code);
  final String code;
}
```

### Task 3 — Plan

`frontend_app/lib/models/api/meal_plan.dart`:

```dart
import 'codes.dart';
import 'json_read.dart';

// Plan 3 ngày đúng hợp đồng BRD 6.2. Tên lớp khác view-model cũ trong lib/models/meal_plan.dart
// (DayPlan, MealItem, GroceryItem…) mà các màn hình còn dùng tới giai đoạn 6.
// toJson() trả lại đúng JSON server đã gửi: đổi món và feedback gửi nguyên plan lên (BRD 6.4) và server
// kiểm từng ID, từng con số (#24).

class MealPlan {
  const MealPlan({
    required this.planId,
    required this.source,
    required this.warnings,
    required this.dailyTarget,
    required this.days,
    required this.groceryList,
  });

  final String planId;
  final PlanSource source;
  final List<String> warnings;
  final DailyTarget dailyTarget;
  final List<PlanDay> days;
  final List<GroceryGroup> groceryList;

  factory MealPlan.fromJson(Json json) => MealPlan(
        planId: readString(json, 'plan_id'),
        source: readCode(json, 'source', PlanSource.values, (v) => v.code),
        warnings: readList(json, 'warnings', (item) => item is String ? item : throw const FormatException('"warnings" phải là mảng chuỗi')),
        dailyTarget: DailyTarget.fromJson(readMap(json['daily_target'], 'daily_target')),
        days: readList(json, 'days', (item) => PlanDay.fromJson(readMap(item, 'days[]'))),
        groceryList: readList(json, 'grocery_list', (item) => GroceryGroup.fromJson(readMap(item, 'grocery_list[]'))),
      );

  Json toJson() => {
        'plan_id': planId,
        'source': source.code,
        'warnings': warnings,
        'daily_target': dailyTarget.toJson(),
        'days': days.map((day) => day.toJson()).toList(),
        'grocery_list': groceryList.map((group) => group.toJson()).toList(),
      };
}

class DailyTarget {
  const DailyTarget({
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final num bmi;
  final num bmr;
  final num tdee;
  final num targetCalories;
  final num proteinG;
  final num carbsG;
  final num fatG;

  factory DailyTarget.fromJson(Json json) => DailyTarget(
        bmi: readNum(json, 'bmi'),
        bmr: readNum(json, 'bmr'),
        tdee: readNum(json, 'tdee'),
        targetCalories: readNum(json, 'target_calories'),
        proteinG: readNum(json, 'protein_g'),
        carbsG: readNum(json, 'carbs_g'),
        fatG: readNum(json, 'fat_g'),
      );

  Json toJson() => {
        'bmi': bmi,
        'bmr': bmr,
        'tdee': tdee,
        'target_calories': targetCalories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

class PlanDay {
  const PlanDay({required this.dayNumber, required this.meals, required this.workout});

  final int dayNumber;
  final List<Meal> meals;
  final Workout workout;

  factory PlanDay.fromJson(Json json) => PlanDay(
        dayNumber: readInt(json, 'day_number'),
        meals: readList(json, 'meals', (item) => Meal.fromJson(readMap(item, 'meals[]'))),
        workout: Workout.fromJson(readMap(json['workout'], 'workout')),
      );

  Json toJson() => {
        'day_number': dayNumber,
        'meals': meals.map((meal) => meal.toJson()).toList(),
        'workout': workout.toJson(),
      };
}

class Meal {
  const Meal({
    required this.mealId,
    required this.mealType,
    required this.name,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ingredients,
  });

  final String mealId;
  final MealType mealType;
  final String name;
  final String portion;
  final num calories;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final List<Ingredient> ingredients;

  factory Meal.fromJson(Json json) => Meal(
        mealId: readString(json, 'meal_id'),
        mealType: readCode(json, 'meal_type', MealType.values, (v) => v.code),
        name: readString(json, 'name'),
        portion: readString(json, 'portion'),
        calories: readNum(json, 'calories'),
        proteinG: readNum(json, 'protein_g'),
        carbsG: readNum(json, 'carbs_g'),
        fatG: readNum(json, 'fat_g'),
        ingredients: readList(json, 'ingredients', (item) => Ingredient.fromJson(readMap(item, 'ingredients[]'))),
      );

  Json toJson() => {
        'meal_id': mealId,
        'meal_type': mealType.code,
        'name': name,
        'portion': portion,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'ingredients': ingredients.map((ingredient) => ingredient.toJson()).toList(),
      };
}

class Ingredient {
  const Ingredient({required this.name, required this.amount, required this.unit, required this.category});

  final String name;
  final num amount;
  final IngredientUnit unit;
  final IngredientCategory category;

  factory Ingredient.fromJson(Json json) => Ingredient(
        name: readString(json, 'name'),
        amount: readNum(json, 'amount'),
        unit: readCode(json, 'unit', IngredientUnit.values, (v) => v.code),
        category: readCode(json, 'category', IngredientCategory.values, (v) => v.code),
      );

  Json toJson() => {'name': name, 'amount': amount, 'unit': unit.code, 'category': category.code};
}

class Workout {
  const Workout({required this.title, required this.durationMinutes, required this.exercises});

  final String title;
  final int durationMinutes;
  final List<Exercise> exercises;

  factory Workout.fromJson(Json json) => Workout(
        title: readString(json, 'title'),
        durationMinutes: readInt(json, 'duration_minutes'),
        exercises: readList(json, 'exercises', (item) => Exercise.fromJson(readMap(item, 'exercises[]'))),
      );

  Json toJson() => {
        'title': title,
        'duration_minutes': durationMinutes,
        'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      };
}

class Exercise {
  const Exercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.repsOrDuration,
    required this.muscleGroup,
    required this.tags,
  });

  final String exerciseId;
  final String name;
  final int sets;
  final String repsOrDuration;
  final MuscleGroup muscleGroup;
  final List<ExerciseTag> tags;

  factory Exercise.fromJson(Json json) => Exercise(
        exerciseId: readString(json, 'exercise_id'),
        name: readString(json, 'name'),
        sets: readInt(json, 'sets'),
        repsOrDuration: readString(json, 'reps_or_duration'),
        muscleGroup: readCode(json, 'muscle_group', MuscleGroup.values, (v) => v.code),
        tags: readList(json, 'tags', (item) => readCode({'tags': item}, 'tags', ExerciseTag.values, (v) => v.code)),
      );

  Json toJson() => {
        'exercise_id': exerciseId,
        'name': name,
        'sets': sets,
        'reps_or_duration': repsOrDuration,
        'muscle_group': muscleGroup.code,
        'tags': tags.map((tag) => tag.code).toList(),
      };
}

class GroceryGroup {
  const GroceryGroup({required this.category, required this.items});

  final IngredientCategory category;
  final List<GroceryEntry> items;

  factory GroceryGroup.fromJson(Json json) => GroceryGroup(
        category: readCode(json, 'category', IngredientCategory.values, (v) => v.code),
        items: readList(json, 'items', (item) => GroceryEntry.fromJson(readMap(item, 'items[]'))),
      );

  Json toJson() => {'category': category.code, 'items': items.map((item) => item.toJson()).toList()};
}

class GroceryEntry {
  const GroceryEntry({required this.name, required this.quantity, required this.sourceMealIds});

  final String name;
  final String quantity;
  final List<String> sourceMealIds;

  factory GroceryEntry.fromJson(Json json) => GroceryEntry(
        name: readString(json, 'name'),
        quantity: readString(json, 'quantity'),
        sourceMealIds: readList(json, 'source_meal_ids', (item) => item is String ? item : throw const FormatException('"source_meal_ids" phải là mảng chuỗi')),
      );

  Json toJson() => {'name': name, 'quantity': quantity, 'source_meal_ids': sourceMealIds};
}
```

### Task 4 — Hồ sơ

`frontend_app/lib/models/api/profile.dart`:

```dart
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
```

### Task 5 — Tài khoản, lịch sử, feedback, `/health`

`frontend_app/lib/models/api/account.dart`:

```dart
import 'codes.dart';
import 'json_read.dart';
import 'meal_plan.dart';

// Đăng nhập, lịch sử, feedback, /health (BRD 6.3, 6.4).

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Json json) =>
      AuthUser(id: readString(json, 'id'), email: readString(json, 'email'), name: readString(json, 'name'));

  Json toJson() => {'id': id, 'email': email, 'name': name};
}

class AuthResult {
  const AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;

  factory AuthResult.fromJson(Json json) => AuthResult(
        accessToken: readString(json, 'access_token'),
        user: AuthUser.fromJson(readMap(json['user'], 'user')),
      );

  Json toJson() => {'access_token': accessToken, 'user': user.toJson()};
}

class PlanSummary {
  const PlanSummary({required this.id, required this.createdAt, required this.targetCalories});

  final String id;
  final DateTime createdAt;
  final num targetCalories;

  factory PlanSummary.fromJson(Json json) {
    final createdAt = DateTime.tryParse(readString(json, 'created_at'));
    if (createdAt == null) throw const FormatException('"created_at" phải là thời điểm ISO 8601');
    return PlanSummary(id: readString(json, 'id'), createdAt: createdAt.toUtc(), targetCalories: readNum(json, 'target_calories'));
  }

  Json toJson() => {'id': id, 'created_at': createdAt.toUtc().toIso8601String(), 'target_calories': targetCalories};
}

List<PlanSummary> planSummariesFromJson(Json json) =>
    readList(json, 'plans', (item) => PlanSummary.fromJson(readMap(item, 'plans[]')));

class FeedbackResult {
  const FeedbackResult({required this.plan, this.safetyWarning});

  final MealPlan plan;
  // Khác null khi người dùng báo dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực) — app phải hiện nổi bật.
  final String? safetyWarning;

  factory FeedbackResult.fromJson(Json json) {
    final warning = json['safety_warning'];
    return FeedbackResult(
      plan: MealPlan.fromJson(readMap(json['plan'], 'plan')),
      safetyWarning: warning == null ? null : readString(readMap(warning, 'safety_warning'), 'message'),
    );
  }

  Json toJson() => {
        'plan': plan.toJson(),
        'safety_warning': safetyWarning == null ? null : {'message': safetyWarning},
      };
}

class HealthStatus {
  const HealthStatus({required this.status, required this.gemini, required this.authMode});

  final String status;
  // "configured" | "fallback" — backend đang dùng Gemini thật hay dữ liệu mẫu.
  final String gemini;
  // "mock" | "google".
  final String authMode;

  factory HealthStatus.fromJson(Json json) => HealthStatus(
        status: readString(json, 'status'),
        gemini: readString(json, 'gemini'),
        authMode: readString(json, 'auth_mode'),
      );

  Json toJson() => {'status': status, 'gemini': gemini, 'auth_mode': authMode};
}

// Câu trả lời bảng feedback cuối ngày (BRD 6.4).
class FeedbackAnswers {
  const FeedbackAnswers({required this.dayNumber, required this.intensity, required this.bodyStates, required this.eating});

  final int dayNumber;
  final Intensity intensity;
  final Set<BodyState> bodyStates;
  final Eating eating;

  Json toJson() => {
        'day_number': dayNumber,
        'intensity': intensity.code,
        'body_states': bodyStates.map((state) => state.code).toList(),
        'eating': eating.code,
      };
}
```

### Task 6 — Test vòng tròn

`frontend_app/test/fixture_loader.dart`:

```dart
import 'dart:convert';
import 'dart:io';

// Fixture hợp đồng do backend xuất (`cd backend_api && npm run fixtures:update`) — JSON thật server trả qua HTTP.
Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;
```

`frontend_app/test/models/contract_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/json_read.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/api/profile.dart';

import '../fixture_loader.dart';

// Vòng tròn fromJson → toJson phải ra đúng JSON server đã gửi: đổi món và feedback gửi nguyên plan lên,
// server kiểm từng ID và con số (BRD 6.4, #24). Fixture lệch với backend → test backend
// contract-fixtures.e2e-spec.ts đỏ trước.
void main() {
  group('vòng tròn JSON với fixture của backend', () {
    for (final name in ['generate_plan', 'meals_swap', 'exercises_swap']) {
      test('$name giữ nguyên từng trường và từng con số', () {
        final json = loadFixture(name);
        final plan = name == 'generate_plan' ? json : json['plan'] as Json;
        expect(MealPlan.fromJson(plan).toJson(), equals(plan));
      });
    }

    for (final name in ['feedback', 'feedback_danger']) {
      test('$name giữ nguyên plan và safety_warning', () {
        final json = loadFixture(name);
        expect(FeedbackResult.fromJson(json).toJson(), equals(json));
      });
    }

    test('profile gửi đi đúng request của backend', () {
      final json = loadFixture('profile');
      expect(Profile.fromJson(json).toJson(), equals(json));
    });

    test('auth_login, history, health', () {
      final auth = loadFixture('auth_login');
      expect(AuthResult.fromJson(auth).toJson(), equals(auth));
      final history = loadFixture('history');
      expect({'plans': planSummariesFromJson(history).map((plan) => plan.toJson()).toList()}, equals(history));
      final health = loadFixture('health');
      expect(HealthStatus.fromJson(health).toJson(), equals(health));
    });
  });

  test('giữ đúng kiểu số: macro thập phân vẫn thập phân, calo nguyên vẫn nguyên', () {
    final meal = MealPlan.fromJson(loadFixture('generate_plan')).days.first.meals.first;
    expect(meal.calories, isA<int>());
    expect(meal.proteinG, isA<double>());
    expect(meal.toJson()['protein_g'], same(meal.proteinG));
  });

  group('JSON sai hợp đồng → FormatException nêu rõ trường', () {
    test('mã lạ', () {
      final json = loadFixture('generate_plan');
      final day = (json['days'] as List).first as Json;
      day['meals'] = [
        {...(day['meals'] as List).first as Json, 'meal_type': 'Bữa sáng'},
        ...(day['meals'] as List).skip(1),
      ];
      expect(() => MealPlan.fromJson(json), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('meal_type'))));
    });

    test('thiếu trường', () {
      final json = loadFixture('generate_plan')..remove('daily_target');
      expect(() => MealPlan.fromJson(json), throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('daily_target'))));
    });

    test('sai kiểu', () {
      final json = loadFixture('generate_plan')..['plan_id'] = 123;
      expect(() => MealPlan.fromJson(json), throwsFormatException);
    });
  });

  test('FeedbackAnswers gửi đúng mã của BRD 6.4', () {
    const answers = FeedbackAnswers(
      dayNumber: 1,
      intensity: Intensity.hard,
      bodyStates: {BodyState.sore, BodyState.jointPain},
      eating: Eating.onPlan,
    );
    expect(answers.toJson(), {
      'day_number': 1,
      'intensity': 'hard',
      'body_states': ['sore', 'joint_pain'],
      'eating': 'on_plan',
    });
  });
}
```

### Task 7 — Cổng kiểm tra F03

```bash
cd frontend_app
flutter analyze            # No issues found!
flutter test test/models   # +12: All tests passed!
```
