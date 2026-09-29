import '../../models/meal_plan.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import 'workout_swap_sheet.dart';

class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final workout = mockData.todayWorkout;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workout.name, style: AppTextStyles.h1.copyWith(fontSize: 28)),
                  const SizedBox(height: 24),
                  _buildStatsBox(workout),
                  const SizedBox(height: 16),
                  _buildWarningCard(),
                  const SizedBox(height: 32),
                  Text('Danh sách bài tập', style: AppTextStyles.h2),
                  const SizedBox(height: 4),
                  Text('Thực hiện theo thứ tự', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 24),
                  _buildExerciseList(context, workout),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final workout = mockData.todayWorkout;

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: const Color(0xFFE8F2FF),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.ink, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFFE8F2FF)),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.fitness_center, color: Colors.blueAccent, size: 48),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    workout.type,
                    style: AppTextStyles.label.copyWith(
                      color: const Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBox(WorkoutDay workout) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.schedule, '${workout.durationMinutes}', 'phút'),
          _buildStatItem(Icons.flash_on, '${workout.exercisesCount}', 'bài tập'),
          _buildStatItem(Icons.local_fire_department, '~${workout.caloriesBurned}', 'kcal'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String unit) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextStyles.h3.copyWith(fontSize: 16)),
            Text(unit, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bài tập đã tránh động tác gây áp lực mạnh lên đầu gối.',
              style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF1E3A8A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList(BuildContext context, WorkoutDay workout) {
    return Column(
      children: workout.exercises.asMap().entries.map<Widget>((entry) {
        int idx = entry.key + 1;
        var ex = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.fitness_center, color: Colors.blueAccent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(ex.name, style: AppTextStyles.h3)),
                        Text('0$idx', style: AppTextStyles.h3.copyWith(color: AppColors.border)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(ex.muscleGroup, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(ex.sets, style: AppTextStyles.label.copyWith(color: AppColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(ex.reps, style: AppTextStyles.label.copyWith(color: AppColors.ink)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => WorkoutSwapSheet(exerciseId: ex.id),
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: AppColors.primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Đổi bài tập',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

