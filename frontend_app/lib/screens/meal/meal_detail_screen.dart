import '../../models/meal_plan.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import '../../widgets/common/primary_button.dart';
import 'meal_swap_sheet.dart';

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch MockDataProvider to rebuild if meal changes (e.g., after a swap)
    final mockData = context.watch<MockDataProvider>();
    final meal = mockData.todayBreakfast;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, meal.imageUrl),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMealInfo(meal),
                  const SizedBox(height: 24),
                  _buildMacroBox(meal),
                  const SizedBox(height: 32),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 32),
                  _buildIngredients(meal),
                  const SizedBox(height: 100), // spacing for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: PrimaryButton(
          text: 'Đổi món',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const MealSwapSheet(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String? imageUrl) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.white,
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
            Container(
              color: AppColors.panel,
              child: const Icon(Icons.restaurant, size: 80, color: AppColors.faint), // Fallback image
            ),
            Positioned(
              left: 24,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'AI đề xuất',
                      style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealInfo(MealEntry meal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${meal.type} · 1 TÔ VỪA',
          style: AppTextStyles.label.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(meal.name, style: AppTextStyles.h1.copyWith(fontSize: 28)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${meal.calories}',
              style: AppTextStyles.h1.copyWith(color: AppColors.primary, fontSize: 32),
            ),
            const SizedBox(width: 4),
            Text(
              'kcal',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMacroBox(MealEntry meal) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMacroItem('1.624', 'kcal'),
          _buildMacroDivider(),
          _buildMacroItem('${meal.protein}g', 'Đạm'),
          _buildMacroDivider(),
          _buildMacroItem('${meal.carbs}g', 'Tinh bột'),
          _buildMacroDivider(),
          _buildMacroItem('${meal.fat}g', 'Chất béo'),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h3.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
      ],
    );
  }

  Widget _buildMacroDivider() {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
    );
  }

  Widget _buildIngredients(MealEntry meal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nguyên liệu', style: AppTextStyles.h2),
        const SizedBox(height: 4),
        Text('Khẩu phần cho 1 người', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
        const SizedBox(height: 24),
        ...meal.ingredients.asMap().entries.map((entry) {
          int idx = entry.key + 1;
          var ing = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$idx',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ing.name, style: AppTextStyles.h3.copyWith(fontSize: 16)),
                    ),
                    Text(
                      ing.amount,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
                if (idx != meal.ingredients.length) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.background, height: 1),
                ]
              ],
            ),
          );
        }),
      ],
    );
  }
}



