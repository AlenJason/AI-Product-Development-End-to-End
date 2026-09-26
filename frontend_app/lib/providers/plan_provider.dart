import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../models/api/profile.dart';
import '../services/api_client.dart';

// Plan hiện tại và hồ sơ đã tạo ra nó. Cả hai lưu trên máy (shared_preferences; web: localStorage) để mở lại app
// vẫn xem được plan khi không có mạng (NFR-2). Hồ sơ gồm cả `restrictions` — dữ liệu sức khoẻ chỉ nằm trên máy
// người dùng (NFR-7, D4). Đổi món/bài/feedback gửi đúng cặp này lên server (BRD 6.4).
class PlanProvider extends ChangeNotifier {
  PlanProvider({required this._api, required this._prefs}) {
    _restore();
  }

  // Đổi hợp đồng plan theo cách bản cũ không đọc được → tăng số phiên bản của khoá.
  static const planKey = 'smartfit.plan.v1';
  static const profileKey = 'smartfit.profile.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;

  Profile? _profile;
  MealPlan? _plan;
  bool _busy = false;

  Profile? get profile => _profile;
  MealPlan? get plan => _plan;
  bool get hasPlan => _plan != null;
  // Đang chờ server — UI khoá các nút tạo/đổi/feedback.
  bool get busy => _busy;

  // Mọi hàm gọi server: lỗi → ApiException (plan đang có giữ nguyên); đang bận → bỏ qua, không gọi server.
  Future<void> generate(Profile profile) => _run(() async => _save(profile, await _api.generatePlan(profile)));

  Future<void> swapMeal(String mealId) => _run(() async {
        final (profile, plan) = _current();
        await _save(profile, await _api.swapMeal(profile, plan, mealId));
      });

  Future<void> swapExercise(String exerciseId) => _run(() async {
        final (profile, plan) = _current();
        await _save(profile, await _api.swapExercise(profile, plan, exerciseId));
      });

  // null khi đang bận. `safetyWarning` khác null → UI hiện cảnh báo nổi bật (BRD 6.4, dấu hiệu nguy hiểm).
  Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(() async {
        final (profile, plan) = _current();
        final result = await _api.submitFeedback(profile, plan, answers);
        await _save(profile, result.plan);
        return result;
      });

  // Bỏ plan đang có (giữ hồ sơ để điền sẵn form).
  Future<void> clearPlan() async {
    _plan = null;
    notifyListeners();
    await _prefs.remove(planKey);
  }

  Future<T?> _run<T>(Future<T> Function() task) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  (Profile, MealPlan) _current() {
    final profile = _profile;
    final plan = _plan;
    if (profile == null || plan == null) throw StateError('Chưa có plan — gọi generate() trước');
    return (profile, plan);
  }

  Future<void> _save(Profile profile, MealPlan plan) async {
    _profile = profile;
    _plan = plan;
    await _prefs.setString(profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString(planKey, jsonEncode(plan.toJson()));
  }

  // Bản lưu hỏng hoặc của hợp đồng cũ → xoá, không crash. Plan không có hồ sơ đi kèm thì không đổi món/feedback
  // được, nên hồ sơ hỏng kéo theo xoá plan; plan hỏng thì hồ sơ vẫn giữ.
  void _restore() {
    _profile = _read(profileKey, Profile.fromJson);
    _plan = _profile == null ? null : _read(planKey, MealPlan.fromJson);
    if (_profile == null && _prefs.containsKey(planKey)) unawaited(_prefs.remove(planKey));
  }

  T? _read<T>(String key, T Function(Json json) parse) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      return parse(readMap(jsonDecode(text), key));
    } on FormatException {
      unawaited(_prefs.remove(key));
      return null;
    }
  }
}
