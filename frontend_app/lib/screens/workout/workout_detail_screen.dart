import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';

class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key, this.exerciseId});
  final String? exerciseId;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final days = plans.plan?.days.where(
      (d) => d.workout.exercises.any((e) => e.exerciseId == exerciseId),
    );
    final day = days == null || days.isEmpty ? null : days.first;
    final exercise = day?.workout.exercises.firstWhere(
      (e) => e.exerciseId == exerciseId,
    );
    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết bài tập')),
        body: const PlanEmpty(
          message: 'Không tìm thấy bài tập trong kế hoạch hiện tại.',
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GradientButton(
            label: 'Đổi bài',
            icon: Icons.swap_horiz,
            onPressed: plans.busy
                ? null
                : () => openSwap(context, exercise.exerciseId, meal: false),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              const WorkoutArtwork(height: 240),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 16,
                left: 18,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
              ),
              Positioned(
                bottom: 18,
                left: 18,
                right: 18,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      muscleLabel(exercise.muscleGroup).toUpperCase(),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.carbs,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ngày ${day!.dayNumber} · ${day.workout.title}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                SurfacePanel(
                  color: AppColors.panel,
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      _stat(
                        Icons.schedule,
                        '${day.workout.durationMinutes}',
                        'phút / cả buổi',
                      ),
                      _stat(
                        Icons.bolt,
                        '${day.workout.exercises.length}',
                        'bài tập',
                      ),
                      _stat(Icons.repeat, '${exercise.sets}', 'hiệp bài này'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                NoticePanel(
                  message: '${exercise.sets} hiệp · ${exercise.repsOrDuration}',
                  success: true,
                  icon: Icons.fitness_center,
                ),
                const SectionTitle(
                  title: 'Danh sách bài tập',
                  subtitle: 'Các động tác trong buổi tập này',
                ),
                for (final (index, item) in day.workout.exercises.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ExerciseCard(
                      exercise: item,
                      index: index + 1,
                      selected: item.exerciseId == exerciseId,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: AppColors.carbs, size: 19),
      const SizedBox(width: 6),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.label),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
        ],
      ),
    ],
  );
}
