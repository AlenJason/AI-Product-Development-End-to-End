import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/recipe_guide.dart';

void main() {
  test('RecipeGuide sinh hướng dẫn chi tiết cho Bánh xèo tôm thịt', () {
    const meal = Meal(
      mealId: 'm1',
      mealType: MealType.breakfast,
      name: 'Bánh xèo tôm thịt',
      portion: '2 bánh',
      calories: 370,
      proteinG: 20,
      carbsG: 45,
      fatG: 12,
      ingredients: [
        Ingredient(name: 'trứng gà', amount: 100, unit: IngredientUnit.g, category: IngredientCategory.protein),
        Ingredient(name: 'bột gạo', amount: 50, unit: IngredientUnit.g, category: IngredientCategory.pantry),
        Ingredient(name: 'tôm tươi', amount: 30, unit: IngredientUnit.g, category: IngredientCategory.protein),
      ],
    );

    final guide = RecipeGuide.forMeal(meal);
    expect(guide.steps.length, 4);
    expect(guide.estimatedMinutes, 20);
    expect(guide.steps.first.title, contains('Sơ chế'));
    expect(guide.steps.any((s) => s.instruction.contains('chảo')), isTrue);
    expect(guide.cookingTip, isNotEmpty);
  });

  test('RecipeGuide nhận diện món xào tổng quát', () {
    const meal = Meal(
      mealId: 'm2',
      mealType: MealType.lunch,
      name: 'Ức gà xào nấm',
      portion: '1 đĩa',
      calories: 450,
      proteinG: 35,
      carbsG: 20,
      fatG: 10,
      ingredients: [
        Ingredient(name: 'Ức gà', amount: 150, unit: IngredientUnit.g, category: IngredientCategory.protein),
        Ingredient(name: 'Nấm rơm', amount: 80, unit: IngredientUnit.g, category: IngredientCategory.produce),
      ],
    );

    final guide = RecipeGuide.forMeal(meal);
    expect(guide.steps.length, 4);
    expect(guide.steps.any((s) => s.title.contains('Xào')), isTrue);
  });
}
