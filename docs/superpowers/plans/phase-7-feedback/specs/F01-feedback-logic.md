# F01 — Luật ngày được đánh giá, khoá "đã gửi", tóm tắt thay đổi

## Feature

Phần logic của feedback cuối ngày, chưa có giao diện (Dashboard ở mốc này chưa đổi):

| File | Việc |
|---|---|
| `lib/models/feedback_rules.dart` (mới) | `canReviewDay(day, today:, sent:)` — quyết định Q2: hôm nay và hôm qua nếu chưa gửi; ngày 3 cả khi plan đã hết; ngày chưa tới hoặc quá cũ thì không. `FeedbackLog` — `plan_id` + số ngày đã gửi, không có câu trả lời |
| `lib/models/feedback_summary.dart` (mới) | `describeFeedbackChanges(before:, after:, answers:, newPlanStart:)` — quyết định Q4: so plan trước/sau, liệt kê điều đã đổi ở ngày kế tiếp; plan mới (ngày 3) → một dòng kèm ngày bắt đầu |
| `lib/providers/plan_provider.dart` | Khoá `smartfit.feedback.v1`; `feedbackDays`; `submitFeedback()` khoá ngày **sau khi** server trả plan cùng `plan_id`; `generate()` và plan mới từ feedback ngày 3 xoá khoá; `clearPlan()` xoá; bản lưu của plan khác hoặc hỏng → coi như chưa gửi |

**Vì sao so plan ở app:** backend không trả bản tóm tắt; cảnh báo `mealsNotRebalanced` chỉ có trong `warnings` của plan vừa trả và mất ở lần đổi món sau (`rebuildPlan()` tính lại cảnh báo — brainstorm P2).

**Vì sao `generate()` xoá khoá tường minh:** khi lập plan, test phát hiện fixture `generate_plan` trả cùng `plan_id` với plan đang có — nếu chỉ dựa vào "`plan_id` đổi thì xoá", khoá cũ sống sót. Server thật luôn sinh UUID mới, nhưng tạo plan mới về nghĩa là chưa gửi feedback ngày nào.

## Scope

UI-only (logic + test):

- `frontend_app/lib/models/feedback_rules.dart`, `feedback_summary.dart` (mới)
- `frontend_app/lib/providers/plan_provider.dart` (sửa)
- `frontend_app/test/models/feedback_rules_test.dart`, `feedback_summary_test.dart` (mới); `test/providers/plan_provider_test.dart` (sửa)

## Implementation

### API Routes

Không có. Dùng `POST /api/v1/feedback` sẵn có qua `PlanProvider.submitFeedback()` → `ApiClient.submitFeedback()` (timeout 60 s — #28; backend dừng Gemini sau 40 s — #15).

### UI Components

Không có (F02 dùng).

### DB / KV Changes

Khoá `shared_preferences` mới `smartfit.feedback.v1` = `{ "plan_id": "…", "days": [1, 2] }`. Không migration: thiếu, hỏng, của plan khác → coi như chưa gửi ngày nào.

### Ràng buộc áp dụng

- **#12, #28** chỉ lưu số ngày — câu trả lời (tình trạng cơ thể) là dữ liệu sức khoẻ, không ghi xuống máy, không log.
- **#24** `submitFeedback()` vẫn gửi hồ sơ **của plan** (có bản nháp cũng không 409).
- **#26** không đổi hợp đồng API → không sửa model trong `lib/models/api/`, không cần `fixtures:update`.
- **#36** (mới, F03 ghi vào wiki) — luật ngày, khoá chỉ sau khi server trả plan.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+115: All tests passed!`

## Test Checklist

1. **@rules**: plan chưa bắt đầu → không ngày nào; ngày 1 → {1}; ngày 2 → {1, 2}; ngày 3 → {2, 3}; plan đã hết (ngày 4, 9) → {3}; đã gửi → khoá
2. **@log**: `FeedbackLog` chỉ có `plan_id` + số ngày; ngày ngoài 1–3 hoặc sai kiểu → `FormatException`
3. **@summary**: fixture `feedback.json` (rất mệt + căng mỏi) → giảm số hiệp từng động tác, thêm giãn cơ, 20 → 15 phút, không nói gì về món; `feedback_danger.json` → một dòng ngày nghỉ, không báo món dù chọn "ăn nhiều"; ăn nhiều mà món không đổi → "giữ nguyên — chưa cân đối lại được"; món đổi → tổng calo trước → sau; không đổi gì → "giữ nguyên như kế hoạch"; plan mới → ngày bắt đầu; thay/bỏ động tác → tên cũ và mới
4. **@provider**: gửi xong → khoá, lưu, mở lại vẫn khoá; server lỗi (409) → không khoá; đổi món giữ khoá, tạo plan mới xoá; feedback ngày 3 trả plan mới → trống; khoá của plan khác / hỏng → trống
5. **@auth**, **@timeout**, **@token**, **@db**: không đổi (không có route, không có DB)

## Tasks

### Task 1 — Luật ngày và khoá

```dart
import 'api/json_read.dart';

// Feedback cuối ngày (BRD FR-5, PLAN giai đoạn 7). Backend không lưu trạng thái: gửi hai lần cho cùng một ngày sẽ
// điều chỉnh hai lần (BRD 6.4) — nên app nhớ ngày nào của plan đã gửi và khoá nút.

// Ngày thứ [day] có được gửi feedback không (quyết định Q2): hôm nay và hôm qua nếu chưa gửi; ngày 3 vẫn được khi
// plan đã hết (feedback ngày 3 tạo plan mới — FR-5.3). Ngày chưa tới, hoặc quá cũ đến mức điều chỉnh rơi vào một
// ngày đã qua, thì không.
bool canReviewDay(int day, {required int today, required Set<int> sent}) {
  if (day < 1 || day > 3 || day > today || sent.contains(day)) return false;
  return day >= today - 1 || day == 3;
}

// Những ngày đã gửi feedback của một plan. Chỉ lưu số ngày — không lưu câu trả lời (dữ liệu sức khoẻ, NFR-7).
class FeedbackLog {
  const FeedbackLog({required this.planId, this.days = const {}});

  final String planId;
  final Set<int> days;

  factory FeedbackLog.fromJson(Json json) => FeedbackLog(
    planId: readString(json, 'plan_id'),
    days: readList(json, 'days', (item) {
      if (item is int && item >= 1 && item <= 3) return item;
      throw const FormatException('"days" chỉ gồm số ngày 1–3');
    }).toSet(),
  );

  Json toJson() => {'plan_id': planId, 'days': days.toList()..sort()};

  FeedbackLog withDay(int day) => FeedbackLog(planId: planId, days: {...days, day});
}
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/feedback_rules.dart';

void main() {
  // Quyết định Q2 giai đoạn 7: hôm nay và hôm qua nếu chưa gửi; ngày 3 vẫn được khi plan đã hết.
  group('canReviewDay', () {
    Set<int> reviewable(int today, [Set<int> sent = const {}]) => {
      for (var day = 1; day <= 3; day++)
        if (canReviewDay(day, today: today, sent: sent)) day,
    };

    test('plan chưa bắt đầu → không ngày nào', () => expect(reviewable(0), isEmpty));
    test('ngày 1 → chỉ ngày 1', () => expect(reviewable(1), {1}));
    test('ngày 2 → hôm qua (1) và hôm nay (2)', () => expect(reviewable(2), {1, 2}));
    test('ngày 3 → ngày 2 và 3; ngày 1 đã quá cũ (điều chỉnh ngày 2 đã qua)', () => expect(reviewable(3), {2, 3}));
    test('plan đã hết → vẫn gửi được ngày 3 để tạo plan mới', () {
      expect(reviewable(4), {3});
      expect(reviewable(9), {3});
    });
    test('đã gửi → khoá ngày đó', () {
      expect(reviewable(2, {1}), {2});
      expect(reviewable(9, {3}), isEmpty);
    });
  });

  group('FeedbackLog', () {
    test('lưu plan_id và số ngày, không lưu câu trả lời', () {
      final log = const FeedbackLog(planId: 'p1').withDay(2).withDay(1).withDay(2);
      expect(log.toJson(), {
        'plan_id': 'p1',
        'days': [1, 2],
      });
      expect(FeedbackLog.fromJson(log.toJson()).days, {1, 2});
    });

    test('ngày ngoài 1–3 hoặc sai kiểu → FormatException', () {
      for (final days in [
        [4],
        [0],
        ['1'],
      ]) {
        expect(() => FeedbackLog.fromJson({'plan_id': 'p1', 'days': days}), throwsFormatException);
      }
    });
  });
}
```

### Task 2 — Tóm tắt thay đổi

```dart
import 'dart:math' as math;

import 'api/account.dart';
import 'api/codes.dart';
import 'api/meal_plan.dart';
import 'plan_schedule.dart';

// Điều feedback vừa làm thay đổi (quyết định Q4 giai đoạn 7), để báo cho người dùng ngay sau khi gửi. Backend không
// trả bản tóm tắt, còn cảnh báo "chưa cân đối món" trong `warnings` mất ở lần đổi món sau — nên so plan trước và
// sau. Chỉ nói điều thật sự đã đổi; không đổi gì thì nói đúng như vậy.
List<String> describeFeedbackChanges({
  required MealPlan before,
  required MealPlan after,
  required FeedbackAnswers answers,
  DateTime? newPlanStart,
}) {
  // Ngày 3 → plan mới (FR-5.3), không có gì để so với plan cũ.
  if (after.planId != before.planId) {
    final start = newPlanStart == null ? '' : ', bắt đầu từ ${vietnameseDate(newPlanStart)}';
    return ['Đã tạo kế hoạch 3 ngày mới$start, có tính tới đánh giá của bạn.'];
  }
  final next = answers.dayNumber + 1;
  final danger = answers.bodyStates.contains(BodyState.dangerSign);
  final lines = [
    ..._workoutChanges(before.days[next - 1].workout, after.days[next - 1].workout, next, danger),
    ..._mealChanges(before.days[next - 1].meals, after.days[next - 1].meals, next, answers.eating, danger),
  ];
  return lines.isEmpty ? ['Ngày $next giữ nguyên như kế hoạch.'] : lines;
}

List<String> _workoutChanges(Workout old, Workout now, int day, bool danger) {
  // Dấu hiệu nguy hiểm: cả buổi thành ngày nghỉ — tên buổi đã nói đủ, không liệt kê từng động tác bị bỏ.
  if (danger) return ['Ngày $day: ${now.title}.'];
  final lines = <String>[];
  final fewer = <String>[];
  final more = <String>[];
  final shared = math.min(old.exercises.length, now.exercises.length);
  for (var i = 0; i < shared; i++) {
    final (a, b) = (old.exercises[i], now.exercises[i]);
    if (a.name != b.name) {
      lines.add('Ngày $day: thay "${a.name}" bằng "${b.name}".');
    } else if (b.sets != a.sets) {
      (b.sets < a.sets ? fewer : more).add('${b.name} ${a.sets} → ${b.sets}');
    }
  }
  if (fewer.isNotEmpty) lines.add('Ngày $day: giảm số hiệp — ${fewer.join(', ')}.');
  if (more.isNotEmpty) lines.add('Ngày $day: tăng số hiệp — ${more.join(', ')}.');
  for (final added in now.exercises.skip(shared)) {
    lines.add('Ngày $day: thêm "${added.name}".');
  }
  for (final removed in old.exercises.skip(shared)) {
    lines.add('Ngày $day: bỏ "${removed.name}".');
  }
  if (now.durationMinutes != old.durationMinutes) {
    lines.add('Ngày $day: buổi tập ${old.durationMinutes} → ${now.durationMinutes} phút.');
  }
  return lines;
}

List<String> _mealChanges(List<Meal> old, List<Meal> now, int day, Eating eating, bool danger) {
  final changed =
      old.length != now.length ||
      [for (var i = 0; i < old.length; i++) old[i].name != now[i].name || old[i].calories != now[i].calories]
          .any((c) => c);
  if (changed) return ['Thực đơn ngày $day đã được cân đối lại: ${_total(old)} → ${_total(now)} kcal.'];
  // Có dấu hiệu nguy hiểm thì server không đụng tới món ăn (#14) — không báo "chưa cân đối được".
  if (eating != Eating.onPlan && !danger) {
    return ['Thực đơn ngày $day giữ nguyên — chưa cân đối lại được theo phần ăn uống bạn báo.'];
  }
  return [];
}

int _total(List<Meal> meals) => meals.fold<num>(0, (sum, meal) => sum + meal.calories).round();
```

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/feedback_summary.dart';

import '../fixture_loader.dart';

// Quyết định Q4 giai đoạn 7: báo đúng điều đã đổi, so plan trước (generate_plan) và sau (fixture feedback của backend).
void main() {
  final before = MealPlan.fromJson(loadFixture('generate_plan'));

  FeedbackAnswers answers(
    Set<BodyState> states, {
    Intensity intensity = Intensity.hard,
    Eating eating = Eating.onPlan,
  }) => FeedbackAnswers(dayNumber: 1, intensity: intensity, bodyStates: states, eating: eating);

  test('rất mệt + căng mỏi (feedback.json): liệt kê hiệp giảm, giãn cơ thêm, thời lượng — không nói gì về món', () {
    final after = FeedbackResult.fromJson(loadFixture('feedback')).plan;
    expect(describeFeedbackChanges(before: before, after: after, answers: answers({BodyState.sore})), [
      'Ngày 2: giảm số hiệp — Đi bộ tại chỗ nâng cao gối (khởi động) 2 → 1, Nhón gót (Calf raise) 3 → 2, '
          'Cầu mông (Glute bridge) 3 → 2, Dead bug 3 → 2.',
      'Ngày 2: thêm "Giãn cơ nhẹ các nhóm cơ đã tập".',
      'Ngày 2: buổi tập 20 → 15 phút.',
    ]);
  });

  test('dấu hiệu nguy hiểm (feedback_danger.json): một dòng ngày nghỉ, không báo món dù đã chọn ăn nhiều', () {
    final after = FeedbackResult.fromJson(loadFixture('feedback_danger')).plan;
    final lines = describeFeedbackChanges(
      before: before,
      after: after,
      answers: answers({BodyState.dangerSign}, intensity: Intensity.easy, eating: Eating.over),
    );
    expect(lines, ['Ngày 2: Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ.']);
  });

  test('ăn nhiều mà món không đổi (chưa có Gemini) → nói rõ thực đơn giữ nguyên', () {
    final lines = describeFeedbackChanges(
      before: before,
      after: before,
      answers: answers({BodyState.normal}, intensity: Intensity.moderate, eating: Eating.over),
    );
    expect(lines, ['Thực đơn ngày 2 giữ nguyên — chưa cân đối lại được theo phần ăn uống bạn báo.']);
  });

  test('món đổi → tổng calo trước và sau; không đổi gì → nói ngày đó giữ nguyên', () {
    final json = loadFixture('generate_plan');
    final meal = (((json['days'] as List)[1] as Map)['meals'] as List)[2] as Map<String, dynamic>;
    meal['name'] = 'Canh chua cá lóc, cơm trắng';
    meal['calories'] = 467;
    final rebalanced = MealPlan.fromJson(json);
    expect(
      describeFeedbackChanges(
        before: before,
        after: rebalanced,
        answers: answers({BodyState.normal}, eating: Eating.over),
      ),
      ['Thực đơn ngày 2 đã được cân đối lại: 1624 → 1524 kcal.'],
    );
    expect(
      describeFeedbackChanges(
        before: before,
        after: before,
        answers: answers({BodyState.normal}, intensity: Intensity.moderate),
      ),
      ['Ngày 2 giữ nguyên như kế hoạch.'],
    );
  });

  test('feedback ngày 3 trả plan mới → báo plan mới và ngày bắt đầu', () {
    final json = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    final lines = describeFeedbackChanges(
      before: before,
      after: MealPlan.fromJson(json),
      answers: const FeedbackAnswers(
        dayNumber: 3,
        intensity: Intensity.easy,
        bodyStates: {BodyState.normal},
        eating: Eating.onPlan,
      ),
      newPlanStart: DateTime.utc(2026, 9, 30),
    );
    expect(lines, ['Đã tạo kế hoạch 3 ngày mới, bắt đầu từ Thứ Tư, 30/9, có tính tới đánh giá của bạn.']);
  });

  test('thay động tác (đau khớp) và bỏ động tác → nêu tên cũ và mới', () {
    final json = loadFixture('generate_plan');
    final exercises = ((((json['days'] as List)[1] as Map)['workout'] as Map)['exercises'] as List);
    (exercises[1] as Map)['name'] = 'Nằm ngửa nâng thẳng chân (Straight-leg raise)';
    exercises.removeLast();
    final after = MealPlan.fromJson(json);
    expect(describeFeedbackChanges(before: before, after: after, answers: answers({BodyState.jointPain})), [
      'Ngày 2: thay "Nhón gót (Calf raise)" bằng "Nằm ngửa nâng thẳng chân (Straight-leg raise)".',
      'Ngày 2: bỏ "Dead bug".',
    ]);
  });
}
```

### Task 3 — Khoá trong `PlanProvider`

```diff
--- a/frontend_app/lib/providers/plan_provider.dart
+++ b/frontend_app/lib/providers/plan_provider.dart
@@ -8,6 +8,7 @@
 import '../models/api/json_read.dart';
 import '../models/api/meal_plan.dart';
 import '../models/api/profile.dart';
+import '../models/feedback_rules.dart';
 import '../models/plan_schedule.dart';
 import '../models/profile_rules.dart';
 import '../services/api_client.dart';
@@ -27,6 +28,7 @@
   static const profileKey = 'smartfit.profile.v1';
   static const scheduleKey = 'smartfit.plan_schedule.v1';
   static const draftKey = 'smartfit.profile_draft.v1';
+  static const feedbackKey = 'smartfit.feedback.v1';
 
   final ApiClient _api;
   final SharedPreferences _prefs;
@@ -36,6 +38,7 @@
   MealPlan? _plan;
   PlanSchedule? _schedule;
   Profile? _draft;
+  FeedbackLog? _feedback;
   bool _busy = false;
 
   // Hồ sơ đã tạo plan hiện tại.
@@ -55,12 +58,16 @@
   // Ngày thứ mấy của plan hôm nay (< 1: chưa bắt đầu, > 3: đã hết). null khi chưa có plan.
   int? get todayNumber => _schedule?.dayNumberOn(_now());
 
+  // Ngày của plan đang mở đã gửi feedback — khoá nút gửi lại (BRD 6.4). Plan mới → trống.
+  Set<int> get feedbackDays => _feedback?.days ?? const {};
+
   // Mọi hàm gọi server: lỗi → ApiException (plan đang có giữ nguyên); đang bận → bỏ qua, không gọi server.
   // Tạo plan mới: bắt đầu từ hôm nay, bỏ bản nháp (hồ sơ đã được dùng).
   Future<void> generate(Profile profile) => _run(() async {
     final plan = await _api.generatePlan(profile);
     _draft = null;
     await _prefs.remove(draftKey);
+    await _clearFeedback();
     await _save(profile, plan, PlanSchedule.startingOn(plan.planId, _now()));
   });
 
@@ -75,14 +82,20 @@
   });
 
   // null khi đang bận. `safetyWarning` khác null → UI hiện cảnh báo nổi bật (BRD 6.4, dấu hiệu nguy hiểm).
-  // Feedback ngày 3 trả plan mới (`plan_id` khác) — plan đó bắt đầu từ ngày mai.
+  // Feedback ngày 3 trả plan mới (`plan_id` khác) — plan đó bắt đầu từ ngày mai. Chỉ khoá ngày khi server đã trả
+  // plan: lỗi mạng thì người dùng gửi lại được.
   Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(() async {
     final (profile, plan) = _current();
     final result = await _api.submitFeedback(profile, plan, answers);
-    final schedule = result.plan.planId == plan.planId
+    final samePlan = result.plan.planId == plan.planId;
+    final schedule = samePlan
         ? _schedule
         : PlanSchedule.startingOn(result.plan.planId, _now().add(const Duration(days: 1)));
     await _save(profile, result.plan, schedule);
+    if (samePlan) {
+      _feedback = (_feedback ?? FeedbackLog(planId: plan.planId)).withDay(answers.dayNumber);
+      await _prefs.setString(feedbackKey, jsonEncode(_feedback!.toJson()));
+    }
     return result;
   });
 
@@ -105,8 +118,14 @@
     notifyListeners();
     await _prefs.remove(planKey);
     await _prefs.remove(scheduleKey);
+    await _clearFeedback();
   }
 
+  Future<void> _clearFeedback() async {
+    _feedback = null;
+    await _prefs.remove(feedbackKey);
+  }
+
   Future<T?> _run<T>(Future<T> Function() task) async {
     if (_busy) return null;
     _busy = true;
@@ -127,6 +146,8 @@
   }
 
   Future<void> _save(Profile profile, MealPlan plan, PlanSchedule? schedule) async {
+    // Plan khác (feedback ngày 3 trả plan mới) → chưa gửi feedback ngày nào; đổi món/bài giữ `plan_id` nên giữ khoá.
+    if (plan.planId != _plan?.planId) await _clearFeedback();
     _profile = profile;
     _plan = plan;
     _schedule = schedule ?? PlanSchedule.startingOn(plan.planId, _now());
@@ -154,6 +175,9 @@
         : schedule != null && schedule.planId == plan.planId
         ? schedule
         : PlanSchedule.startingOn(plan.planId, _now());
+    // Khoá feedback của plan khác (hoặc hỏng) → coi như chưa gửi ngày nào.
+    final feedback = plan == null ? null : _read(feedbackKey, FeedbackLog.fromJson);
+    _feedback = feedback != null && feedback.planId == plan?.planId ? feedback : null;
   }
 
   T? _read<T>(String key, T Function(Json json) parse) {
```

```diff
--- a/frontend_app/test/providers/plan_provider_test.dart
+++ b/frontend_app/test/providers/plan_provider_test.dart
@@ -201,4 +201,65 @@
     expect(provider.editableProfile!.age, 17);
     expect(prefs.containsKey(PlanProvider.planKey), isFalse);
   });
+
+  // Giai đoạn 7: backend không lưu trạng thái, gửi lại sẽ điều chỉnh thêm lần nữa (BRD 6.4) → app khoá theo ngày.
+  group('khoá feedback theo ngày', () {
+    const day1 = FeedbackAnswers(dayNumber: 1, intensity: Intensity.hard, bodyStates: {BodyState.sore}, eating: Eating.onPlan);
+    final planId = loadFixture('generate_plan')['plan_id'];
+
+    test('gửi xong → khoá ngày đó và lưu lại, chỉ số ngày; mở lại app vẫn khoá', () async {
+      final (provider, backend, prefs) = await create(saved);
+      await provider.submitFeedback(day1);
+      expect(provider.feedbackDays, {1});
+      expect(jsonDecode(prefs.getString(PlanProvider.feedbackKey)!), {
+        'plan_id': planId,
+        'days': [1],
+      });
+      expect(PlanProvider(api: backend.api, prefs: prefs, now: () => now).feedbackDays, {1});
+    });
+
+    test('server lỗi → không khoá, gửi lại được', () async {
+      final (provider, backend, prefs) = await create(saved);
+      backend.failWith = 409;
+      await expectLater(provider.submitFeedback(day1), throwsA(isA<PlanOutdatedException>()));
+      expect(provider.feedbackDays, isEmpty);
+      expect(prefs.containsKey(PlanProvider.feedbackKey), isFalse);
+    });
+
+    test('đổi món giữ khoá (cùng plan_id); tạo plan mới → hết khoá', () async {
+      final (provider, _, prefs) = await create(saved);
+      await provider.submitFeedback(day1);
+      await provider.swapMeal('m2_1');
+      expect(provider.feedbackDays, {1});
+      await provider.generate(profile);
+      expect(provider.feedbackDays, isEmpty);
+      expect(prefs.containsKey(PlanProvider.feedbackKey), isFalse);
+    });
+
+    test('feedback ngày 3 trả plan mới → plan mới chưa khoá ngày nào', () async {
+      final (provider, backend, prefs) = await create(saved);
+      await provider.submitFeedback(day1);
+      final next = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
+      backend.responses['/api/v1/feedback'] = {'plan': next, 'safety_warning': null};
+      await provider.submitFeedback(
+        const FeedbackAnswers(dayNumber: 3, intensity: Intensity.easy, bodyStates: {BodyState.normal}, eating: Eating.onPlan),
+      );
+      expect(provider.plan!.planId, next['plan_id']);
+      expect(provider.feedbackDays, isEmpty);
+      expect(prefs.containsKey(PlanProvider.feedbackKey), isFalse);
+    });
+
+    test('khoá lưu của plan khác hoặc bị hỏng → coi như chưa gửi ngày nào', () async {
+      for (final stored in [
+        jsonEncode({
+          'plan_id': 'khac',
+          'days': [1, 2],
+        }),
+        '{"days": "hỏng"}',
+      ]) {
+        final (provider, _, _) = await create({...saved, PlanProvider.feedbackKey: stored});
+        expect(provider.feedbackDays, isEmpty);
+      }
+    });
+  });
 }
```

### Kiểm

```bash
cd frontend_app
flutter analyze   # No issues found!
flutter test      # +115: All tests passed!
```
