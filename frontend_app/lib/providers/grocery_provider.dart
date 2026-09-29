import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/codes.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import 'plan_provider.dart';

// Trạng thái danh sách đi chợ (BRD FR-3.2): món đã mua, món đã có sẵn trong tủ lạnh (ẩn khỏi danh sách).
// Danh sách do server tính (#7); app chỉ lưu trạng thái hiển thị, theo từng plan — plan mới thì bắt đầu lại.
class GroceryProvider extends ChangeNotifier {
  GroceryProvider({required this._prefs, required this._plans}) {
    _restore();
    _plans.addListener(_onPlanChanged);
  }

  static const stateKey = 'smartfit.grocery.v1';

  final SharedPreferences _prefs;
  final PlanProvider _plans;

  String? _planId;
  final Set<String> _bought = {};
  final Set<String> _have = {};

  // Khoá gồm cả lượng: đổi món làm lượng thay đổi thì dòng đó bỏ tích — cần mua thêm.
  static String keyOf(IngredientCategory category, GroceryEntry entry) =>
      '${category.code}|${entry.name}|${entry.quantity}';

  bool isBought(String key) => _bought.contains(key);
  bool isHave(String key) => _have.contains(key);

  Future<void> toggleBought(String key) =>
      _update(() => _bought.contains(key) ? _bought.remove(key) : _bought.add(key));

  Future<void> markHave(String key) => _update(() {
    _have.add(key);
    _bought.remove(key);
  });

  Future<void> restoreHave(String key) => _update(() => _have.remove(key));

  @override
  void dispose() {
    _plans.removeListener(_onPlanChanged);
    super.dispose();
  }

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    await _prefs.setString(
      stateKey,
      jsonEncode({'plan_id': _planId, 'bought': _bought.toList(), 'have': _have.toList()}),
    );
  }

  void _onPlanChanged() {
    final planId = _plans.plan?.planId;
    if (planId == _planId) return;
    _planId = planId;
    _bought.clear();
    _have.clear();
    notifyListeners();
    unawaited(_prefs.remove(stateKey));
  }

  void _restore() {
    _planId = _plans.plan?.planId;
    final text = _prefs.getString(stateKey);
    if (text == null) return;
    try {
      final json = readMap(jsonDecode(text), stateKey);
      if (json['plan_id'] != _planId) {
        unawaited(_prefs.remove(stateKey));
        return;
      }
      _bought.addAll(readList(json, 'bought', (item) => item is String ? item : throw const FormatException('bought')));
      _have.addAll(readList(json, 'have', (item) => item is String ? item : throw const FormatException('have')));
    } on FormatException {
      _bought.clear();
      _have.clear();
      unawaited(_prefs.remove(stateKey));
    }
  }
}

