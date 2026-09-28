import 'package:flutter/foundation.dart';
import '../models/meal_plan.dart';

class MockDataProvider extends ChangeNotifier {
  late List<DayPlan> planDays;
  late List<GroceryCategoryModel> groceryCategories;
  int currentDayIndex = 0;

  MealEntry get todayBreakfast => planDays[currentDayIndex].meals.firstWhere((m) => m.type == 'BỮA SÁNG');
  WorkoutDay get todayWorkout => planDays[currentDayIndex].workout;

  MockDataProvider() {
    _initializeMockData();
  }

  void _initializeMockData() {
    final defaultWorkout = WorkoutDay(
      id: 'workout_1',
      name: 'Vận động toàn thân tại nhà',
      type: 'NHẸ · KHÔNG DỤNG CỤ',
      durationMinutes: 20,
      exercisesCount: 3,
      caloriesBurned: 120,
      exercises: [
        ExerciseEntry(
          id: 'ex_1',
          name: 'Squat tay không',
          muscleGroup: 'Chân · Mông',
          sets: '3 hiệp',
          reps: '12-15 lần',
          difficultyLevel: 1,
        ),
        ExerciseEntry(
          id: 'ex_2',
          name: 'Chống đẩy khuỷu gối',
          muscleGroup: 'Ngực · Tay sau',
          sets: '3 hiệp',
          reps: '10-12 lần',
          difficultyLevel: 2,
        ),
        ExerciseEntry(
          id: 'ex_3',
          name: 'Gập bụng cơ bản',
          muscleGroup: 'Bụng',
          sets: '3 hiệp',
          reps: '15-20 lần',
          difficultyLevel: 1,
        ),
      ],
    );

    planDays = [
      DayPlan(
        id: 'day_1',
        title: 'Ngày 1',
        subtitle: 'Hôm nay',
        workout: defaultWorkout,
        meals: [
          MealEntry(
            id: 'meal_1',
            name: 'Bún thịt bò nạc',
            type: 'BỮA SÁNG',
            imageUrl: 'assets/images/meals/bun_thit_bo.jpg',
            calories: 410,
            protein: 25,
            carbs: 55,
            fat: 10,
            ingredients: [
              Ingredient(name: 'Bún tươi', amount: '150g'),
              Ingredient(name: 'Thịt bò nạc', amount: '70g'),
              Ingredient(name: 'Rau thơm', amount: '20g'),
              Ingredient(name: 'Hành lá', amount: '10g'),
              Ingredient(name: 'Nước dùng', amount: '300ml'),
            ],
          ),
          MealEntry(
            id: 'meal_2',
            name: 'Cơm gà xào nấm',
            type: 'BỮA TRƯA',
            imageUrl: 'assets/images/meals/com_ga.jpg',
            calories: 630,
            protein: 42,
            carbs: 72,
            fat: 18,
          ),
          MealEntry(
            id: 'meal_3',
            name: 'Đậu phụ sốt cà chua',
            type: 'BỮA TỐI',
            imageUrl: 'assets/images/meals/dau_phu.jpg',
            calories: 555,
            protein: 35,
            carbs: 56,
            fat: 20,
          ),
        ],
      ),
      DayPlan(
        id: 'day_2',
        title: 'Ngày 2',
        subtitle: '25/09',
        workout: defaultWorkout,
        meals: [
          MealEntry(
            id: 'meal_4',
            name: 'Phở gà',
            type: 'BỮA SÁNG',
            calories: 380,
            protein: 30,
            carbs: 50,
            fat: 8,
          ),
          MealEntry(
            id: 'meal_5',
            name: 'Cơm sườn nướng',
            type: 'BỮA TRƯA',
            calories: 700,
            protein: 40,
            carbs: 80,
            fat: 25,
          ),
        ],
      ),
      DayPlan(
        id: 'day_3',
        title: 'Ngày 3',
        subtitle: '26/09',
        workout: defaultWorkout,
        meals: [
          MealEntry(
            id: 'meal_6',
            name: 'Bánh mì ốp la',
            type: 'BỮA SÁNG',
            calories: 450,
            protein: 20,
            carbs: 45,
            fat: 15,
          ),
        ],
      ),
    ];

    groceryCategories = [
      GroceryCategoryModel(
        id: 'cat_1',
        name: 'Đạm',
        items: [
          GroceryItemModel(id: 'g_1', name: 'Ức gà', amount: '500g', isChecked: true),
          GroceryItemModel(id: 'g_2', name: 'Thịt bò', amount: '300g', isChecked: false),
          GroceryItemModel(id: 'g_3', name: 'Đậu phụ', amount: '4 miếng', isChecked: true),
          GroceryItemModel(id: 'g_4', name: 'Trứng', amount: '6 quả', isChecked: true),
        ],
      ),
      GroceryCategoryModel(
        id: 'cat_2',
        name: 'Rau củ quả',
        items: [
          GroceryItemModel(id: 'g_5', name: 'Cà chua', amount: '500g', isChecked: true),
          GroceryItemModel(id: 'g_6', name: 'Rau cải', amount: '400g', isChecked: true),
          GroceryItemModel(id: 'g_7', name: 'Bí đỏ', amount: '300g', isChecked: false),
          GroceryItemModel(id: 'g_8', name: 'Nấm rơm', amount: '200g', isChecked: false),
        ],
      ),
    ];
  }

  void setPlanDay(int index) {
    currentDayIndex = index;
    notifyListeners();
  }

  List<MealEntry> getMealAlternatives(String currentMealId) {
    return [
      MealEntry(
        id: 'meal_alt_1',
        name: 'Cơm gà xé rau củ',
        type: 'BỮA SÁNG',
        imageUrl: 'assets/images/meals/com_ga.jpg',
        calories: 430,
        protein: 28,
        carbs: 50,
        fat: 12,
      ),
      MealEntry(
        id: 'meal_alt_2',
        name: 'Phở bò tái nạm',
        type: 'BỮA SÁNG',
        imageUrl: 'assets/images/meals/pho_bo.jpg',
        calories: 450,
        protein: 22,
        carbs: 60,
        fat: 15,
      ),
    ];
  }

  List<ExerciseEntry> getExerciseAlternatives(String currentExerciseId) {
    return [
      ExerciseEntry(
        id: 'ex_alt_1',
        name: 'Wall Push-up',
        muscleGroup: 'Ngực',
        sets: '3 hiệp',
        reps: '10-12 lần',
        difficultyLevel: 1,
      ),
    ];
  }

  void applyAdaptiveWorkoutReduction() {
    final dayPlan = planDays[currentDayIndex];
    planDays[currentDayIndex] = DayPlan(
      id: dayPlan.id,
      title: dayPlan.title,
      subtitle: dayPlan.subtitle,
      meals: dayPlan.meals,
      workout: WorkoutDay(
        id: dayPlan.workout.id,
        name: 'Phục hồi sau tập',
        type: 'PHỤC HỒI NHẸ NHÀNG',
        durationMinutes: (dayPlan.workout.durationMinutes * 0.85).round(),
        exercisesCount: dayPlan.workout.exercisesCount,
        caloriesBurned: (dayPlan.workout.caloriesBurned * 0.8).round(),
        exercises: List.from(dayPlan.workout.exercises),
      ),
    );
    notifyListeners();
  }

  void swapMeal(String newMealId) {
    final alternatives = getMealAlternatives(todayBreakfast.id);
    final newMeal = alternatives.firstWhere((m) => m.id == newMealId);
    
    final dayPlan = planDays[currentDayIndex];
    final index = dayPlan.meals.indexWhere((m) => m.type == 'BỮA SÁNG');
    if (index != -1) {
      dayPlan.meals[index] = newMeal;
      notifyListeners();
    }
  }

  void swapExercise(String oldExerciseId, String newExerciseId) {
    final alternatives = getExerciseAlternatives(oldExerciseId);
    final newEx = alternatives.firstWhere((e) => e.id == newExerciseId);
    
    final dayPlan = planDays[currentDayIndex];
    final index = dayPlan.workout.exercises.indexWhere((e) => e.id == oldExerciseId);
    if (index != -1) {
      dayPlan.workout.exercises[index] = newEx;
      notifyListeners();
    }
  }

  void toggleGroceryItem(String itemId) {
    for (var cat in groceryCategories) {
      for (var item in cat.items) {
        if (item.id == itemId) {
          item.isChecked = !item.isChecked;
          notifyListeners();
          return;
        }
      }
    }
  }
}



