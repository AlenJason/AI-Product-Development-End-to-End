import 'package:flutter/material.dart';
import '../models/meal_plan.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Tất cả';

  final List<GroceryCategory> _categories = [
    GroceryCategory(
      icon: '🥩',
      title: 'THỊT & THỦY HẢI SẢN',
      items: [
        GroceryItem(name: 'Thịt bò nạc', quantity: '70g', category: 'Thịt & Cá', isChecked: true),
        GroceryItem(name: 'Ức gà', quantity: '450g', category: 'Thịt & Cá', isChecked: false),
        GroceryItem(name: 'Thịt nạc băm', quantity: '120g', category: 'Thịt & Cá', isChecked: false),
        GroceryItem(name: 'Cá trắm', quantity: '400g', category: 'Thịt & Cá', isChecked: true),
      ],
    ),
    GroceryCategory(
      icon: '🥦',
      title: 'RAU CỦ QUẢ',
      items: [
        GroceryItem(name: 'Rau cải ngọt', quantity: '500g', category: 'Rau củ quả', isChecked: false),
        GroceryItem(name: 'Bí đỏ', quantity: '300g', category: 'Rau củ quả', isChecked: false),
        GroceryItem(name: 'Nấm rơm', quantity: '150g', category: 'Rau củ quả', isChecked: true),
        GroceryItem(name: 'Dưa leo', quantity: '200g', category: 'Rau củ quả', isChecked: false),
        GroceryItem(name: 'Cà chua & Hành ngò', quantity: '250g', category: 'Rau củ quả', isChecked: true),
      ],
    ),
    GroceryCategory(
      icon: '🧂',
      title: 'GIA VỊ & NGUYÊN LIỆU KHÁC',
      items: [
        GroceryItem(name: 'Gừng tươi & Tỏi', quantity: '1 túi nhỏ', category: 'Gia vị', isChecked: true),
        GroceryItem(name: 'Nước tương Maggi', quantity: '1 chai nhỏ', category: 'Gia vị', isChecked: false),
        GroceryItem(name: 'Gạo tẻ thơm', quantity: '1 kg', category: 'Gia vị', isChecked: false),
        GroceryItem(name: 'Dầu ăn thực vật', quantity: '1 chai 500ml', category: 'Gia vị', isChecked: false),
      ],
    ),
  ];

  int get _totalItems =>
      _categories.fold(0, (sum, cat) => sum + cat.items.length);

  int get _checkedItems => _categories.fold(
      0, (sum, cat) => sum + cat.items.where((i) => i.isChecked).length);

  void _toggleAll() {
    final allChecked = _checkedItems == _totalItems;
    setState(() {
      for (final cat in _categories) {
        for (final item in cat.items) {
          item.isChecked = !allChecked;
        }
      }
    });
  }

  void _showAddIngredientModal() {
    final textController = TextEditingController();
    final qtyController = TextEditingController();
    String category = 'Thịt & Cá';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thêm nguyên liệu mới',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                decoration: InputDecoration(
                  labelText: 'Tên nguyên liệu (VD: Trứng gà, Tôm sú)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                decoration: InputDecoration(
                  labelText: 'Số lượng / Trọng lượng (VD: 200g, 4 quả)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nhóm nguyên liệu:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Thịt & Cá', 'Rau củ quả', 'Gia vị'].map((cat) {
                  final isSel = category == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    onSelected: (selected) {
                      if (selected) {
                        setModalState(() => category = cat);
                      }
                    },
                    selectedColor: const Color(0xFF00875A),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    final name = textController.text.trim();
                    final qty = qtyController.text.trim().isEmpty ? '1 phần' : qtyController.text.trim();
                    if (name.isNotEmpty) {
                      setState(() {
                        final targetCatIndex = category == 'Thịt & Cá'
                            ? 0
                            : (category == 'Rau củ quả' ? 1 : 2);
                        _categories[targetCatIndex].items.add(
                          GroceryItem(name: name, quantity: qty, category: category, isChecked: false),
                        );
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00875A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Thêm vào danh sách', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalItems == 0 ? 0.0 : _checkedItems / _totalItems;

    // Filter categories based on search and selected pill
    final filteredCategories = _categories.map((cat) {
      final filteredItems = cat.items.where((item) {
        final matchesSearch = _searchQuery.isEmpty ||
            item.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesCategory = _selectedCategory == 'Tất cả' ||
            item.category == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();

      return GroceryCategory(
        icon: cat.icon,
        title: cat.title,
        items: filteredItems,
      );
    }).where((cat) => cat.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section matching Figma
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Danh sách đi chợ 3 ngày',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_checkedItems/$_totalItems đã mua',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00875A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Green progress line
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00875A)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search Bar
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Tìm nguyên liệu...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Tất cả', 'Thịt & Cá', 'Rau củ quả', 'Gia vị'].map((pill) {
                        final isSelected = _selectedCategory == pill;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => setState(() => _selectedCategory = pill),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF00875A) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF00875A) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                pill,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Category list
            Expanded(
              child: filteredCategories.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'Không tìm thấy nguyên liệu "$_searchQuery"',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredCategories.length,
                      itemBuilder: (context, catIndex) {
                        final category = filteredCategories[catIndex];
                        final checkedInCat = category.items.where((i) => i.isChecked).length;
                        final totalInCat = category.items.length;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Category Header
                              Padding(
                                padding: const EdgeInsets.only(left: 14, right: 14, top: 12, bottom: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(category.icon, style: const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Text(
                                          category.title,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '$checkedInCat/$totalInCat',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 0.6, color: Color(0xFFF1F5F9)),
                              // Items with circular checkbox
                              ...category.items.map((item) {
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      item.isChecked = !item.isChecked;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Circular checkbox matching Figma
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: item.isChecked
                                                ? const Color(0xFF00875A)
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: item.isChecked
                                                  ? const Color(0xFF00875A)
                                                  : const Color(0xFFCBD5E1),
                                              width: 1.4,
                                            ),
                                          ),
                                          child: item.isChecked
                                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: item.isChecked
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF1E293B),
                                              decoration: item.isChecked
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.quantity,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Bottom Sticky Action Bar matching Figma
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _toggleAll,
                        icon: const Icon(Icons.check, size: 16, color: Color(0xFF334155)),
                        label: Text(
                          _checkedItems == _totalItems ? 'Bỏ chọn tất cả' : 'Đánh dấu tất cả',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: _showAddIngredientModal,
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text(
                          'Thêm nguyên liệu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00875A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
