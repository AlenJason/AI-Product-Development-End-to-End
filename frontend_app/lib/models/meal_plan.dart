class MealPlanResponse {
  final String planId;
  final List<dynamic> days;
  final dynamic dailyTarget;
  final List<GroceryItemModel> groceryList;

  MealPlanResponse({required this.planId, required this.days, this.dailyTarget, this.groceryList = const []});
  
  factory MealPlanResponse.fromJson(Map<String, dynamic> json) {
    return MealPlanResponse(
      planId: json['plan_id'] ?? '',
      days: json['days'] ?? [],
      dailyTarget: json['daily_target'],
      groceryList: [],
    );
  }
  
  Map<String, dynamic> toJson() => {};
}

class MealEntry {
  final String id;
  final String name;
  final String? imageUrl;
  final String type; // e.g., 'BỮA SÁNG', 'BỮA TRƯA'
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<Ingredient> ingredients;

  MealEntry({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.type,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.ingredients = const [],
  });
}

class Ingredient {
  final String name;
  final String amount;
  
  Ingredient({required this.name, required this.amount});
}

class WorkoutDay {
  final String id;
  final String name; // e.g., 'Vận động toàn thân tại nhà'
  final String type; // e.g., 'NHẸ · KHÔNG DỤNG CỤ'
  final int durationMinutes;
  final int exercisesCount;
  final int caloriesBurned;
  final List<ExerciseEntry> exercises;

  WorkoutDay({
    required this.id,
    required this.name,
    required this.type,
    required this.durationMinutes,
    required this.exercisesCount,
    required this.caloriesBurned,
    this.exercises = const [],
  });
}

class ExerciseEntry {
  final String id;
  final String name;
  final String? imageUrl;
  final String muscleGroup; // e.g., 'Chân · Mông'
  final String sets;
  final String reps;
  final int difficultyLevel; // 1, 2, 3

  ExerciseEntry({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    this.difficultyLevel = 1,
  });
}

class DayPlan {
  final String id;
  final String title;
  final String subtitle;
  final List<MealEntry> meals;
  final WorkoutDay workout;

  DayPlan({required this.id, required this.title, required this.subtitle, required this.meals, required this.workout});
}

class GroceryItemModel {
  final String id;
  final String name;
  final String amount;
  bool isChecked;

  GroceryItemModel({required this.id, required this.name, this.amount = '', this.isChecked = false});
}

class ProfileData {
  final int age;
  final dynamic gender;
  final double heightCm;
  final double weightKg;
  final dynamic activityLevel;
  final dynamic goal;
  final dynamic restrictions;
  
  ProfileData({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    this.activityLevel,
    this.goal,
    this.restrictions,
  });
}

class GroceryCategoryModel {
  final String id;
  final String name;
  final List<GroceryItemModel> items;

  GroceryCategoryModel({required this.id, required this.name, required this.items});
}

