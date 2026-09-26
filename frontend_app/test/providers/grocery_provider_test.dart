import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final saved = {
    PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
  };
  final plan = MealPlan.fromJson(loadFixture('generate_plan'));
  final firstGroup = plan.groceryList.first;
  final key = GroceryProvider.keyOf(firstGroup.category, firstGroup.items.first);

  Future<(GroceryProvider, PlanProvider, FakeBackend, SharedPreferences)> create(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final plans = PlanProvider(api: backend.api, prefs: prefs);
    return (GroceryProvider(prefs: prefs, plans: plans), plans, backend, prefs);
  }

  test('đánh dấu đã mua, đã có sẵn; mở lại app vẫn còn', () async {
    final (grocery, plans, _, prefs) = await create(saved);
    await grocery.toggleBought(key);
    expect(grocery.isBought(key), isTrue);
    await grocery.markHave(key);
    expect(grocery.isHave(key), isTrue);
    expect(grocery.isBought(key), isFalse, reason: 'đã có sẵn thì không tính là đã mua');

    final reopened = GroceryProvider(prefs: prefs, plans: plans);
    expect(reopened.isHave(key), isTrue);
    await reopened.restoreHave(key);
    expect(reopened.isHave(key), isFalse);
  });

  test('khoá gồm cả lượng: đổi món làm lượng thay đổi thì dòng đó hết tích', () {
    final entry = firstGroup.items.first;
    final more = GroceryEntry(name: entry.name, quantity: '9999g', sourceMealIds: entry.sourceMealIds);
    expect(GroceryProvider.keyOf(firstGroup.category, more), isNot(key));
  });

  test('plan mới (plan_id khác) → bắt đầu lại từ đầu', () async {
    final (grocery, plans, backend, prefs) = await create(saved);
    await grocery.toggleBought(key);
    backend.responses['/api/v1/generate-plan'] = loadFixture('generate_plan')..['plan_id'] = 'khac';
    await plans.generate(Profile.fromJson(loadFixture('profile')));
    expect(grocery.isBought(key), isFalse);
    expect(prefs.containsKey(GroceryProvider.stateKey), isFalse);
  });

  test('trạng thái lưu của plan khác hoặc bị hỏng → bỏ qua', () async {
    final (other, _, _, _) = await create({
      ...saved,
      GroceryProvider.stateKey: jsonEncode({
        'plan_id': 'khac',
        'bought': [key],
        'have': [],
      }),
    });
    expect(other.isBought(key), isFalse);
    final (broken, _, _, _) = await create({...saved, GroceryProvider.stateKey: '{"plan_id": 1'});
    expect(broken.isBought(key), isFalse);
  });
}
