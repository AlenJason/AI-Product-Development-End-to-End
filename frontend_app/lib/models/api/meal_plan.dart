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
