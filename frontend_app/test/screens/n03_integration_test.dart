import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/routes.dart';
import 'package:my_ai_app/screens/home/home_screen.dart';
import 'package:my_ai_app/screens/plan/plan_screen.dart';
import 'package:my_ai_app/screens/grocery/grocery_screen.dart';
import 'package:my_ai_app/screens/meal/meal_detail_screen.dart';
import 'package:my_ai_app/screens/workout/workout_detail_screen.dart';
import 'package:provider/provider.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

Widget app(Harness h, Widget screen) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: h.plans),
    ChangeNotifierProvider.value(value: h.grocery),
  ],
  child: MaterialApp(
    onGenerateRoute: appGenerateRoute,
    home: Scaffold(body: screen),
  ),
);

void main() {
  testWidgets(
    'dashboard uses current day, real IDs and empty state sends no HTTP',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      await tester.pumpWidget(app(h, const HomeScreen()));
      final meal = h.plans.plan!.days.first.meals.first;
      await scrollTo(tester, find.text(meal.name));
      expect(find.text(meal.name), findsOneWidget);
      await scrollTo(tester, find.byKey(ValueKey(meal.mealId)));
      await tester.tap(find.byKey(ValueKey(meal.mealId)));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MealDetailScreen>(find.byType(MealDetailScreen)).mealId,
        meal.mealId,
      );
      expect(h.backend.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
      final empty = await Harness.create(tester);
      await tester.pumpWidget(app(empty, const HomeScreen()));
      expect(find.text('Chưa có kế hoạch.'), findsOneWidget);
      expect(empty.backend.requests, isEmpty);
    },
  );

  testWidgets('plan switches all three days and opens exact exercise', (
    tester,
  ) async {
    final h = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(app(h, const PlanScreen()));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ngày 3'));
    await tester.pumpAndSettle();
    final day = h.plans.plan!.days[2];
    await scrollTo(
      tester,
      find.byKey(ValueKey(day.workout.exercises.first.exerciseId)),
    );
    await tester.tap(
      find.byKey(ValueKey(day.workout.exercises.first.exerciseId)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<WorkoutDetailScreen>(find.byType(WorkoutDetailScreen))
          .exerciseId,
      day.workout.exercises.first.exerciseId,
    );
  });

  for (final meal in [true, false]) {
    testWidgets(
      '${meal ? 'meal' : 'exercise'} swap: failure keeps plan; retry, busy, profile, persistence',
      (tester) async {
        final h = await Harness.create(tester, saved: savedPlan());
        final original = h.plans.plan!.toJson();
        final id = meal
            ? h.plans.plan!.days[1].meals[1].mealId
            : h.plans.plan!.days[1].workout.exercises.first.exerciseId;
        final endpoint = meal ? '/api/v1/meals/swap' : '/api/v1/exercises/swap';
        final response = loadFixture(meal ? 'meals_swap' : 'exercises_swap');
        (response['plan'] as Map<String, dynamic>)['plan_id'] =
            h.plans.plan!.planId;
        h.backend.responses[endpoint] = response;
        await tester.pumpWidget(
          app(
            h,
            meal
                ? MealDetailScreen(mealId: id)
                : WorkoutDetailScreen(exerciseId: id),
          ),
        );
        final swap = find.text(meal ? 'Đổi món' : 'Đổi bài');
        await scrollTo(tester, swap);
        await tester.tap(swap);
        await tester.pumpAndSettle();
        h.backend.failWith = 422;
        await tester.tap(find.text('Xác nhận đổi'));
        await tester.pumpAndSettle();
        expect(h.plans.plan!.toJson(), original);
        expect(find.text('Thử lại'), findsOneWidget);
        h.backend.failWith = null;
        h.backend.hold = Completer<void>();
        await tester.tap(find.text('Thử lại'));
        await tester.pump();
        await tester.tap(find.text('Xác nhận đổi'));
        await tester.pump();
        expect(h.backend.requests.length, 2);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        h.backend.hold!.complete();
        await tester.pumpAndSettle();
        final body =
            jsonDecode(h.backend.requests.last.body) as Map<String, dynamic>;
        expect(body[meal ? 'meal_id' : 'exercise_id'], id);
        expect(body['profile'], loadFixture('profile'));
        expect(body['plan'], original);
        expect(h.plans.plan!.toJson(), response['plan']);
        final restored = PlanProvider(api: h.backend.api, prefs: h.prefs);
        expect(restored.plan!.toJson(), response['plan']);
      },
    );
  }

  testWidgets('409 offers regenerate, missing detail stays safe', (
    tester,
  ) async {
    final h = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(
      app(
        h,
        MealDetailScreen(mealId: h.plans.plan!.days.first.meals.first.mealId),
      ),
    );
    await scrollTo(tester, find.text('Đổi món'));
    await tester.tap(find.text('Đổi món'));
    await tester.pumpAndSettle();
    h.backend.failWith = 409;
    await tester.tap(find.text('Xác nhận đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo kế hoạch mới'), findsOneWidget);
    expect(h.backend.requests.length, 1);
    await tester.pumpWidget(app(h, const MealDetailScreen(mealId: 'missing')));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tìm thấy món ăn trong kế hoạch hiện tại.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'grocery reflects server swap, keeps unchanged checks, restores have and bought',
    (tester) async {
      final h = await Harness.create(tester, saved: savedPlan());
      final group = h.plans.plan!.groceryList.first;
      final entry = group.items.first;
      final key = GroceryProvider.keyOf(group.category, entry);
      await tester.pumpWidget(app(h, const GroceryScreen()));
      await scrollTo(tester, find.byKey(ValueKey(key)));
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.grocery.isBought(key), isTrue);
      final response = loadFixture('meals_swap');
      final updated = response['plan'] as Map<String, dynamic>;
      updated['plan_id'] = h.plans.plan!.planId;
      // A server response retains one unchanged line and changes the other lines.
      final groups = updated['grocery_list'] as List<dynamic>;
      (groups.first as Map<String, dynamic>)['items'] = [
        entry.toJson(),
        {
          'name': 'Nguyên liệu mới từ máy chủ',
          'quantity': '123g',
          'source_meal_ids': ['m1_1'],
        },
      ];
      h.backend.responses['/api/v1/meals/swap'] = response;
      await h.plans.swapMeal('m1_1');
      await tester.pumpAndSettle();
      expect(h.grocery.isBought(key), isTrue);
      await scrollTo(tester, find.text('Nguyên liệu mới từ máy chủ'));
      expect(find.text('123g'), findsOneWidget);
      final restored = GroceryProvider(prefs: h.prefs, plans: h.plans);
      expect(restored.isBought(key), isTrue);
      await h.grocery.markHave(key);
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(key)), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Hiện nguyên liệu đã có sẵn'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Hiện nguyên liệu đã có sẵn'));
      await tester.tap(find.text('Hiện nguyên liệu đã có sẵn'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(ValueKey(key)));
      expect(find.byKey(ValueKey(key)), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.text('Cần mua'),
        ),
      );
      await tester.pumpAndSettle();
      expect(h.grocery.isHave(key), isFalse);
      expect(
        MealPlan.fromJson(updated).groceryList.first.items[1].quantity,
        '123g',
      );
    },
  );
}
