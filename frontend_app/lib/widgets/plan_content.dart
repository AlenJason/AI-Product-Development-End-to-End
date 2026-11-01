import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/routes.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/api/codes.dart';
import '../models/api/meal_plan.dart';
import '../providers/plan_provider.dart';
import '../screens/meal/meal_swap_sheet.dart';
import '../screens/workout/workout_swap_sheet.dart';
import 'ui_kit.dart';

String number(num value) =>
    value.toStringAsFixed(value % 1 == 0 ? 0 : 1).replaceAll('.', ',');
String mealLabel(MealType type) => switch (type) {
  MealType.breakfast => 'Bữa sáng',
  MealType.lunch => 'Bữa trưa',
  MealType.dinner => 'Bữa tối',
};
String unitLabel(IngredientUnit unit) => switch (unit) {
  IngredientUnit.g => 'g',
  IngredientUnit.ml => 'ml',
  IngredientUnit.piece => 'cái',
  IngredientUnit.tbsp => 'thìa canh',
  IngredientUnit.tsp => 'thìa cà phê',
};
String muscleLabel(MuscleGroup group) => switch (group) {
  MuscleGroup.legs => 'Chân',
  MuscleGroup.chest => 'Ngực',
  MuscleGroup.back => 'Lưng',
  MuscleGroup.core => 'Cơ trung tâm',
  MuscleGroup.shoulders => 'Vai',
  MuscleGroup.arms => 'Tay',
  MuscleGroup.fullBody => 'Toàn thân',
  MuscleGroup.cardio => 'Tim mạch',
};

Future<void> openSwap(BuildContext context, String id, {required bool meal}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 430),
      backgroundColor: Colors.white,
      builder: (_) =>
          meal ? MealSwapSheet(mealId: id) : WorkoutSwapSheet(exerciseId: id),
    );

class PlanEmpty extends StatelessWidget {
  const PlanEmpty({super.key, this.message = 'Chưa có kế hoạch.'});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SurfacePanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ToneIcon(icon: Icons.calendar_month_outlined),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.h4),
            const SizedBox(height: 8),
            Text(
              'Hoàn thành hồ sơ để SmartFit chuẩn bị kế hoạch phù hợp.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: 'Tạo kế hoạch mới',
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.onboardingBasicInfo,
                arguments: context.read<PlanProvider?>()?.editableProfile,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlanNotice extends StatelessWidget {
  const PlanNotice({super.key, required this.plan});
  final MealPlan plan;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: plan.source == PlanSource.sample
              ? const Color(0xFFF5F3FF)
              : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 14,
              color: plan.source == PlanSource.sample
                  ? const Color(0xFF7C3AED)
                  : AppColors.primaryDark,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                plan.source == PlanSource.sample
                    ? 'Kế hoạch mẫu từ máy chủ'
                    : 'Kế hoạch do AI tạo (${plan.source.code})',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      if (plan.warnings.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: NoticePanel(message: plan.warnings.first),
        ),
      if (plan.warnings.length > 1)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            'Lưu ý khác (${plan.warnings.length - 1})',
            style: AppTextStyles.bodySmall,
          ),
          children: [
            for (final warning in plan.warnings.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NoticePanel(message: warning),
              ),
          ],
        ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế.',
          style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
        ),
      ),
    ],
  );
}

class MacroStrip extends StatelessWidget {
  const MacroStrip({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.light = false,
  });
  final num calories, protein, carbs, fat;
  final bool light;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final stat in [
        (number(calories), 'kcal'),
        ('${number(protein)}g', 'Đạm'),
        ('${number(carbs)}g', 'Tinh bột'),
        ('${number(fat)}g', 'Chất béo'),
      ])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.$1,
                  style: AppTextStyles.label.copyWith(
                    fontSize: 13,
                    color: light ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.$2,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10,
                    color: light ? Colors.white70 : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class EnergySummary extends StatelessWidget {
  const EnergySummary({
    super.key,
    required this.day,
    required this.target,
    this.dashboard = false,
  });
  final PlanDay day;
  final DailyTarget target;
  final bool dashboard;
  @override
  Widget build(BuildContext context) {
    num total(num Function(Meal) read) =>
        day.meals.fold<num>(0, (sum, meal) => sum + read(meal));
    final kcal = total((m) => m.calories),
        protein = total((m) => m.proteinG),
        carbs = total((m) => m.carbsG),
        fat = total((m) => m.fatG);
    final fraction = target.targetCalories > 0
        ? (kcal / target.targetCalories).toDouble()
        : 0.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: dashboard
              ? [const Color(0xFF14532D), AppColors.primary]
              : [const Color(0xFF163D2C), const Color(0xFF163D2C)],
        ),
        boxShadow: dashboard
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .15),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard) ...[
            Text(
              'NĂNG LƯỢNG KẾ HOẠCH HÔM NAY',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                letterSpacing: .7,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                color: Color(0xFF86EFAC),
                size: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: number(kcal),
                    style: AppTextStyles.h2.copyWith(color: Colors.white),
                    children: [
                      TextSpan(
                        text: ' / ${number(target.targetCalories)} kcal',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (dashboard)
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: fraction.clamp(0.0, 1.0),
                          strokeWidth: 5,
                          color: const Color(0xFF86EFAC),
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Text(
                        '${number(fraction * 100)}%',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (dashboard) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 5,
                color: const Color(0xFF86EFAC),
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 16),
          ],
          MacroStrip(
            calories: kcal,
            protein: protein,
            carbs: carbs,
            fat: fat,
            light: true,
          ),
          if (dashboard) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            Text(
              'Mục tiêu: ${number(target.proteinG)}g đạm · ${number(target.carbsG)}g tinh bột · ${number(target.fatG)}g béo',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The API has no photo URL: a neutral meal illustration avoids attributing
/// one of the export's three sample-food photos to unrelated generated meals.
class MealArtwork extends StatelessWidget {
  const MealArtwork({super.key, this.large = false});
  final bool large;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0F5E7), Color(0xFFF0F9F3)],
      ),
    ),
    child: Center(
      child: Container(
        padding: EdgeInsets.all(large ? 25 : 12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: .12),
            width: 4,
          ),
        ),
        child: Icon(
          Icons.restaurant_outlined,
          color: AppColors.primaryDark,
          size: large ? 54 : 28,
        ),
      ),
    ),
  );
}

class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.meal, this.swappable = false});
  final Meal meal;
  final bool swappable;
  @override
  Widget build(BuildContext context) {
    final busy = context.watch<PlanProvider>().busy;
    void detail() =>
        Navigator.pushNamed(context, '/meal_detail', arguments: meal.mealId);
    return Material(
      key: ValueKey(meal.mealId),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: detail,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 84, child: MealArtwork()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealLabel(meal.mealType).toUpperCase(),
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 10,
                          letterSpacing: .6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal.name,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${number(meal.calories)} kcal',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${number(meal.proteinG)}g đạm · ${number(meal.carbsG)}g tinh bột · ${number(meal.fatG)}g béo',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: detail,
                            child: const Text('Xem chi tiết →'),
                          ),
                          if (swappable)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: busy
                                  ? null
                                  : () => openSwap(
                                      context,
                                      meal.mealId,
                                      meal: true,
                                    ),
                              icon: const Icon(Icons.swap_horiz, size: 14),
                              label: const Text('Đổi món'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkoutArtwork extends StatelessWidget {
  const WorkoutArtwork({super.key, this.height = 130});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDBEAFE), Color(0xFFF0FDF4)],
      ),
    ),
    child: Center(
      child: Container(
        width: height * .6,
        height: height * .6,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(
          Icons.fitness_center,
          color: AppColors.carbs,
          size: height * .25,
        ),
      ),
    ),
  );
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    this.selected = false,
  });
  final Exercise exercise;
  final int index;
  final bool selected;
  @override
  Widget build(BuildContext context) => Material(
    key: ValueKey(exercise.exerciseId),
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: selected ? AppColors.carbs : AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/workout_detail',
        arguments: exercise.exerciseId,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ToneIcon(icon: Icons.fitness_center, blue: true, size: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name, style: AppTextStyles.label),
                  const SizedBox(height: 3),
                  Text(
                    muscleLabel(exercise.muscleGroup),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${exercise.sets} hiệp',
                        style: AppTextStyles.bodySmall,
                      ),
                      Text(
                        exercise.repsOrDuration,
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: context.watch<PlanProvider>().busy
                        ? null
                        : () => openSwap(
                            context,
                            exercise.exerciseId,
                            meal: false,
                          ),
                    icon: const Icon(Icons.swap_horiz, size: 14),
                    label: const Text('Đổi bài tập'),
                  ),
                ],
              ),
            ),
            Text(
              index.toString().padLeft(2, '0'),
              style: AppTextStyles.label.copyWith(color: AppColors.border),
            ),
          ],
        ),
      ),
    ),
  );
}

class DayContent extends StatelessWidget {
  const DayContent({
    super.key,
    required this.day,
    required this.target,
    this.showSummary = true,
  });
  final PlanDay day;
  final DailyTarget target;
  final bool showSummary;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showSummary) EnergySummary(day: day, target: target),
      SectionTitle(
        title: 'Ăn uống',
        subtitle: '${day.meals.length} bữa trong kế hoạch',
      ),
      if (day.meals.isEmpty) const Text('Chưa có bữa ăn cho ngày này.'),
      for (final meal in day.meals)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MealCard(meal: meal, swappable: true),
        ),
      SectionTitle(
        title: 'Tập luyện',
        subtitle:
            '${day.workout.durationMinutes} phút · ${day.workout.exercises.length} bài tập',
      ),
      SurfacePanel(
        child: Row(
          children: [
            const ToneIcon(icon: Icons.fitness_center, blue: true),
            const SizedBox(width: 12),
            Expanded(child: Text(day.workout.title, style: AppTextStyles.h4)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (day.workout.exercises.isEmpty)
        const Text('Không có bài tập cho ngày này.'),
      for (final (index, exercise) in day.workout.exercises.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ExerciseCard(exercise: exercise, index: index + 1),
        ),
    ],
  );
}
