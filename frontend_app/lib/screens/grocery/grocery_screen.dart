import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/mock_data_provider.dart';
import '../../models/meal_plan.dart';

class GroceryScreen extends StatelessWidget {
  const GroceryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mockData = context.watch<MockDataProvider>();
    final categories = mockData.groceryCategories;

    int totalItems = 0;
    int checkedItems = 0;
    for (var cat in categories) {
      for (var item in cat.items) {
        totalItems++;
        if (item.isChecked) checkedItems++;
      }
    }

    final double progress = totalItems > 0 ? checkedItems / totalItems : 0;
    final int remaining = totalItems - checkedItems;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Đi chợ', style: AppTextStyles.h1.copyWith(fontSize: 28)),
                            const SizedBox(height: 8),
                            Text('Nguyên liệu cho kế hoạch 3 ngày', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
                          ],
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, color: AppColors.ink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCard(checkedItems, totalItems, remaining, progress),
                    const SizedBox(height: 24),
                    ...categories.map((cat) => _buildCategoryCard(context, mockData, cat)),
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

  Widget _buildSummaryCard(int checkedItems, int totalItems, int remaining, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF166534), // Darker green as per Figma
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.shopping_basket_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$checkedItems / $totalItems',
                        style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 24),
                      ),
                      Text(
                        'nguyên liệu đã có',
                        style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF86EFAC)), // Light green progress
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Còn $remaining món cần chuẩn bị',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, MockDataProvider mockData, GroceryCategoryModel category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category.name, style: AppTextStyles.h3),
                Text(
                  '${category.items.length} món',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...category.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: GestureDetector(
                    onTap: () => mockData.toggleGroceryItem(item.id),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: item.isChecked ? const Color(0xFF22C55E) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: item.isChecked ? const Color(0xFF22C55E) : AppColors.faint,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: item.isChecked
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 16,
                      color: item.isChecked ? AppColors.muted : AppColors.ink,
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(
                    item.amount,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                  ),
                  trailing: const Icon(Icons.more_horiz, color: AppColors.faint),
                ),
                if (idx < category.items.length - 1)
                  const Divider(height: 1, indent: 60, color: AppColors.border),
              ],
            );
          }),
        ],
      ),
    );
  }
}
