import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
