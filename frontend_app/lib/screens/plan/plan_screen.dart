import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import '../../models/meal_plan.dart';
import '../meal/meal_swap_sheet.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final currentDay = mockData.planDays[mockData.currentDayIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kế hoạch 3 ngày', style: AppTextStyles.h1.copyWith(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      'Được cập nhật theo tiến độ của bạn',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    _buildDayTabs(context, mockData),
                    const SizedBox(height: 24),
                    _buildDailySummaryCard(currentDay),
                    const SizedBox(height: 32),
                    Text('Ăn uống', style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    Text('${currentDay.meals.length} bữa cân bằng', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 16),
                    ...currentDay.meals.map((meal) => _buildMealCard(context, meal)),
                    const SizedBox(height: 32),
                    Text('Tập luyện', style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    Text(currentDay.workout.type, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 16),
                    _buildWorkoutCard(context, currentDay.workout),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTabs(BuildContext context, MockDataProvider mockData) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // AppColors.panel is sometimes too dark
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: mockData.planDays.asMap().entries.map((entry) {
          final isSelected = mockData.currentDayIndex == entry.key;
          final day = entry.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => mockData.setPlanDay(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      day.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isSelected ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailySummaryCard(DayPlan dayPlan) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('1.624', style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 32)),
                  const SizedBox(width: 4),
                  Text('kcal', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroItem('1.624\nkcal', 'kcal'),
              _buildMacroDivider(),
              _buildMacroItem('102g', 'Đạm'),
              _buildMacroDivider(),
              _buildMacroItem('183g', 'Tinh bột'),
              _buildMacroDivider(),
              _buildMacroItem('54g', 'Chất béo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildMacroDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildMealCard(BuildContext context, MealEntry meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
                child: Container(
                  width: 120,
                  height: 120,
                  color: AppColors.panel,
                  child: const Icon(Icons.restaurant, color: AppColors.faint, size: 40),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.type, style: AppTextStyles.label.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(meal.name, style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Text('${meal.calories} kcal', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${meal.protein}g đạm · ${meal.carbs}g tinh bột · ${meal.fat}g béo',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/meal_detail'),
                  child: Row(
                    children: [
                      Text('Xem chi tiết', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, color: AppColors.primary, size: 16),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const MealSwapSheet(),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Text('Đổi món', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(BuildContext context, WorkoutDay workout) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            height: 140,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F2FF),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.fitness_center, size: 48, color: Colors.blueAccent),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.name, style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text('${workout.durationMinutes} phút · ${workout.exercisesCount} bài tập', style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/workout_detail'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: AppColors.primary, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
