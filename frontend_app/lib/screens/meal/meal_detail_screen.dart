import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/recipe_guide.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';

class MealDetailScreen extends StatelessWidget {
  const MealDetailScreen({super.key, this.mealId});
  final String? mealId;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final matches = plans.plan?.days
        .expand((d) => d.meals)
        .where((m) => m.mealId == mealId);
    final meal = matches == null || matches.isEmpty ? null : matches.first;
    if (meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết món ăn')),
        body: const PlanEmpty(
          message: 'Không tìm thấy món ăn trong kế hoạch hiện tại.',
        ),
      );
    }
    final recipe = RecipeGuide.forMeal(meal);
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: GradientButton(
            label: 'Đổi món',
            icon: Icons.swap_horiz,
            onPressed: plans.busy
                ? null
                : () => openSwap(context, meal.mealId, meal: true),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              const SizedBox(height: 270, child: MealArtwork(large: true)),
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'THỰC ĐƠN CỦA BẠN',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mealLabel(meal.mealType).toUpperCase()} · ${meal.portion}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(meal.name, style: AppTextStyles.h1.copyWith(fontSize: 26)),
                const SizedBox(height: 12),
                Text(
                  '${number(meal.calories)} kcal',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 18),
                SurfacePanel(
                  color: AppColors.panel,
                  child: MacroStrip(
                    calories: meal.calories,
                    protein: meal.proteinG,
                    carbs: meal.carbsG,
                    fat: meal.fatG,
                  ),
                ),
                const SectionTitle(
                  title: 'Nguyên liệu',
                  subtitle: 'Định lượng theo khẩu phần của món',
                ),
                if (meal.ingredients.isEmpty)
                  const NoticePanel(
                    message: 'Máy chủ chưa cung cấp nguyên liệu.',
                  ),
                for (final (index, ingredient) in meal.ingredients.indexed)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ingredient.name,
                            style: AppTextStyles.label,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '${number(ingredient.amount)} ${unitLabel(ingredient.unit)}',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SectionTitle(
                  title: 'Hướng dẫn chế biến',
                  subtitle: 'Cách nấu nhanh gọn và giữ chuẩn dinh dưỡng',
                ),
                SurfacePanel(
                  color: AppColors.panel,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: AppColors.primaryDark,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Chuẩn bị: ~${recipe.prepMinutes}p',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_outlined,
                            size: 16,
                            color: AppColors.fat,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Nấu: ~${recipe.cookMinutes}p',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.restaurant_menu,
                              size: 13,
                              color: AppColors.primaryDark,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Độ khó: ${recipe.difficulty}',
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final step in recipe.steps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SurfacePanel(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${step.stepNumber}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment:
                                      WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      step.title,
                                      style: AppTextStyles.label.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.panel,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '⏱ ${step.duration}',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  step.instruction,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.ink.withValues(alpha: .88),
                                    height: 1.5,
                                  ),
                                ),
                                if (step.tip != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.primary.withValues(
                                          alpha: .22,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.tips_and_updates_outlined,
                                          size: 15,
                                          color: AppColors.primaryDark,
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Text(
                                            step.tip!,
                                            style: AppTextStyles.bodySmall
                                                .copyWith(
                                                  color: AppColors.primaryDark,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (recipe.cookingTip.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  NoticePanel(
                    message: 'Mẹo nấu ngon: ${recipe.cookingTip}',
                    icon: Icons.lightbulb_outline,
                    success: true,
                  ),
                ],
                if (recipe.nutritionNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NoticePanel(
                    message: 'Lưu ý dinh dưỡng: ${recipe.nutritionNote}',
                    icon: Icons.health_and_safety_outlined,
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Hình minh họa chung · Chưa có ảnh món ăn từ máy chủ.',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
