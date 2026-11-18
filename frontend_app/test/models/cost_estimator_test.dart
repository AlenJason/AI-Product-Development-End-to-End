import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/cost_estimator.dart';

void main() {
  group('Cost Estimator Tests', () {
    test('formatVnd formats thousands and millions accurately', () {
      expect(formatVnd(25000), '25.000đ');
      expect(formatVnd(185000), '185.000đ');
      expect(formatVnd(5000), '5.000đ');
    });

    test('estimateMealCost assigns budget tier for low cost meals (eggs, tofu)', () {
      const cheapMeal = Meal(
        mealId: 'm1_1',
        mealType: MealType.breakfast,
        name: 'Bánh mì trứng ốp la',
        portion: '1 ổ',
        calories: 360,
        proteinG: 18,
        carbsG: 40,
        fatG: 12,
        ingredients: [
          Ingredient(name: 'Trứng gà', amount: 2, unit: IngredientUnit.piece, category: IngredientCategory.protein),
          Ingredient(name: 'Bánh mì', amount: 1, unit: IngredientUnit.piece, category: IngredientCategory.pantry),
          Ingredient(name: 'Dưa leo', amount: 30, unit: IngredientUnit.g, category: IngredientCategory.produce),
        ],
      );

      final cost = estimateMealCost(cheapMeal);
      expect(cost.tier, MealCostTier.budget);
      expect(cost.averageVnd, lessThan(25000));
      expect(cost.formattedApprox, contains('đ'));
    });

    test('estimateMealCost assigns premium tier for beef or salmon meals', () {
      const premiumMeal = Meal(
        mealId: 'm1_2',
        mealType: MealType.lunch,
        name: 'Thịt bò xào ớt chuông',
        portion: '1 đĩa vừa',
        calories: 620,
        proteinG: 42,
        carbsG: 65,
        fatG: 18,
        ingredients: [
          Ingredient(name: 'Thịt bò nạc', amount: 150, unit: IngredientUnit.g, category: IngredientCategory.protein),
          Ingredient(name: 'Ớt chuông', amount: 100, unit: IngredientUnit.g, category: IngredientCategory.produce),
          Ingredient(name: 'Gạo tẻ', amount: 80, unit: IngredientUnit.g, category: IngredientCategory.pantry),
        ],
      );

      final cost = estimateMealCost(premiumMeal);
      expect(cost.tier, MealCostTier.premium);
      expect(cost.averageVnd, greaterThan(45000));
    });

    test('estimateGroceryCost estimates 3-day totals and breakdown', () {
      const groups = [
        GroceryGroup(
          category: IngredientCategory.protein,
          items: [
            GroceryEntry(name: 'Thịt gà bỏ da', quantity: '300g', sourceMealIds: ['m1_1']),
            GroceryEntry(name: 'Trứng gà', quantity: '4 quả', sourceMealIds: ['m2_1']),
          ],
        ),
        GroceryGroup(
          category: IngredientCategory.produce,
          items: [
            GroceryEntry(name: 'Rau muống', quantity: '300g', sourceMealIds: ['m1_2']),
          ],
        ),
        GroceryGroup(
          category: IngredientCategory.pantry,
          items: [
            GroceryEntry(name: 'Gạo tẻ', quantity: '500g', sourceMealIds: ['m1_2']),
          ],
        ),
      ];

      final grocery = estimateGroceryCost(groups);
      expect(grocery.totalVnd, greaterThan(50000));
      expect(grocery.proteinVnd, greaterThan(0));
      expect(grocery.produceVnd, greaterThan(0));
      expect(grocery.perDayVnd, equals((grocery.totalVnd / 3).round()));
      expect(grocery.formattedTotal, contains('đ'));
    });
  });
}
