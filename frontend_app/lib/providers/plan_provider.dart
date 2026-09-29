import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../models/api/profile.dart';
import '../models/plan_schedule.dart';
import '../models/profile_rules.dart';
import '../services/api_client.dart';

// Plan hiện tại, hồ sơ đã tạo ra nó và ngày bắt đầu của plan. Lưu trên máy (shared_preferences; web: localStorage)
// để mở lại app vẫn xem được plan khi không có mạng (NFR-2). Hồ sơ gồm cả `restrictions` và
// `pregnantOrBreastfeeding` — dữ liệu sức khoẻ chỉ nằm trên máy người dùng (NFR-7, D4). Đổi món/bài/feedback gửi
// đúng hồ sơ của plan lên server (BRD 6.4) — hồ sơ đang sửa ở tab "Cá nhân" là bản nháp riêng, nên sửa hồ sơ
// không làm các thao tác trên plan cũ bị 409.
class PlanProvider extends ChangeNotifier {
  PlanProvider({required this._api, required this._prefs, DateTime Function()? now}) : _now = now ?? DateTime.now {
    _restore();
  }

  // Đổi hợp đồng theo cách bản cũ không đọc được → tăng số phiên bản của khoá.
  static const planKey = 'smartfit.plan.v1';
  static const profileKey = 'smartfit.profile.v1';
  static const scheduleKey = 'smartfit.plan_schedule.v1';
  static const draftKey = 'smartfit.profile_draft.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  Profile? _profile;
  MealPlan? _plan;
  PlanSchedule? _schedule;
  Profile? _draft;
  bool _busy = false;

  // Hồ sơ đã tạo plan hiện tại.
  Profile? get profile => _profile;
  MealPlan? get plan => _plan;
  PlanSchedule? get schedule => _schedule;
  bool get hasPlan => _plan != null;
  // Đang chờ server — UI khoá các nút tạo/đổi.
  bool get busy => _busy;

  // Hồ sơ đã sửa ở tab "Cá nhân" mà chưa tạo plan mới.
  Profile? get draft => _draft;
  bool get hasPendingProfile => _draft != null;
  // Hồ sơ để điền sẵn form: bản nháp nếu có, không thì hồ sơ của plan.
  Profile? get editableProfile => _draft ?? _profile;

  // Ngày thứ mấy của plan hôm nay (< 1: chưa bắt đầu, > 3: đã hết). null khi chưa có plan.
  int? get todayNumber => _schedule?.dayNumberOn(_now());

  // Mọi hàm gọi server: lỗi → ApiException (plan đang có giữ nguyên); đang bận → bỏ qua, không gọi server.
  // Tạo plan mới: bắt đầu từ hôm nay, bỏ bản nháp (hồ sơ đã được dùng).
  Future<void> generate(Profile profile) => _run(() async {
    final plan = await _api.generatePlan(profile);
    _draft = null;
    await _prefs.remove(draftKey);
    await _save(profile, plan, PlanSchedule.startingOn(plan.planId, _now()));
  });

  Future<void> swapMeal(String mealId) => _run(() async {
    final (profile, plan) = _current();
    await _save(profile, await _api.swapMeal(profile, plan, mealId), _schedule);
  });

  Future<void> swapExercise(String exerciseId) => _run(() async {
    final (profile, plan) = _current();
    await _save(profile, await _api.swapExercise(profile, plan, exerciseId), _schedule);
  });

  // null khi đang bận. `safetyWarning` khác null → UI hiện cảnh báo nổi bật (BRD 6.4, dấu hiệu nguy hiểm).
  // Feedback ngày 3 trả plan mới (`plan_id` khác) — plan đó bắt đầu từ ngày mai.
  Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(() async {
    final (profile, plan) = _current();
    final result = await _api.submitFeedback(profile, plan, answers);
    final schedule = result.plan.planId == plan.planId
        ? _schedule
        : PlanSchedule.startingOn(result.plan.planId, _now().add(const Duration(days: 1)));
    await _save(profile, result.plan, schedule);
    return result;
  });

  // Lưu hồ sơ sửa ở tab "Cá nhân". Giống hồ sơ của plan → không còn gì chờ áp dụng.
  Future<void> saveDraft(Profile edited) async {
    final current = _profile;
    _draft = current != null && edited.sameAs(current) ? null : edited;
    notifyListeners();
    if (_draft == null) {
      await _prefs.remove(draftKey);
    } else {
      await _prefs.setString(draftKey, jsonEncode(edited.toJson()));
    }
  }

  // Bỏ plan đang có (giữ hồ sơ để điền sẵn form).
  Future<void> clearPlan() async {
    _plan = null;
    _schedule = null;
    notifyListeners();
    await _prefs.remove(planKey);
    await _prefs.remove(scheduleKey);
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

  Future<void> _save(Profile profile, MealPlan plan, PlanSchedule? schedule) async {
    _profile = profile;
    _plan = plan;
    _schedule = schedule ?? PlanSchedule.startingOn(plan.planId, _now());
    await _prefs.setString(profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString(planKey, jsonEncode(plan.toJson()));
    await _prefs.setString(scheduleKey, jsonEncode(_schedule!.toJson()));
  }

  // Bản lưu hỏng hoặc của hợp đồng cũ → xoá, không crash. Plan không có hồ sơ đi kèm thì không đổi món/feedback
  // được, nên hồ sơ hỏng kéo theo xoá plan; plan hỏng thì hồ sơ vẫn giữ.
  // Hồ sơ lưu trước v2.6.0 mà nay bị luật mới chặn (dưới 18 tuổi, thiếu cân + Giảm mỡ…): mọi request sẽ trả 400,
  // nên bỏ plan và giữ hồ sơ để người dùng sửa ở Onboarding.
  void _restore() {
    _profile = _read(profileKey, Profile.fromJson);
    _draft = _read(draftKey, Profile.fromJson);
    final profile = _profile;
    _plan = profile == null || profileProblems(profile).isNotEmpty ? null : _read(planKey, MealPlan.fromJson);
    if (_plan == null && _prefs.containsKey(planKey)) unawaited(_prefs.remove(planKey));

    final plan = _plan;
    final schedule = plan == null ? null : _read(scheduleKey, PlanSchedule.fromJson);
    // Plan lưu trước khi có lịch (giai đoạn 5) hoặc lịch của plan khác → coi như bắt đầu hôm nay.
    _schedule = plan == null
        ? null
        : schedule != null && schedule.planId == plan.planId
        ? schedule
        : PlanSchedule.startingOn(plan.planId, _now());
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

