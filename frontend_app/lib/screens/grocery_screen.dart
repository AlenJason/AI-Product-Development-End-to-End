import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/meal_plan.dart';
import '../providers/grocery_provider.dart';
import '../providers/plan_provider.dart';
import '../theme/app_colors.dart';

// Danh sách đi chợ 3 ngày (BRD FR-3): dựng từ `grocery_list` server tính (#7); đánh dấu đã mua, ẩn món đã có sẵn
// trong tủ lạnh (FR-3.2). Trạng thái lưu trên máy theo từng plan (`GroceryProvider`).
class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

// Tên nhóm theo BRD FR-3.1.
const groceryCategoryLabels = {
  IngredientCategory.protein: 'Đạm',
  IngredientCategory.produce: 'Rau củ quả',
  IngredientCategory.pantry: 'Gạo, bún & gia vị',
};

const _categoryIcons = {
  IngredientCategory.protein: Icons.set_meal_outlined,
  IngredientCategory.produce: Icons.eco_outlined,
  IngredientCategory.pantry: Icons.rice_bowl_outlined,
};

class _Row {
  const _Row(this.category, this.entry, this.key);

  final IngredientCategory category;
  final GroceryEntry entry;
  final String key;
}

class _GroceryScreenState extends State<GroceryScreen> {
  IngredientCategory? _filter;
  String _query = '';
  bool _showHave = false;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>().plan;
    final grocery = context.watch<GroceryProvider>();
    if (plan == null) return const SizedBox.shrink();

    final rows = [
      for (final group in plan.groceryList)
        for (final entry in group.items) _Row(group.category, entry, GroceryProvider.keyOf(group.category, entry)),
    ];
    final toBuy = rows.where((row) => !grocery.isHave(row.key)).toList();
    final have = rows.where((row) => grocery.isHave(row.key)).toList();
    final bought = toBuy.where((row) => grocery.isBought(row.key)).length;
    final query = _query.trim().toLowerCase();
    final visible = toBuy
        .where((row) => _filter == null || row.category == _filter)
        .where((row) => query.isEmpty || row.entry.name.toLowerCase().contains(query))
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách đi chợ 3 ngày',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$bought/${toBuy.length} đã mua',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: toBuy.isEmpty ? 1 : bought / toBuy.length,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.primaryBright,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (text) => setState(() => _query = text),
            decoration: InputDecoration(
              hintText: 'Tìm nguyên liệu…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Tất cả', null),
                for (final category in IngredientCategory.values)
                  _filterChip(groceryCategoryLabels[category]!, category),
              ],
            ),
          ),
          for (final category in IngredientCategory.values)
            if (visible.any((row) => row.category == category))
              _group(category, visible.where((row) => row.category == category).toList(), grocery),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Không có nguyên liệu nào khớp.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          if (have.isNotEmpty) _haveSection(have, grocery),
        ],
      ),
    );
  }

  Widget _filterChip(String label, IngredientCategory? category) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == category,
      onSelected: (_) => setState(() => _filter = category),
      selectedColor: AppColors.primarySoft,
    ),
  );

  Widget _group(IngredientCategory category, List<_Row> rows, GroceryProvider grocery) {
    final bought = rows.where((row) => grocery.isBought(row.key)).length;
    // Material (không phải Container có màu nền) để các ListTile vẽ được hiệu ứng bấm.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(_categoryIcons[category], color: AppColors.primary),
              title: Text(
                groceryCategoryLabels[category]!.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.heading),
              ),
              trailing: Text('$bought/${rows.length}', style: const TextStyle(color: AppColors.muted)),
            ),
            const Divider(height: 1),
            for (final row in rows)
              CheckboxListTile(
                value: grocery.isBought(row.key),
                onChanged: (_) => grocery.toggleBought(row.key),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primaryBright,
                title: Text(
                  row.entry.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: grocery.isBought(row.key) ? AppColors.faint : AppColors.ink,
                    decoration: grocery.isBought(row.key) ? TextDecoration.lineThrough : null,
                  ),
                ),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.entry.quantity,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                    IconButton(
                      tooltip: 'Đã có sẵn trong tủ lạnh',
                      icon: const Icon(Icons.kitchen_outlined, size: 20),
                      onPressed: () => grocery.markHave(row.key),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _haveSection(List<_Row> have, GroceryProvider grocery) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: AppColors.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.kitchen_outlined, color: AppColors.muted),
            title: Text(
              '${have.length} món đã có sẵn',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _showHave = !_showHave),
              child: Text(_showHave ? 'Ẩn' : 'Hiện lại'),
            ),
          ),
          if (_showHave)
            for (final row in have)
              ListTile(
                dense: true,
                title: Text('${row.entry.name} · ${row.entry.quantity}'),
                trailing: TextButton(onPressed: () => grocery.restoreHave(row.key), child: const Text('Cần mua')),
              ),
        ],
      ),
    ),
  );
}
