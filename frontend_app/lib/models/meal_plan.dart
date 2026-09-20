class MacroNutrient {
  final String label;
  final String value;
  final double progress; // 0.0 to 1.0
  final int colorValue;

  const MacroNutrient({
    required this.label,
    required this.value,
    required this.progress,
    required this.colorValue,
  });
}

class MealItem {
  final String period; // BỮA SÁNG, BỮA TRƯA, BỮA TỐI
  final String name;
  final int calories;
  final int protein;
  final List<String> ingredients;

  const MealItem({
    required this.period,
    required this.name,
    required this.calories,
    required this.protein,
    required this.ingredients,
  });

  MealItem copyWith({
    String? period,
    String? name,
    int? calories,
    int? protein,
    List<String>? ingredients,
  }) {
    return MealItem(
      period: period ?? this.period,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}

class DayPlan {
  final int dayNumber;
  final String label;
  final int targetCalories;
  final List<MacroNutrient> macros;
  final List<MealItem> meals;

  const DayPlan({
    required this.dayNumber,
    required this.label,
    required this.targetCalories,
    required this.macros,
    required this.meals,
  });
}

class WorkoutExercise {
  final String icon;
  final String name;
  final String detail;

  const WorkoutExercise({
    required this.icon,
    required this.name,
    required this.detail,
  });
}

class GroceryItem {
  final String name;
  final String quantity;
  final String category;
  bool isChecked;

  GroceryItem({
    required this.name,
    required this.quantity,
    this.category = 'Thịt & Cá',
    this.isChecked = false,
  });
}

class GroceryCategory {
  final String icon;
  final String title;
  final List<GroceryItem> items;

  const GroceryCategory({
    required this.icon,
    required this.title,
    required this.items,
  });
}
