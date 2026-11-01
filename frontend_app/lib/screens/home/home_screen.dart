import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/plan_schedule.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/plan_status.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>(), plan = plans.plan;
    if (plan == null) return const SafeArea(child: PlanEmpty());
    final matches = plan.days.where((d) => d.dayNumber == plans.todayNumber);
    final day = matches.isEmpty ? null : matches.first;
    final date = day == null ? null : plans.schedule?.dateOfDay(day.dayNumber);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date == null
                          ? 'KẾ HOẠCH CỦA BẠN'
                          : vietnameseDate(date).toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .6,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Xin chào bạn',
                            style: AppTextStyles.h1.copyWith(fontSize: 26),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.waving_hand_outlined,
                          color: AppColors.fat,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Hôm nay mình cùng tiến một bước nhé.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: ToneIcon(icon: Icons.person_outline, size: 44),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const PlanStatus(),
          if (day == null)
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.threeDayPlan),
              child: const Text('Xem kế hoạch 3 ngày'),
            )
          else ...[
            EnergySummary(day: day, target: plan.dailyTarget, dashboard: true),
            const SizedBox(height: 14),
            PlanNotice(plan: plan),
            SectionTitle(
              title: 'Bữa ăn hôm nay',
              subtitle:
                  '${day.meals.length} bữa · ${number(day.meals.fold<num>(0, (sum, m) => sum + m.calories))} kcal',
              action: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.threeDayPlan),
                child: const Text('Xem kế hoạch'),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final meal in day.meals)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: (constraints.maxWidth * .86)
                              .clamp(240, 320)
                              .toDouble(),
                          child: MealCard(meal: meal),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SectionTitle(title: 'Buổi tập hôm nay'),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  const WorkoutArtwork(),
                  SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.workout.title, style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(
                          '${day.workout.durationMinutes} phút · ${day.workout.exercises.length} bài tập',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (day.workout.exercises.isNotEmpty)
                          GradientButton(
                            label: 'Xem buổi tập',
                            icon: Icons.bolt,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/workout_detail',
                              arguments: day.workout.exercises.first.exerciseId,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, exercise) in day.workout.exercises.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExerciseCard(exercise: exercise, index: index + 1),
              ),
          ],
        ],
      ),
    );
  }
}
