import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import '../../widgets/common/primary_button.dart';

class MealSwapSheet extends StatefulWidget {
  const MealSwapSheet({super.key});

  @override
  State<MealSwapSheet> createState() => _MealSwapSheetState();
}

class _MealSwapSheetState extends State<MealSwapSheet> {
  String? _selectedMealId;

  @override
  Widget build(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final currentMeal = mockData.todayBreakfast;
    final alternatives = mockData.getMealAlternatives(currentMeal.id);

    // Default select first alternative if none selected
    _selectedMealId ??= alternatives.isNotEmpty ? alternatives.first.id : null;

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
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đổi món', style: AppTextStyles.h1.copyWith(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        'Món tương đương và phù hợp mục tiêu của bạn.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
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
                      Text('HIỆN TẠI', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 4),
                      Text(currentMeal.name, style: AppTextStyles.h3),
                    ],
                  ),
                  Text('${currentMeal.calories} kcal', style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
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
                  final isSelected = _selectedMealId == alt.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMealId = alt.id),
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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 64,
                              height: 64,
                              color: AppColors.panel,
                              child: const Icon(Icons.restaurant, color: AppColors.faint),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GỢI Ý PHÙ HỢP',
                                  style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(alt.name, style: AppTextStyles.h3),
                                const SizedBox(height: 4),
                                Text(
                                  '${alt.calories} kcal · ${alt.protein}g đạm',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+5%',
                              style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
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
                  const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vẫn nằm trong mục tiêu năng lượng hôm nay.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Chọn món này',
              onPressed: () {
                if (_selectedMealId != null) {
                  context.read<MockDataProvider>().swapMeal(_selectedMealId!);
                  Navigator.pop(context); // Close sheet
                  // Pop again if we want to go home, but mock says "stay on Meal Detail or go back".
                  // The UI reference implies going to Meal Swap Success. But user said: 
                  // "Sau khi xác nhận phải có feedback/navigation hợp lý... Nếu Figma có màn hình Meal Swap Success thì sử dụng"
                  // I'll show a snackbar and keep them on the detail screen for simplicity, or we can just go back to Meal Detail.
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
                  'Giữ món hiện tại',
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

