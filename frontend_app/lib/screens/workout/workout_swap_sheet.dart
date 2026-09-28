import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import '../../widgets/common/primary_button.dart';

class WorkoutSwapSheet extends StatefulWidget {
  final String exerciseId;

  const WorkoutSwapSheet({super.key, required this.exerciseId});

  @override
  State<WorkoutSwapSheet> createState() => _WorkoutSwapSheetState();
}

class _WorkoutSwapSheetState extends State<WorkoutSwapSheet> {
  String? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final workout = mockData.todayWorkout;
    final currentEx = workout.exercises.firstWhere((e) => e.id == widget.exerciseId);
    final alternatives = mockData.getExerciseAlternatives(currentEx.id);

    _selectedExerciseId ??= alternatives.isNotEmpty ? alternatives.first.id : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Đổi bài tập', style: AppTextStyles.h1.copyWith(fontSize: 24)),
            const SizedBox(height: 8),
            Text(
              'Chọn bài nhẹ hơn và phù hợp với hạn chế của bạn.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BÀI HIỆN TẠI', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(currentEx.name, style: AppTextStyles.h3),
                    ],
                  ),
                  Text(
                    '${currentEx.muscleGroup} · Độ khó ${currentEx.difficultyLevel}/3',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -12),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_downward, color: Colors.white, size: 16),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Column(
                children: alternatives.map((alt) {
                  final isSelected = _selectedExerciseId == alt.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedExerciseId = alt.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primarySoft : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.fitness_center, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GỢI Ý AN TOÀN HƠN',
                                  style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(alt.name, style: AppTextStyles.h3),
                                const SizedBox(height: 4),
                                Text(
                                  '${alt.muscleGroup} · Độ khó ${alt.difficultyLevel}/3',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(alt.sets, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                                    const SizedBox(width: 8),
                                    Text(alt.reps, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Không xung đột với hạn chế đau gối đã lưu.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Chọn bài này',
              onPressed: () {
                if (_selectedExerciseId != null) {
                  context.read<MockDataProvider>().swapExercise(widget.exerciseId, _selectedExerciseId!);
                  Navigator.pop(context); // Close sheet
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Huỷ',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

