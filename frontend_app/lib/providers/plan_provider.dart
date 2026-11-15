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
import '../models/feedback_state.dart';
import '../services/api_exception.dart';
import '../services/api_client.dart';

class PlanProvider extends ChangeNotifier {
  PlanProvider({
    required this._api,
    required SharedPreferences prefs,
    DateTime Function()? now,
    Future<bool> Function(String, String)? write,
  }) : _prefs = prefs,
       _now = now ?? DateTime.now,
       _write = write ?? prefs.setString {
    _restore();
  }

  // V2 is the authoritative, single-key commit. V1 keys remain readable and are
  // mirrored for compatibility, but a partial mirror cannot replace V2 state.
  static const stateKey = 'smartfit.plan_state.v2';
  static const planKey = 'smartfit.plan.v1';
  static const profileKey = 'smartfit.profile.v1';
  static const scheduleKey = 'smartfit.plan_schedule.v1';
  static const draftKey = 'smartfit.profile_draft.v1';
  final ApiClient _api;
  final SharedPreferences _prefs;
  final DateTime Function() _now;
  final Future<bool> Function(String, String) _write;
  Profile? _profile, _draft;
  MealPlan? _plan;
  PlanSchedule? _schedule;
  bool _busy = false, _needsMigration = false;
  int? _notifiedDay;
  String? _restoreWarning;
  String? _recoverySource, _recoveryKey;
  Map<String, LocalFeedbackReceipt> _feedback = {};
  PendingFeedback? _pendingFeedback;
  PlanCycle? _nextCycle;
  List<PlanCycle> _history = [];
  bool _activating = false;
  PendingFeedback? get pendingFeedback => _pendingFeedback;
  PlanCycle? get nextCycle => _nextCycle;
  List<PlanCycle> get history => List.unmodifiable(_history);
  LocalFeedbackReceipt? feedbackFor(String planId, int day) =>
      _feedback['$planId:$day'];
  bool hasFeedback(int day) =>
      _plan != null && feedbackFor(_plan!.planId, day) != null;
  String? get currentSafetyWarning => _plan == null || todayNumber == null
      ? null
      : feedbackFor(_plan!.planId, todayNumber!)?.safetyWarning;
  bool get nextCycleDue =>
      _nextCycle != null && _nextCycle!.schedule.dayNumberOn(_now()) >= 1;
  Profile? get profile => _profile;
  Profile? get draft => _draft;
  MealPlan? get plan => _plan;
  PlanSchedule? get schedule => _schedule;
  bool get hasPlan => _plan != null;
  bool get busy => _busy || _activating;
  bool get hasPendingProfile => _draft != null;
  Profile? get editableProfile => _draft ?? _profile;
  String? get restoreWarning => _restoreWarning;
  int? get todayNumber => _schedule?.dayNumberOn(_now());

  void refreshDay() {
    unawaited(activateScheduledCycle());
    if (_notifiedDay == todayNumber) return;
    _notifiedDay = todayNumber;
    notifyListeners();
  }

  Duration get untilNextDay {
    final now = _now();
    final next = now.isUtc
        ? DateTime.utc(now.year, now.month, now.day + 1)
        : DateTime(now.year, now.month, now.day + 1);
    return next.difference(now);
  }

  // Only a completely readable legacy record is migrated. Read errors do not
  // delete or overwrite any stored value, including a recoverable valid plan.
  Future<void> finishRestore() async {
    try {
      if (_needsMigration) {
        await _commit(
          profile: _profile,
          plan: _plan,
          schedule: _schedule,
          draft: _draft,
        );
      }
      await activateScheduledCycle();
    } catch (_) {
      _restoreWarning = 'Không thể hoàn tất lưu dữ liệu. Kế hoạch đang có vẫn được giữ nguyên.';
    }
  }

  Future<void> generate(Profile profile) => _run(() async {
    _requireMutable();
    _validateProfile(profile);
    final plan = await _api.generatePlan(profile);
    _validatePlan(plan);
    await _commit(
      profile: profile,
      plan: plan,
      schedule: PlanSchedule.startingOn(plan.planId, _now()),
      draft: null,
      history: _archivedCurrent(),
    );
  });
  Future<void> swapMeal(String mealId) => _run(() async {
    _requireMutable();
    final (profile, plan) = _current();
    final changed = await _api.swapMeal(profile, plan, mealId);
    _validatePlan(changed);
    await _commit(
      profile: profile,
      plan: changed,
      schedule: _schedule,
      draft: _draft,
    );
  });
  Future<void> swapExercise(String exerciseId) => _run(() async {
    _requireMutable();
    final (profile, plan) = _current();
    final changed = await _api.swapExercise(profile, plan, exerciseId);
    _validatePlan(changed);
    await _commit(
      profile: profile,
      plan: changed,
      schedule: _schedule,
      draft: _draft,
    );
  });
  Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(
    () async {
      if (_pendingFeedback == null) {
        final (profile, plan) = _current();
        if (answers.dayNumber != todayNumber ||
            hasFeedback(answers.dayNumber) ||
            _nextCycle != null) {
          throw StateError('Ngày này không thể gửi thêm phản hồi.');
        }
        if (answers.dayNumber < 1 ||
            answers.dayNumber > 3 ||
            answers.bodyStates.isEmpty) {
          throw const FormatException('Phản hồi không hợp lệ');
        }
        final pending = PendingFeedback(
          PlanCycle(profile, plan, _schedule!),
          answers,
        );
        await _commit(
          profile: profile,
          plan: plan,
          schedule: _schedule,
          draft: _draft,
          pending: pending,
        );
      } else if (jsonEncode(_pendingFeedback!.answers.toJson()) !=
          jsonEncode(answers.toJson())) {
        throw StateError(
          'Có phản hồi đang chờ. Hãy thử lại đúng nội dung đã gửi.',
        );
      }
      final pending = _pendingFeedback!, cycle = pending.cycle;
      FeedbackResult result;
      try {
        result = await _api.submitFeedback(
          cycle.profile,
          cycle.plan,
          pending.answers,
        );
      } on ValidationException {
        await _clearPending();
        rethrow;
      } on NoReplacementException {
        await _clearPending();
        rethrow;
      }
      _validatePlan(result.plan);
      final day = pending.answers.dayNumber;
      if (day < 3) {
        if (result.plan.planId != cycle.plan.planId) {
          throw const FormatException('Sai chu kỳ phản hồi');
        }
        for (var i = 0; i < 3; i++) {
          if (i != day &&
              jsonEncode(cycle.plan.days[i].toJson()) !=
                  jsonEncode(result.plan.days[i].toJson())) {
            throw const FormatException('Máy chủ thay đổi ngày ngoài phạm vi');
          }
        }
      } else if (result.plan.planId == cycle.plan.planId) {
        throw const FormatException('Chưa có chu kỳ mới');
      }
      final nextStart = day == 3 ? cycle.schedule.dateOfDay(4) : null;
      final changed =
          day == 3 ||
          jsonEncode(cycle.plan.days[day].toJson()) !=
              jsonEncode(result.plan.days[day].toJson());
      final receipt = LocalFeedbackReceipt(
        planId: cycle.plan.planId,
        answers: pending.answers,
        savedAt: _now(),
        changed: changed,
        safetyWarning: result.safetyWarning,
        nextStart: nextStart,
      );
      final receipts = {..._feedback, receipt.key: receipt};
      await _commit(
        profile: cycle.profile,
        plan: day == 3 ? cycle.plan : result.plan,
        schedule: cycle.schedule,
        draft: _draft,
        feedback: receipts,
        clearPending: true,
        next: day == 3
            ? PlanCycle(
                cycle.profile,
                result.plan,
                PlanSchedule.startingOn(result.plan.planId, nextStart!),
              )
            : null,
        history: day == 3 ? _archivedCurrent() : null,
      );
      return result;
    },
  );
  Future<FeedbackResult?> retryFeedback() {
    final pending = _pendingFeedback;
    if (pending == null) return Future.value(null);
    return submitFeedback(pending.answers);
  }

  Future<void> _clearPending() => _commit(
    profile: _profile,
    plan: _plan,
    schedule: _schedule,
    draft: _draft,
    clearPending: true,
  );
  List<PlanCycle> _archivedCurrent() =>
      _plan == null ||
          _profile == null ||
          _schedule == null ||
          _history.any((c) => c.plan.planId == _plan!.planId)
      ? _history
      : [..._history, PlanCycle(_profile!, _plan!, _schedule!)];
  void _requireMutable() {
    if (_pendingFeedback != null) {
      throw StateError(
        'Phản hồi đang chờ kết quả. Hãy thử lại phản hồi trước khi thay kế hoạch.',
      );
    }
    if (_nextCycle != null) {
      throw StateError('Chu kỳ kế tiếp đã sẵn sàng và sẽ mở vào ngày bắt đầu.');
    }
  }

  Future<void> activateScheduledCycle() async {
    if (_busy || _activating || _pendingFeedback != null || !nextCycleDue) {
      return;
    }
    _activating = true;
    notifyListeners();
    try {
      final next = _nextCycle!;
      await _commit(
        profile: next.profile,
        plan: next.plan,
        schedule: next.schedule,
        draft: _draft,
        clearNext: true,
      );
    } catch (_) {
      _restoreWarning = 'Chưa lưu được chuyển chu kỳ. Dữ liệu cũ được giữ; hãy mở lại hoặc thử lại.';
    } finally {
      _activating = false;
      notifyListeners();
    }
  }

  Future<void> saveDraft(Profile edited) => _run(() async {
    _validateProfile(edited);
    await _commit(
      profile: _profile,
      plan: _plan,
      schedule: _schedule,
      draft: _profile != null && edited.sameAs(_profile!) ? null : edited,
    );
  });
  Future<void> clearPlan() => _run(() async {
    _requireMutable();
    await _commit(profile: _profile, plan: null, schedule: null, draft: _draft);
  });
  Future<T?> _run<T>(Future<T> Function() task) async {
    if (_busy || _activating) return null;
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      notifyListeners();
      await activateScheduledCycle();
    }
  }

  (Profile, MealPlan) _current() {
    if (_profile == null || _plan == null) throw StateError('Chưa có kế hoạch');
    return (_profile!, _plan!);
  }

  static void _validateProfile(Profile profile) {
    final errors = profileProblems(profile);
    if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
  }

  static void _validatePlan(MealPlan plan) {
    if (plan.planId.isEmpty ||
        plan.days.length != 3 ||
        plan.days.map((d) => d.dayNumber).toSet().length != 3 ||
        plan.days.any(
          (d) =>
              d.dayNumber < 1 ||
              d.dayNumber > 3 ||
              d.meals.length != 3 ||
              d.meals.map((m) => m.mealType).toSet().length != 3,
        ) ||
        plan.days
            .expand((d) => d.meals)
            .any(
              (m) =>
                  m.mealId.isEmpty || !m.calories.isFinite || m.calories <= 0,
            ) ||
        plan.days.expand((d) => d.meals).map((m) => m.mealId).toSet().length !=
            9 ||
        !plan.dailyTarget.targetCalories.isFinite ||
        plan.dailyTarget.targetCalories <= 0) {
      throw const FormatException('Kế hoạch lưu không tương thích');
    }
  }

  Future<void> _commit({
    required Profile? profile,
    required MealPlan? plan,
    required PlanSchedule? schedule,
    required Profile? draft,
    Map<String, LocalFeedbackReceipt>? feedback,
    PendingFeedback? pending,
    bool clearPending = false,
    PlanCycle? next,
    bool clearNext = false,
    List<PlanCycle>? history,
  }) async {
    final actualSchedule = plan == null
        ? null
        : schedule == null
        ? PlanSchedule.startingOn(plan.planId, _now())
        : PlanSchedule(planId: plan.planId, startDate: schedule.startDate);
    final text = jsonEncode({
      'version': 2,
      'profile': profile?.toJson(),
      'plan': plan?.toJson(),
      'schedule': actualSchedule?.toJson(),
      'draft': draft?.toJson(),
      'feedback_receipts': (feedback ?? _feedback).map(
        (k, v) => MapEntry(k, v.toJson()),
      ),
      'feedback_pending': (clearPending ? null : pending ?? _pendingFeedback)
          ?.toJson(),
      'next_cycle': (clearNext ? null : next ?? _nextCycle)?.toJson(),
      'history': (history ?? _history).map((c) => c.toJson()).toList(),
    });
    try {
      // Recovery is read-only until an explicit save/lifecycle commit. Keep the
      // exact damaged snapshot separately before replacing it with recovered data.
      if (_recoverySource != null) {
        _recoveryKey ??=
            '$stateKey.recovery.${DateTime.now().microsecondsSinceEpoch}';
        final existing = _prefs.getString(_recoveryKey!);
        if (existing != _recoverySource &&
            (existing != null ||
                !await _write(_recoveryKey!, _recoverySource!))) {
          throw StateError('Không thể bảo toàn bản lưu cần khôi phục');
        }
      }
      if (!await _write(stateKey, text)) {
        throw StateError('Không thể lưu kế hoạch');
      }
    } catch (_) {
      // SharedPreferences can update its cache before a platform write fails.
      // Reload that cache from disk; never try to overwrite a valid disk copy.
      try {
        await _prefs.reload();
      } catch (_) {}
      rethrow;
    }
    _profile = profile;
    _plan = plan;
    _schedule = actualSchedule;
    _draft = draft;
    _feedback = feedback ?? _feedback;
    _pendingFeedback = clearPending ? null : pending ?? _pendingFeedback;
    _nextCycle = clearNext ? null : next ?? _nextCycle;
    _history = history ?? _history;
    _needsMigration = false;
    _restoreWarning = null;
    _recoverySource = null;
    _recoveryKey = null;
    _notifiedDay = todayNumber;
    // Compatibility mirrors are not a transaction or restoration source when a
    // valid V2 snapshot exists. The committed snapshot has all four components.
    for (final entry in {
      profileKey: profile?.toJson(),
      planKey: plan?.toJson(),
      scheduleKey: actualSchedule?.toJson(),
      draftKey: draft?.toJson(),
    }.entries) {
      try {
        if (entry.value == null) {
          await _prefs.remove(entry.key);
        } else {
          await _prefs.setString(entry.key, jsonEncode(entry.value));
        }
      } catch (_) {}
    }
  }

  void _restore() {
    final hasSnapshot = _prefs.containsKey(stateKey);
    final snapshot = _read(stateKey, (json) => json);
    if (snapshot != null) {
      if (snapshot['version'] != 2) {
        _recoverySource = _prefs.getString(stateKey);
        _restoreWarning = 'Dữ liệu được lưu bởi phiên bản khác. Bản lưu được giữ nguyên; hãy cập nhật ứng dụng.';
        return;
      }
      _profile = _component(snapshot, 'profile', Profile.fromJson);
      _draft = _component(snapshot, 'draft', Profile.fromJson);
      _plan = _component(snapshot, 'plan', MealPlan.fromJson);
      _schedule = _component(snapshot, 'schedule', PlanSchedule.fromJson);
      final receipts = _component(snapshot, 'feedback_receipts', (j) => j);
      if (receipts != null) {
        for (final entry in receipts.entries) {
          final receipt = _component({'receipt': entry.value}, 'receipt', (j) {
            final r = LocalFeedbackReceipt.fromJson(j);
            if (r.key != entry.key) throw const FormatException();
            return r;
          });
          if (receipt != null) _feedback[receipt.key] = receipt;
        }
      }
      _pendingFeedback = _component(snapshot, 'feedback_pending', (j) {
        final pending = PendingFeedback.fromJson(j);
        _checkedCycle(pending.cycle);
        if (pending.cycle.plan.planId != _plan?.planId) {
          throw const FormatException();
        }
        return pending;
      });
      _nextCycle = _component(
        snapshot,
        'next_cycle',
        (j) => _checkedCycle(PlanCycle.fromJson(j)),
      );
      final history = snapshot['history'];
      if (history != null) {
        if (history is List) {
          for (final entry in history) {
            final cycle = _component(
              {'cycle': entry},
              'cycle',
              (j) => _checkedCycle(PlanCycle.fromJson(j)),
            );
            if (cycle != null) _history.add(cycle);
          }
        } else {
          _warn();
        }
      }
    } else {
      _profile = _read(profileKey, Profile.fromJson);
      _draft = _read(draftKey, Profile.fromJson);
      _plan = _read(planKey, MealPlan.fromJson);
      _schedule = _read(scheduleKey, PlanSchedule.fromJson);
      _needsMigration =
          !hasSnapshot && _restoreWarning == null && _plan != null;
    }
    if (_draft != null && profileProblems(_draft!).isNotEmpty) {
      _draft = null;
      _warn();
    }
    if (_plan != null) {
      try {
        if (_profile == null || profileProblems(_profile!).isNotEmpty) {
          throw const FormatException();
        }
        _validatePlan(_plan!);
      } on FormatException {
        _plan = null;
        _warn();
      }
    }
    if (_plan == null) {
      _schedule = null;
      _needsMigration = false;
    } else if (_schedule == null || _schedule!.planId != _plan!.planId) {
      _schedule = PlanSchedule.startingOn(_plan!.planId, _now());
      if (hasSnapshot || _prefs.containsKey(scheduleKey)) {
        _warn();
        _needsMigration = false;
      }
    }
    if (_restoreWarning != null) _needsMigration = false;
    _notifiedDay = todayNumber;
  }

  void _warn() {
    // Keep this in memory; never log raw snapshots or profile/health data.
    try {
      _recoverySource ??= _prefs.getString(stateKey);
    } on TypeError {
      /* Non-string preference remains untouched on restore. */
    }
    _restoreWarning = 'Một phần dữ liệu lưu không đọc được hoặc không còn tương thích. Bản lưu gốc được giữ nguyên; hãy kiểm tra hồ sơ trước khi tạo lại.';
  }

  static PlanCycle _checkedCycle(PlanCycle cycle) {
    _validatePlan(cycle.plan);
    _validateProfile(cycle.profile);
    return cycle;
  }

  T? _component<T>(Json state, String key, T Function(Json) parse) {
    if (state[key] == null) return null;
    try {
      return parse(readMap(state[key], key));
    } on FormatException {
      _warn();
      return null;
    } on TypeError {
      _warn();
      return null;
    }
  }

  T? _read<T>(String key, T Function(Json) parse) {
    try {
      final text = _prefs.getString(key);
      if (text == null) return null;
      return parse(readMap(jsonDecode(text), key));
    } on FormatException {
      _warn();
      return null;
    } on TypeError {
      _warn();
      return null;
    }
  }
}
