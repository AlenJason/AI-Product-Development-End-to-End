import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/api/codes.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});
  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  String _query = '';
  IngredientCategory? _category;
  bool _showHave = false;
  String label(IngredientCategory c) => switch (c) {
    IngredientCategory.protein => 'Đạm',
    IngredientCategory.produce => 'Rau củ quả',
    IngredientCategory.pantry => 'Gạo, bún & gia vị',
  };
  Future<void> _save(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu checklist. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>().plan;
    final grocery = context.watch<GroceryProvider>();
    if (plan == null) return const SafeArea(child: PlanEmpty());
    final total = plan.groceryList.fold<int>(0, (n, g) => n + g.items.length);
    if (total == 0) {
      return const SafeArea(
        child: Center(
          child: NoticePanel(
            message: 'Máy chủ chưa cung cấp nguyên liệu đi chợ.',
          ),
        ),
      );
    }
    final ready = plan.groceryList.fold<int>(
      0,
      (n, g) =>
          n +
          g.items.where((e) {
            final key = GroceryProvider.keyOf(g.category, e);
            return grocery.isBought(key) || grocery.isHave(key);
          }).length,
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          if (grocery.restoreWarning != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoticePanel(message: grocery.restoreWarning!),
            ),
          ScreenHeading(
            title: 'Đi chợ',
            subtitle: 'Nguyên liệu cho kế hoạch ${plan.days.length} ngày',
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF14532D), Color(0xFF15803D)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_basket_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$ready / $total',
                            style: AppTextStyles.h3.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'nguyên liệu đã sẵn sàng',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(ready / total * 100).round()}%',
                      style: AppTextStyles.label.copyWith(
                        color: const Color(0xFF86EFAC),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ready / total,
                    minHeight: 6,
                    color: const Color(0xFF86EFAC),
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Còn ${total - ready} nguyên liệu cần chuẩn bị',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Tìm kiếm và lọc', style: AppTextStyles.bodySmall),
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Tìm nguyên liệu',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả'),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final c in IngredientCategory.values)
                    ChoiceChip(
                      label: Text(label(c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Hiện nguyên liệu đã có sẵn',
              style: AppTextStyles.bodySmall,
            ),
            value: _showHave,
            onChanged: (v) => setState(() => _showHave = v),
          ),
          for (final group in plan.groceryList.where(
            (g) => _category == null || g.category == _category,
          )) ...[
            const SizedBox(height: 12),
            SurfacePanel(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label(group.category),
                          style: AppTextStyles.label,
                        ),
                      ),
                      Text(
                        '${group.items.length} mục',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(),
                  for (final entry in group.items.where(
                    (e) => e.name.toLowerCase().contains(_query),
                  ))
                    if (_showHave ||
                        !grocery.isHave(
                          GroceryProvider.keyOf(group.category, entry),
                        ))
                      Builder(
                        builder: (context) {
                          final key = GroceryProvider.keyOf(
                                group.category,
                                entry,
                              ),
                              have = grocery.isHave(key),
                              bought = grocery.isBought(key);
                          return Container(
                            key: ValueKey(key),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.border),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 34,
                                  child: Checkbox(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    value: bought,
                                    onChanged: have
                                        ? null
                                        : (_) => _save(
                                            () => grocery.toggleBought(key),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.name,
                                        style: AppTextStyles.label.copyWith(
                                          fontSize: 13,
                                          color: bought || have
                                              ? AppColors.faint
                                              : AppColors.ink,
                                          decoration: bought || have
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        entry.quantity,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 72,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    onPressed: () => _save(
                                      () => have
                                          ? grocery.restoreHave(key)
                                          : grocery.markHave(key),
                                    ),
                                    child: Text(
                                      have ? 'Cần mua' : 'Đã có sẵn',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
