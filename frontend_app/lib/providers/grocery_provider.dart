import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/codes.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import 'plan_provider.dart';

class GroceryProvider extends ChangeNotifier {
  GroceryProvider({required this._prefs, required this._plans}) {
    _restore();
    _plans.addListener(_onPlanChanged);
  }
  static const stateKey = 'smartfit.grocery.v1';
  final SharedPreferences _prefs;
  final PlanProvider _plans;
  String? _planId;
  Set<String> _bought = {}, _have = {};
  final Map<String, Json> _history = {};
  Json? checklistFor(String planId) => _history[planId];
  Future<void> _pending = Future.value();
  bool _disposed = false;
  String? restoreWarning;
  String? _recoverySource, _recoveryKey;
  static String keyOf(IngredientCategory category, GroceryEntry entry) =>
      '${category.code}|${entry.name}|${entry.quantity}';
  bool isBought(String key) => _bought.contains(key);
  bool isHave(String key) => _have.contains(key);
  Future<void> toggleBought(String key) =>
      _update((b, h) => b.contains(key) ? b.remove(key) : b.add(key));
  Future<void> markHave(String key) => _update((b, h) {
    h.add(key);
    b.remove(key);
  });
  Future<void> restoreHave(String key) => _update((b, h) => h.remove(key));
  Set<String> get _keys => {
    for (final group in _plans.plan?.groceryList ?? <GroceryGroup>[])
      for (final entry in group.items) keyOf(group.category, entry),
  };
  Future<void> _queue(Future<void> Function() task) {
    final next = _pending.then((_) => task());
    _pending = next.catchError((Object _) {});
    return next;
  }

  Future<void> _update(void Function(Set<String>, Set<String>) change) {
    final planId = _planId;
    return _queue(() async {
      if (planId == null || planId != _planId) return;
      final bought = {..._bought}, have = {..._have};
      change(bought, have);
      final text = jsonEncode({
        'plan_id': planId,
        'bought': bought.toList(),
        'have': have.toList(),
        'history': _history,
      });
      try {
        await _backupRecovery();
        if (!await _prefs.setString(stateKey, text)) {
          throw StateError('Không thể lưu checklist');
        }
      } catch (_) {
        try {
          await _prefs.reload();
        } catch (_) {}
        rethrow;
      }
      if (_disposed || planId != _planId) return;
      _bought = bought;
      _have = have;
      _recoverySource = null;
      _recoveryKey = null;
      restoreWarning = null;
      notifyListeners();
    });
  }

  void _onPlanChanged() {
    final id = _plans.plan?.planId;
    if (id != _planId) {
      if (_planId != null) {
        _history[_planId!] = {
          'bought': _bought.toList(),
          'have': _have.toList(),
        };
      }
      _planId = id;
      _bought = _storedSet(_history[id], 'bought').intersection(_keys);
      _have = _storedSet(_history[id], 'have').intersection(_keys);
      notifyListeners();
      unawaited(
        _queue(() async {
          if (id != _planId) return;
          await _backupRecovery();
          if (!await _prefs.setString(
            stateKey,
            jsonEncode({
              'plan_id': id,
              'bought': _bought.toList(),
              'have': _have.toList(),
              'history': _history,
            }),
          )) {
            throw StateError('Không thể lưu checklist');
          }
          _recoverySource = null;
          _recoveryKey = null;
        }).catchError((Object _) {
          restoreWarning = 'Không thể lưu thay đổi checklist.';
          if (!_disposed) notifyListeners();
        }),
      );
      return;
    }
    final keys = _keys;
    if (_bought.every(keys.contains) && _have.every(keys.contains)) return;
    unawaited(
      _update((b, h) {
        b.removeWhere((k) => !keys.contains(k));
        h.removeWhere((k) => !keys.contains(k));
      }).catchError((Object _) {
        restoreWarning = 'Không thể lưu thay đổi checklist.';
        if (!_disposed) notifyListeners();
      }),
    );
  }

  void _restore() {
    _planId = _plans.plan?.planId;
    try {
      final text = _prefs.getString(stateKey);
      if (text == null) return;
      final json = readMap(jsonDecode(text), stateKey);
      if (json['history'] != null) {
        try {
          for (final entry in readMap(json['history'], 'history').entries) {
            try {
              _history[entry.key] = _readChecklist(
                readMap(entry.value, 'checklist'),
              );
            } on FormatException {
              _warn();
            } on TypeError {
              _warn();
            }
          }
        } on FormatException {
          _warn();
        } on TypeError {
          _warn();
        }
      }
      if (json['plan_id'] is String) {
        _history[json['plan_id'] as String] = _readChecklist(json);
      }
      if (_history.containsKey(_planId)) {
        _bought = _storedSet(_history[_planId], 'bought').intersection(_keys);
        _have = _storedSet(_history[_planId], 'have').intersection(_keys);
      }
    } on FormatException {
      _warn();
    } on TypeError {
      _warn();
    }
  }

  Json _readChecklist(Json json) {
    List<String> values(String key) {
      try {
        return _storedSet(json, key).toList();
      } on FormatException {
        _warn();
        return [];
      } on TypeError {
        _warn();
        return [];
      }
    }

    return {'bought': values('bought'), 'have': values('have')};
  }

  void _warn() {
    try {
      _recoverySource ??= _prefs.getString(stateKey);
    } on TypeError {
      /* Keep original non-string preference untouched. */
    }
    restoreWarning = 'Một phần checklist không đọc được. Các phần hợp lệ được khôi phục; bản lưu gốc được giữ nguyên.';
  }

  Future<void> _backupRecovery() async {
    if (_recoverySource == null) return;
    _recoveryKey ??=
        '$stateKey.recovery.${DateTime.now().microsecondsSinceEpoch}';
    final existing = _prefs.getString(_recoveryKey!);
    try {
      if (existing != _recoverySource &&
          (existing != null ||
              !await _prefs.setString(_recoveryKey!, _recoverySource!))) {
        throw StateError('Không thể bảo toàn checklist cần khôi phục');
      }
    } catch (_) {
      try {
        await _prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }

  static Set<String> _storedSet(Json? json, String key) => json == null
      ? {}
      : readList(
          json,
          key,
          (v) => v is String ? v : throw const FormatException(),
        ).toSet();

  @override
  void dispose() {
    _disposed = true;
    _plans.removeListener(_onPlanChanged);
    super.dispose();
  }
}
