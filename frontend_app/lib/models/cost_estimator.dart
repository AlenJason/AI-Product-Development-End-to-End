import 'dart:ui';
import 'api/codes.dart';
import 'api/meal_plan.dart';

enum MealCostTier {
  budget(
    code: 'budget',
    label: 'Tiết kiệm',
    rangeLabel: 'Dưới 25.000đ',
    badgeText: 'Tiết kiệm · Dưới 25k',
    color: Color(0xFF15803D),
  ),
  standard(
    code: 'standard',
    label: 'Tiêu chuẩn',
    rangeLabel: '25.000đ – 45.000đ',
    badgeText: 'Tiêu chuẩn · 25k–45k',
    color: Color(0xFF0284C7),
  ),
  premium(
    code: 'premium',
    label: 'Cao cấp',
    rangeLabel: 'Trên 45.000đ',
    badgeText: 'Dinh dưỡng cao · Trên 45k',
    color: Color(0xFFD97706),
  );

  const MealCostTier({
    required this.code,
    required this.label,
    required this.rangeLabel,
    required this.badgeText,
    required this.color,
  });

  final String code;
  final String label;
  final String rangeLabel;
  final String badgeText;
  final Color color;

  static MealCostTier fromCode(String? code) {
    if (code == null) return MealCostTier.standard;
    for (final tier in MealCostTier.values) {
      if (tier.code == code) return tier;
    }
    return MealCostTier.standard;
  }
}

class MealCostEstimate {
  const MealCostEstimate({
    required this.minVnd,
    required this.maxVnd,
    required this.averageVnd,
    required this.tier,
  });

  final int minVnd;
  final int maxVnd;
  final int averageVnd;
  final MealCostTier tier;

  String get formattedApprox => '~${formatVnd(averageVnd)}';
  String get formattedRange => '${formatVnd(minVnd)} – ${formatVnd(maxVnd)}';
}

class GroceryCostEstimate {
  const GroceryCostEstimate({
    required this.totalVnd,
    required this.proteinVnd,
    required this.produceVnd,
    required this.pantryVnd,
    required this.perDayVnd,
  });

  final int totalVnd;
  final int proteinVnd;
  final int produceVnd;
  final int pantryVnd;
  final int perDayVnd;

  String get formattedTotal => '~${formatVnd(totalVnd)}';
  String get formattedPerDay => '~${formatVnd(perDayVnd)} / ngày';
  String get formattedProtein => '~${formatVnd(proteinVnd)}';
  String get formattedProduce => '~${formatVnd(produceVnd)}';
  String get formattedPantry => '~${formatVnd(pantryVnd)}';
}

String formatVnd(num amount) {
  final rounded = ((amount / 1000).round() * 1000).toInt();
  final str = rounded.toString();
  final buffer = StringBuffer();
  final len = str.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(str[i]);
  }
  return '${buffer.toString()}đ';
}

/// Tính toán chi phí ước tính của một món ăn dựa trên nguyên liệu thực tế.
MealCostEstimate estimateMealCost(Meal meal) {
  var calculated = 0;

  for (final ingredient in meal.ingredients) {
    calculated += _estimateIngredientCost(ingredient.name, ingredient.amount, ingredient.unit, ingredient.category);
  }

  // Gia vị và năng lượng chế biến cơ bản: ~2.500đ / món
  calculated += 2500;

  // Nếu món không có nguyên liệu cụ thể, ước tính dựa trên tên và calo
  if (calculated <= 2500) {
    calculated = _estimateFromNameAndCalories(meal.name, meal.calories);
  }

  // Làm tròn tới 1.000đ
  final avg = ((calculated / 1000).round() * 1000).toInt();
  final min = (((avg * 0.9) / 1000).round() * 1000).toInt();
  final max = (((avg * 1.15) / 1000).round() * 1000).toInt();

  final MealCostTier tier;
  if (avg < 25000) {
    tier = MealCostTier.budget;
  } else if (avg <= 45000) {
    tier = MealCostTier.standard;
  } else {
    tier = MealCostTier.premium;
  }

  return MealCostEstimate(
    minVnd: min,
    maxVnd: max,
    averageVnd: avg,
    tier: tier,
  );
}

/// Tính toán tổng dự toán mua sắm cho toàn bộ danh sách đi chợ.
GroceryCostEstimate estimateGroceryCost(List<GroceryGroup> groups) {
  var proteinTotal = 0;
  var produceTotal = 0;
  var pantryTotal = 0;

  for (final group in groups) {
    for (final item in group.items) {
      final (amount, unit) = _parseQuantity(item.quantity);
      final cost = _estimateIngredientCost(item.name, amount, unit, group.category);
      switch (group.category) {
        case IngredientCategory.protein:
          proteinTotal += cost;
          break;
        case IngredientCategory.produce:
          produceTotal += cost;
          break;
        case IngredientCategory.pantry:
          pantryTotal += cost;
          break;
      }
    }
  }

  // Dự phòng gia vị vặt và hao hụt mua sắm: ~15.000đ cho cả đợt
  pantryTotal += 15000;

  final total = proteinTotal + produceTotal + pantryTotal;
  final perDay = (total / 3).round();

  return GroceryCostEstimate(
    totalVnd: total,
    proteinVnd: proteinTotal,
    produceVnd: produceTotal,
    pantryVnd: pantryTotal,
    perDayVnd: perDay,
  );
}

int _estimateIngredientCost(String name, num amount, IngredientUnit unit, IngredientCategory category) {
  final lower = name.toLowerCase();

  // Đổi đơn vị sang gram hoặc quả để tính chuẩn
  var grams = switch (unit) {
    IngredientUnit.g => amount.toDouble(),
    IngredientUnit.ml => amount.toDouble(),
    IngredientUnit.piece => amount.toDouble() * 50, // quả trứng ~50g
    IngredientUnit.tbsp => amount.toDouble() * 15,
    IngredientUnit.tsp => amount.toDouble() * 5,
  };

  if (category == IngredientCategory.protein) {
    // Trứng
    if (lower.contains('trứng')) {
      if (unit == IngredientUnit.piece) {
        return (amount * 3500).toInt();
      }
      return (grams * 70).toInt();
    }
    // Thịt bò
    if (lower.contains('bò')) {
      return (grams * 260).toInt(); // 260k/kg
    }
    // Tôm, hải sản cao cấp
    if (lower.contains('tôm') || lower.contains('mực') || lower.contains('bạch tuộc')) {
      return (grams * 230).toInt(); // 230k/kg
    }
    // Cá hồi
    if (lower.contains('hồi')) {
      return (grams * 380).toInt();
    }
    // Thịt heo / lợn
    if (lower.contains('heo') || lower.contains('lợn') || lower.contains('thịt nạc') || lower.contains('thịt xay')) {
      return (grams * 140).toInt(); // 140k/kg
    }
    // Đậu phụ / tàu hũ
    if (lower.contains('đậu') || lower.contains('tàu hũ')) {
      return (grams * 35).toInt(); // 35k/kg
    }
    // Gà / ức gà
    if (lower.contains('gà')) {
      return (grams * 90).toInt(); // 90k/kg
    }
    // Cá thông thường (cá basa, cá nục, cá diêu hồng)
    if (lower.contains('cá')) {
      return (grams * 110).toInt(); // 110k/kg
    }
    // Đạm chung
    return (grams * 120).toInt();
  }

  if (category == IngredientCategory.produce) {
    // Nấm, măng tây, bông cải, ớt chuông
    if (lower.contains('nấm') || lower.contains('măng tây') || lower.contains('bông cải') || lower.contains('ớt chuông')) {
      return (grams * 75).toInt();
    }
    // Trái cây (chuối, táo, ổi)
    if (lower.contains('chuối') || lower.contains('táo') || lower.contains('ổi') || lower.contains('bơ')) {
      return (grams * 40).toInt();
    }
    // Rau củ phổ biến: rau muống, cải, dưa leo, cà chua, cà rốt, bắp cải
    return (grams * 35).toInt();
  }

  // Pantry
  if (lower.contains('bánh mì')) {
    return (amount * 5000).toInt();
  }
  if (lower.contains('gạo lứt') || lower.contains('yến mạch')) {
    return (grams * 40).toInt();
  }
  if (lower.contains('bột gạo') || lower.contains('bột chiên')) {
    return (grams * 35).toInt();
  }
  if (lower.contains('bún') || lower.contains('phở')) {
    return (grams * 25).toInt();
  }
  if (lower.contains('miến')) {
    return (grams * 60).toInt();
  }
  // Gạo trắng, dầu hào, hành tỏi gia vị
  return (grams * 25).toInt();
}

int _estimateFromNameAndCalories(String name, num calories) {
  final lower = name.toLowerCase();
  if (lower.contains('bò') || lower.contains('hải sản') || lower.contains('hồi')) {
    return 48000;
  }
  if (lower.contains('trứng') || lower.contains('đậu phụ') || lower.contains('bánh mì')) {
    return 20000;
  }
  if (lower.contains('tôm') || lower.contains('thịt kho') || lower.contains('gà')) {
    return 32000;
  }
  // Calorie-based approximation
  return (calories * 60).clamp(18000, 55000).toInt();
}

(num, IngredientUnit) _parseQuantity(String quantity) {
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-zA-ZÀ-ỹ]+)?').firstMatch(quantity.trim());
  if (match == null) return (100, IngredientUnit.g);
  final numVal = num.tryParse(match.group(1) ?? '100') ?? 100;
  final unitStr = (match.group(2) ?? 'g').toLowerCase();
  final unit = switch (unitStr) {
    'g' => IngredientUnit.g,
    'ml' => IngredientUnit.ml,
    'quả' || 'trứng' || 'cái' || 'miếng' => IngredientUnit.piece,
    'tbsp' => IngredientUnit.tbsp,
    'tsp' => IngredientUnit.tsp,
    _ => IngredientUnit.g,
  };
  return (numVal, unit);
}
