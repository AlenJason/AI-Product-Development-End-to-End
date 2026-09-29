# F02 — Bảng feedback, thẻ trên Dashboard, route khôi phục được

## Feature

Giao diện feedback cuối ngày theo quyết định Q1–Q4:

| File | Việc |
|---|---|
| `lib/widgets/feedback_sheet.dart` (mới) | `FeedbackSheet` — 3 câu hỏi D2 (`ChoiceChip` / `FilterChip`); "Bình thường" loại trừ trạng thái khác; chọn dấu hiệu nguy hiểm → ô đỏ `dangerSignAdvice` ngay, không cần mạng; nút gửi khoá tới khi đủ 3 câu và khi đang bận; gửi → vòng xoay, ngày 3 thêm "có thể mất tới 40 giây"; lỗi → câu của `ApiException`, giữ lựa chọn; 409 → "Tạo kế hoạch mới" (đóng bảng, trả `true`); kết quả: ô đỏ `safety_warning` (chỉ nút "Tôi đã hiểu" đóng được — `PopScope` chặn Back và chạm ra ngoài, `enableDrag: false`), "Đã lưu đánh giá ngày d" + các dòng của `describeFeedbackChanges()`. Câu trả lời đang chọn: `RestorationMixin` (#35). `feedbackSheetRoute` — hàm top-level cho `restorablePush`, tham số chỉ là số ngày |
| `lib/screens/dashboard_screen.dart` | `onFeedback` (tuỳ chọn); thẻ cuối tab ngày: đã gửi → "Đã gửi đánh giá ngày d"; `canReviewDay()` → câu theo ngày + nút "Đánh giá ngày d" (khoá khi `busy`) |
| `lib/main.dart` | `MainShell` giữ `RestorableRouteFuture<bool?>` mở bảng (không đặt ở Dashboard: feedback ngày 3 trả plan mới làm Dashboard dựng lại — brainstorm P3); bảng trả `true` → `_generate()` |

**Phát hiện khi lập plan:**

| # | Phát hiện | Xử lý |
|---|---|---|
| P8 | Hàng "Đã gửi đánh giá ngày 1" tràn 2,1 px khi chạy test (font test rộng hơn): `Text` trong `Row` không có `Expanded` — ngoài đời cũng tràn khi phóng chữ 130% | `Expanded` |
| P9 | `FilterChip`/`ChoiceChip` bọc một `RawChip`, cả hai đều là `SelectableChipAttributes` → tìm tổ tiên ra 2 phần tử | Test lấy `.first` |
| P10 | Danh sách Dashboard dựng dần: một lần kéo 5000 px dừng ở cuối "ước lượng", thẻ cuối trang chưa được dựng → test "không có thẻ" sai ý | Test nhảy tới `maxScrollExtent` lặp tới khi hết tăng |
| P11 | Fixture `generate_plan` giữ nguyên `plan_id` → sau 409 + tạo mới, Dashboard mở lại ở vị trí cuộn cũ. Với `plan_id` mới (như server thật) Dashboard mở từ đầu — thử thêm `PageStorageKey` theo plan rồi kiểm ngược: không cần | Test trả plan có `plan_id` mới; không thêm khoá cuộn |

## Scope

UI-only:

- `frontend_app/lib/widgets/feedback_sheet.dart` (mới)
- `frontend_app/lib/screens/dashboard_screen.dart`, `lib/main.dart` (sửa)
- `frontend_app/test/widgets/feedback_sheet_test.dart` (mới); `test/screens/dashboard_screen_test.dart`, `test/widget_test.dart` (sửa)

## Implementation

### API Routes

Không có route mới. `POST /api/v1/feedback`: không có Gemini → vài trăm ms; có Gemini → cân đối món ngày kế tiếp hoặc (ngày 3) tạo plan mới, backend dừng sau 40 s (#15), app chờ tối đa 60 s (#28). Bảng hiện vòng xoay, ngày 3 có câu "có thể mất tới 40 giây".

### UI Components

- Thẻ trên Dashboard ở cuối tab ngày, sau buổi tập.
- Bảng trượt `ModalBottomSheetRoute` (`isScrollControlled`, tối đa 90 % chiều cao), nằm trong cột 640 của `AppFrame` trên màn hình rộng (D7).

### DB / KV Changes

Không (F01 đã thêm `smartfit.feedback.v1`). Câu trả lời đang chọn chỉ nằm trong dữ liệu khôi phục của hệ điều hành (#35).

### Ràng buộc áp dụng

- **#14** dấu hiệu nguy hiểm: khuyến cáo ngay trong app; `safety_warning` của server hiện nguyên văn, phải xác nhận.
- **#24** hồ sơ của plan (qua `PlanProvider`).
- **#28** không log; lỗi hiện câu của `ApiException`.
- **#35** câu trả lời và bảng đang mở khôi phục được; không ghi xuống `shared_preferences` (test kiểm danh sách khoá không đổi).

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+125: All tests passed!`
- [ ] `flutter build apk --debug`, `flutter build web`, `flutter build macos --debug` build được

## Test Checklist

1. **@happy**: đủ 3 câu mới gửi được; "Bình thường" loại trừ; gửi đúng `day_number`, `intensity`, `body_states`, `eating`; bảng báo điều đã đổi; "Xong" → thẻ "Đã gửi đánh giá ngày 1"
2. **@danger**: ô đỏ hiện khi chưa có request nào; kết quả có câu `safety_warning` của server và dòng ngày nghỉ; Back và chạm ra ngoài không đóng; "Tôi đã hiểu" đóng
3. **@partial-fail**: 400 → câu tiếng Việt, lựa chọn còn, chưa khoá; gửi lại thành công
4. **@409**: câu của server + "Tạo kế hoạch mới" → đóng bảng, gọi `generate-plan`, Dashboard plan mới
5. **@timeout**: ngày 3 → trong lúc chờ có câu "có thể mất tới 40 giây"; xong → "Đã tạo kế hoạch 3 ngày mới, bắt đầu từ Thứ Ba, 29/9…"; Dashboard có dải "Kế hoạch bắt đầu từ Thứ Ba, 29/9."
6. **@card**: ngày 1 có thẻ, ngày 2 (chưa tới) không; ngày 3: ngày 1 không, ngày 2 ("Bạn chưa đánh giá ngày 2…") và 3 có; plan đã hết → ngày 3 có; đã gửi ngày 1 → "Đã gửi…", ngày 2 vẫn có
7. **@restore**: bảng đang mở + 2 lựa chọn → `restartAndRestore()` → bảng và lựa chọn còn; khoá `shared_preferences` không đổi
8. **@auth**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Bảng feedback

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/account.dart';
import '../models/api/codes.dart';
import '../models/feedback_summary.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';

// Feedback cuối ngày (BRD FR-5, PLAN giai đoạn 7): 3 câu hỏi theo D2, gửi, rồi báo đúng điều đã đổi.
// Route khôi phục được (#35): hàm top-level, tham số chỉ là số ngày. Trả `true` khi người dùng chọn tạo kế hoạch
// mới vì plan đã cũ (409).
@pragma('vm:entry-point')
Route<bool?> feedbackSheetRoute(BuildContext context, Object? arguments) => ModalBottomSheetRoute<bool?>(
  builder: (context) => FeedbackSheet(day: arguments! as int),
  isScrollControlled: true,
  // Kéo xuống để đóng thì bỏ qua PopScope — tắt, để cảnh báo an toàn phải được bấm "Tôi đã hiểu".
  enableDrag: false,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
);

// Khuyến cáo hiện ngay khi chọn dấu hiệu nguy hiểm — không chờ server, nên có cả khi mất mạng (#14, quyết định Q3).
const dangerSignAdvice =
    'Hãy ngừng tập và nghỉ ngơi ngay. Nếu chóng mặt, khó thở hay đau ngực nặng lên hoặc kéo dài, gọi cấp cứu 115. '
    'Hỏi ý kiến bác sĩ trước khi tập lại.';

const _intensityLabels = {Intensity.easy: 'Nhẹ nhàng', Intensity.moderate: 'Vừa sức', Intensity.hard: 'Rất mệt'};
const _stateLabels = {
  BodyState.normal: 'Bình thường',
  BodyState.sore: 'Căng mỏi cơ',
  BodyState.jointPain: 'Đau khớp (gối, cổ tay, vai…)',
  BodyState.fatigued: 'Uể oải, thiếu ngủ',
  BodyState.dangerSign: 'Chóng mặt, khó thở bất thường, đau ngực',
};
const _eatingLabels = {
  Eating.onPlan: 'Đúng thực đơn',
  Eating.over: 'Ăn nhiều hơn',
  Eating.under: 'Ăn ít hơn hoặc bỏ bữa',
};

class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({super.key, required this.day});

  final int day;

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _Outcome {
  const _Outcome(this.safetyWarning, this.changes);

  final String? safetyWarning;
  final List<String> changes;
}

class _FeedbackSheetState extends State<FeedbackSheet> with RestorationMixin {
  // Câu trả lời đang chọn: lưu tạm (#35), không ghi xuống máy — tình trạng cơ thể là dữ liệu sức khoẻ (NFR-7).
  final _intensity = RestorableStringN(null);
  final _states = RestorableString('');
  final _eating = RestorableStringN(null);
  bool _sending = false;
  ApiException? _error;
  _Outcome? _outcome;

  @override
  String get restorationId => 'feedback_sheet';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_intensity, 'intensity');
    registerForRestoration(_states, 'states');
    registerForRestoration(_eating, 'eating');
  }

  @override
  void dispose() {
    _intensity.dispose();
    _states.dispose();
    _eating.dispose();
    super.dispose();
  }

  Intensity? get _chosenIntensity => Intensity.values.asNameMap()[_intensity.value];
  Eating? get _chosenEating => Eating.values.asNameMap()[_eating.value];
  Set<BodyState> get _chosenStates => {
    for (final name in _states.value.split(',')) ?BodyState.values.asNameMap()[name],
  };

  // "Bình thường" loại trừ các trạng thái khác — backend cũng bỏ nó khi đi cùng trạng thái khác (BRD 6.4).
  void _toggle(BodyState state, bool on) {
    final next = {..._chosenStates};
    if (!on) {
      next.remove(state);
    } else if (state == BodyState.normal) {
      next
        ..clear()
        ..add(state);
    } else {
      next
        ..remove(BodyState.normal)
        ..add(state);
    }
    setState(
      () => _states.value = [
        for (final s in BodyState.values)
          if (next.contains(s)) s.name,
      ].join(','),
    );
  }

  Future<void> _submit() async {
    final plans = context.read<PlanProvider>();
    final before = plans.plan;
    final (intensity, eating, states) = (_chosenIntensity, _chosenEating, _chosenStates);
    if (before == null || intensity == null || eating == null || states.isEmpty) return;
    final answers = FeedbackAnswers(dayNumber: widget.day, intensity: intensity, bodyStates: states, eating: eating);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final result = await plans.submitFeedback(answers);
      if (!mounted || result == null) return;
      final changes = describeFeedbackChanges(
        before: before,
        after: result.plan,
        answers: answers,
        newPlanStart: plans.schedule?.startDate,
      );
      setState(() => _outcome = _Outcome(result.safetyWarning, changes));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final outcome = _outcome;
    return PopScope(
      // Đang gửi, hoặc cảnh báo an toàn chưa được xác nhận → không đóng bằng nút Back hay chạm ra ngoài.
      canPop: !_sending && outcome?.safetyWarning == null,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: outcome != null
                  ? _result(outcome)
                  : plans.feedbackDays.contains(widget.day)
                  ? _alreadySent()
                  : _form(plans),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _form(PlanProvider plans) {
    final day = widget.day;
    final when = plans.todayNumber == day ? 'hôm nay' : 'ngày $day';
    final states = _chosenStates;
    final error = _error;
    final complete = _chosenIntensity != null && _chosenEating != null && states.isNotEmpty;
    return [
      Text(
        'Đánh giá cuối ngày $day',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      const SizedBox(height: 4),
      Text(
        day == 3
            ? 'Khoảng 1 phút — SmartFit dùng để lập kế hoạch 3 ngày tiếp theo.'
            : 'Khoảng 1 phút — SmartFit dùng để điều chỉnh ngày ${day + 1}.',
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      _question('Cường độ buổi tập $when'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: value, value: label) in _intensityLabels.entries)
            ChoiceChip(
              label: Text(label),
              selected: _chosenIntensity == value,
              onSelected: _sending ? null : (_) => setState(() => _intensity.value = value.name),
            ),
        ],
      ),
      _question('Tình trạng cơ thể khi hoặc sau khi tập (chọn nhiều)'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: state, value: label) in _stateLabels.entries)
            FilterChip(
              avatar: state == BodyState.dangerSign
                  ? const Icon(Icons.warning_amber_rounded, color: AppColors.danger)
                  : null,
              label: Text(label),
              selected: states.contains(state),
              onSelected: _sending ? null : (on) => _toggle(state, on),
            ),
        ],
      ),
      if (states.contains(BodyState.dangerSign)) ...[
        const SizedBox(height: 10),
        const _DangerBox(message: dangerSignAdvice),
      ],
      _question('Ăn uống'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final MapEntry(key: value, value: label) in _eatingLabels.entries)
            ChoiceChip(
              label: Text(label),
              selected: _chosenEating == value,
              onSelected: _sending ? null : (_) => setState(() => _eating.value = value.name),
            ),
        ],
      ),
      if (error != null) ...[
        const SizedBox(height: 12),
        Text(error.message, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
        if (error is PlanOutdatedException)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo kế hoạch mới')),
          ),
      ],
      if (_sending && day == 3) ...[
        const SizedBox(height: 12),
        const Text(
          'Đang lập kế hoạch mới — có thể mất tới 40 giây.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          TextButton(onPressed: _sending ? null : () => Navigator.pop(context), child: const Text('Để sau')),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: complete && !_sending && !plans.busy ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(day == 3 ? 'Gửi và lập kế hoạch mới' : 'Gửi và điều chỉnh ngày ${day + 1}'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _result(_Outcome outcome) {
    final warning = outcome.safetyWarning;
    return [
      if (warning != null) ...[_DangerBox(message: warning), const SizedBox(height: 16)],
      Text(
        'Đã lưu đánh giá ngày ${widget.day}',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
      ),
      const SizedBox(height: 8),
      for (final line in outcome.changes)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  ', style: TextStyle(fontSize: 14, color: AppColors.primary)),
              Expanded(
                child: Text(line, style: const TextStyle(fontSize: 14, color: AppColors.heading)),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      ElevatedButton(
        // Chỉ nút này đóng được bảng khi có cảnh báo an toàn (quyết định Q3): Navigator.pop không qua PopScope.
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: warning == null ? AppColors.primaryBright : AppColors.danger,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(warning == null ? 'Xong' : 'Tôi đã hiểu'),
      ),
    ];
  }

  List<Widget> _alreadySent() => [
    Text(
      'Bạn đã gửi đánh giá ngày ${widget.day}.',
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
    ),
    const SizedBox(height: 16),
    OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
  ];

  Widget _question(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.heading),
    ),
  );
}

class _DangerBox extends StatelessWidget {
  const _DangerBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFCA5A5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
```

### Task 2 — Thẻ trên Dashboard

```diff
--- a/frontend_app/lib/screens/dashboard_screen.dart
+++ b/frontend_app/lib/screens/dashboard_screen.dart
@@ -3,6 +3,7 @@
 
 import '../models/api/codes.dart';
 import '../models/api/meal_plan.dart';
+import '../models/feedback_rules.dart';
 import '../models/plan_schedule.dart';
 import '../providers/plan_provider.dart';
 import '../services/api_exception.dart';
@@ -12,10 +13,12 @@
 // Kế hoạch 3 ngày (BRD FR-2): mở đúng ngày hôm nay (D6-B1), đủ 3 bữa, tổng calo + macro mỗi ngày (FR-2.3),
 // buổi tập, `warnings` (NFR-9). Đổi món / đổi bài gọi API (FR-4.1, FR-4.2 — chuyển lên giai đoạn 6).
 class DashboardScreen extends StatefulWidget {
-  const DashboardScreen({super.key, required this.onCreatePlan});
+  const DashboardScreen({super.key, required this.onCreatePlan, this.onFeedback});
 
   // Tạo plan mới từ hồ sơ hiện tại (bản nháp nếu có) — plan hết hạn, hồ sơ đã đổi, hoặc server báo 409.
   final VoidCallback onCreatePlan;
+  // Mở bảng feedback cuối ngày cho ngày được chọn (giai đoạn 7). null → không có thẻ feedback.
+  final ValueChanged<int>? onFeedback;
 
   @override
   State<DashboardScreen> createState() => _DashboardScreenState();
@@ -115,6 +118,7 @@
           _NutritionSummary(day: day, target: plan.dailyTarget),
           for (final meal in day.meals) _mealCard(plans, meal),
           _workoutCard(plans, day.workout),
+          ?_feedbackCard(plans, dayNumber, today),
         ],
       ),
     );
@@ -290,6 +294,59 @@
     ),
   );
 
+  // Thẻ feedback cuối ngày: đã gửi → báo đã gửi (khoá — BRD 6.4); được đánh giá (quyết định Q2) → nút mở bảng.
+  Widget? _feedbackCard(PlanProvider plans, int dayNumber, int today) {
+    final onFeedback = widget.onFeedback;
+    if (onFeedback == null) return null;
+    if (plans.feedbackDays.contains(dayNumber)) {
+      return _Card(
+        child: Row(
+          children: [
+            const Icon(Icons.check_circle, color: AppColors.primary),
+            const SizedBox(width: 10),
+            Expanded(
+              child: Text(
+                'Đã gửi đánh giá ngày $dayNumber',
+                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
+              ),
+            ),
+          ],
+        ),
+      );
+    }
+    if (!canReviewDay(dayNumber, today: today, sent: plans.feedbackDays)) return null;
+    final text = dayNumber == 3
+        ? 'Đánh giá 1 phút để SmartFit lập kế hoạch 3 ngày tiếp theo.'
+        : dayNumber == today
+        ? 'Hôm nay thế nào? Đánh giá 1 phút để SmartFit điều chỉnh ngày ${dayNumber + 1}.'
+        : 'Bạn chưa đánh giá ngày $dayNumber — gửi ngay để điều chỉnh hôm nay.';
+    return _Card(
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          const Text(
+            'ĐÁNH GIÁ CUỐI NGÀY',
+            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
+          ),
+          const SizedBox(height: 6),
+          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.heading)),
+          const SizedBox(height: 10),
+          ElevatedButton.icon(
+            onPressed: plans.busy ? null : () => onFeedback(dayNumber),
+            icon: const Icon(Icons.rate_review_outlined, size: 18),
+            label: Text('Đánh giá ngày $dayNumber'),
+            style: ElevatedButton.styleFrom(
+              backgroundColor: AppColors.primaryBright,
+              foregroundColor: Colors.white,
+              elevation: 0,
+              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+
   static Meal? _findMeal(MealPlan? plan, String id) =>
       plan?.days.expand((day) => day.meals).where((meal) => meal.mealId == id).firstOrNull;
```

### Task 3 — Route khôi phục được trong `MainShell`

```diff
--- a/frontend_app/lib/main.dart
+++ b/frontend_app/lib/main.dart
@@ -17,6 +17,7 @@
 import 'services/api_exception.dart';
 import 'theme/app_colors.dart';
 import 'widgets/app_frame.dart';
+import 'widgets/feedback_sheet.dart';
 
 Future<void> main() async {
   WidgetsFlutterBinding.ensureInitialized();
@@ -106,13 +107,27 @@
   @override
   String get restorationId => 'shell';
 
+  // Bảng feedback cuối ngày (giai đoạn 7) mở từ đây, không từ Dashboard: feedback ngày 3 trả plan mới làm Dashboard
+  // dựng lại (khoá theo plan_id). Route khôi phục được (#35). Bảng trả true → plan đã cũ (409), tạo plan mới.
+  late final _feedbackRoute = RestorableRouteFuture<bool?>(
+    onPresent: (navigator, arguments) => navigator.restorablePush(feedbackSheetRoute, arguments: arguments),
+    onComplete: (createPlan) {
+      final profile = context.read<PlanProvider>().editableProfile;
+      if (createPlan == true && profile != null) _generate(profile);
+    },
+  );
+
   @override
-  void restoreState(RestorationBucket? oldBucket, bool initialRestore) => registerForRestoration(_tab, 'tab');
+  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
+    registerForRestoration(_tab, 'tab');
+    registerForRestoration(_feedbackRoute, 'feedback_sheet');
+  }
 
   @override
   void dispose() {
     WidgetsBinding.instance.removeObserver(this);
     _tab.dispose();
+    _feedbackRoute.dispose();
     super.dispose();
   }
 
@@ -161,7 +176,11 @@
   Widget _home(PlanProvider plans) => Scaffold(
     body: switch (_tab.value) {
       // Khoá theo plan_id: plan mới thì Dashboard mở lại đúng ngày hôm nay.
-      0 => DashboardScreen(key: ValueKey(plans.plan?.planId), onCreatePlan: () => _generate(plans.editableProfile!)),
+      0 => DashboardScreen(
+        key: ValueKey(plans.plan?.planId),
+        onCreatePlan: () => _generate(plans.editableProfile!),
+        onFeedback: (day) => _feedbackRoute.present(day),
+      ),
       1 => const GroceryScreen(),
       2 => _placeholder(
         icon: Icons.history_rounded,
```

### Task 4 — Test

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/widgets/feedback_sheet.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Bảng feedback cuối ngày (PLAN giai đoạn 7, quyết định Q1–Q4) — mở từ thẻ trên Dashboard, trong cả app.
void main() {
  Future<Harness> openSheet(WidgetTester tester, {int day = 1, DateTime? now}) async {
    final harness = await Harness.create(tester, saved: savedPlan(), now: now);
    await tester.pumpWidget(harness.app());
    await scrollTo(tester, find.text('Đánh giá ngày $day'));
    await tester.tap(find.text('Đánh giá ngày $day'));
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá cuối ngày $day'), findsOneWidget);
    return harness;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pump();
  }

  bool selected(WidgetTester tester, String label) => (tester.widget(
    find.ancestor(
      of: find.text(label),
      // FilterChip/ChoiceChip bọc một RawChip — cả hai đều là SelectableChipAttributes.
      matching: find.byWidgetPredicate((widget) => widget is SelectableChipAttributes),
    ).first,
  ) as SelectableChipAttributes).selected;

  Map<String, dynamic> lastBody(Harness harness) =>
      jsonDecode(utf8.decode(harness.backend.requests.last.bodyBytes)) as Map<String, dynamic>;

  testWidgets(
    'khoá nút gửi tới khi đủ 3 câu; "Bình thường" loại trừ; gửi đúng câu trả lời; báo điều đã đổi; khoá ngày',
    (tester) async {
      final harness = await openSheet(tester);
      const submit = 'Gửi và điều chỉnh ngày 2';
      await tap(tester, 'Rất mệt');
      await tap(tester, 'Căng mỏi cơ');
      await tap(tester, 'Bình thường');
      expect(selected(tester, 'Căng mỏi cơ'), isFalse);
      expect(selected(tester, 'Bình thường'), isTrue);
      await tap(tester, 'Căng mỏi cơ');
      expect(selected(tester, 'Bình thường'), isFalse);
      expect(enabled(tester, submit), isFalse);
      await tap(tester, 'Đúng thực đơn');
      expect(enabled(tester, submit), isTrue);

      await tap(tester, submit);
      await tester.pumpAndSettle();
      expect(lastBody(harness), containsPair('day_number', 1));
      expect(lastBody(harness), containsPair('intensity', 'hard'));
      expect(lastBody(harness)['body_states'], ['sore']);
      expect(lastBody(harness), containsPair('eating', 'on_plan'));
      expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
      expect(find.textContaining('Ngày 2: giảm số hiệp'), findsOneWidget);
      expect(find.text('Ngày 2: buổi tập 20 → 15 phút.'), findsOneWidget);

      await tap(tester, 'Xong');
      await tester.pumpAndSettle();
      expect(find.text('Đánh giá cuối ngày 1'), findsNothing);
      await scrollTo(tester, find.text('Đã gửi đánh giá ngày 1'));
      expect(find.text('Đánh giá ngày 1'), findsNothing);
    },
  );

  testWidgets('dấu hiệu nguy hiểm → khuyến cáo hiện ngay, chưa gọi mạng; sau khi gửi phải bấm "Tôi đã hiểu"', (
    tester,
  ) async {
    final harness = await openSheet(tester);
    await tap(tester, 'Chóng mặt, khó thở bất thường, đau ngực');
    expect(find.text(dangerSignAdvice), findsOneWidget);
    expect(harness.backend.requests, isEmpty);

    harness.backend.responses['/api/v1/feedback'] = loadFixture('feedback_danger');
    await tap(tester, 'Nhẹ nhàng');
    await tap(tester, 'Ăn nhiều hơn');
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    final warning = (loadFixture('feedback_danger')['safety_warning'] as Map)['message'] as String;
    expect(find.text(warning), findsOneWidget);
    expect(find.text('Ngày 2: Nghỉ ngơi — chỉ đi bộ nhẹ nếu thấy khoẻ.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text(warning), findsOneWidget, reason: 'nút Back và chạm ra ngoài không đóng được cảnh báo');

    await tap(tester, 'Tôi đã hiểu');
    await tester.pumpAndSettle();
    expect(find.text(warning), findsNothing);
  });

  testWidgets('server báo lỗi → câu tiếng Việt, giữ lựa chọn, không khoá ngày; gửi lại được', (tester) async {
    final harness = await openSheet(tester);
    for (final label in ['Vừa sức', 'Uể oải, thiếu ngủ', 'Ăn ít hơn hoặc bỏ bữa']) {
      await tap(tester, label);
    }
    harness.backend.failWith = 400;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại hồ sơ.'), findsOneWidget);
    expect(selected(tester, 'Uể oải, thiếu ngủ'), isTrue);
    expect(harness.plans.feedbackDays, isEmpty);

    harness.backend.failWith = null;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
    expect(lastBody(harness)['body_states'], ['fatigued']);
  });

  testWidgets('409 → câu của server + "Tạo kế hoạch mới": đóng bảng và tạo plan', (tester) async {
    final harness = await openSheet(tester);
    for (final label in ['Vừa sức', 'Bình thường', 'Đúng thực đơn']) {
      await tap(tester, label);
    }
    harness.backend.failWith = 409;
    await tap(tester, 'Gửi và điều chỉnh ngày 2');
    await tester.pumpAndSettle();
    expect(find.text(loadFixture('error_409')['message'] as String), findsOneWidget);

    harness.backend.failWith = null;
    final fresh = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    harness.backend.responses['/api/v1/generate-plan'] = fresh;
    await tap(tester, 'Tạo kế hoạch mới');
    await tester.pumpAndSettle();
    expect(find.text('Đánh giá cuối ngày 1'), findsNothing);
    expect(harness.backend.paths.last, '/api/v1/generate-plan');
    expect(harness.plans.plan!.planId, fresh['plan_id']);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
  });

  testWidgets('ngày 3 → chờ có câu "tới 40 giây"; báo plan mới bắt đầu ngày mai; Dashboard hiện plan mới', (
    tester,
  ) async {
    final harness = await openSheet(tester, day: 3, now: planStart.add(const Duration(days: 2)));
    final next = loadFixture('generate_plan')..['plan_id'] = '11111111-2222-4333-8444-555555555555';
    harness.backend.responses['/api/v1/feedback'] = {'plan': next, 'safety_warning': null};
    for (final label in ['Nhẹ nhàng', 'Bình thường', 'Đúng thực đơn']) {
      await tap(tester, label);
    }
    harness.backend.hold = Completer();
    await tap(tester, 'Gửi và lập kế hoạch mới');
    expect(find.text('Đang lập kế hoạch mới — có thể mất tới 40 giây.'), findsOneWidget);
    harness.backend.hold!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Đã tạo kế hoạch 3 ngày mới, bắt đầu từ Thứ Ba, 29/9, có tính tới đánh giá của bạn.'),
      findsOneWidget,
    );

    await tap(tester, 'Xong');
    await tester.pumpAndSettle();
    expect(find.text('Kế hoạch bắt đầu từ Thứ Ba, 29/9.'), findsOneWidget);
    expect(harness.plans.plan!.planId, next['plan_id']);
  });
}
```

```diff
--- a/frontend_app/test/screens/dashboard_screen_test.dart
+++ b/frontend_app/test/screens/dashboard_screen_test.dart
@@ -1,5 +1,9 @@
+import 'dart:convert';
+
+import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
 import 'package:my_ai_app/models/api/profile.dart';
+import 'package:my_ai_app/providers/plan_provider.dart';
 import 'package:my_ai_app/screens/dashboard_screen.dart';
 
 import '../app_harness.dart';
@@ -77,4 +81,75 @@
     await tester.tap(find.text('Tạo kế hoạch mới'));
     expect(created, ['tạo mới']);
   });
+
+  // Giai đoạn 7, quyết định Q2: hôm nay và hôm qua nếu chưa gửi; ngày 3 cả khi plan đã hết; đã gửi thì khoá.
+  group('thẻ feedback cuối ngày', () {
+    Future<List<int>> pumpWithFeedback(WidgetTester tester, {DateTime? now, Set<int> sent = const {}}) async {
+      final saved = savedPlan();
+      final planId = jsonDecode(saved[PlanProvider.planKey]! as String)['plan_id'];
+      final harness = await Harness.create(
+        tester,
+        saved: {
+          ...saved,
+          if (sent.isNotEmpty) PlanProvider.feedbackKey: jsonEncode({'plan_id': planId, 'days': sent.toList()}),
+        },
+        now: now,
+      );
+      final opened = <int>[];
+      await tester.pumpWidget(harness.screen(DashboardScreen(onCreatePlan: () {}, onFeedback: opened.add)));
+      return opened;
+    }
+
+    // Danh sách chỉ dựng phần đang hiện và độ dài tăng dần khi dựng thêm: nhảy tới cuối cho tới khi hết tăng.
+    Future<void> showDay(WidgetTester tester, int day) async {
+      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
+      position.jumpTo(0);
+      await tester.pumpAndSettle();
+      await tester.tap(
+        find.descendant(of: find.byType(SegmentedButton<int>), matching: find.textContaining('Ngày $day')),
+      );
+      await tester.pumpAndSettle();
+      double? end;
+      while (end != position.maxScrollExtent) {
+        end = position.maxScrollExtent;
+        position.jumpTo(end);
+        await tester.pumpAndSettle();
+      }
+    }
+
+    testWidgets('ngày 1: có thẻ, bấm mở đúng ngày; ngày 2 chưa tới → không có thẻ', (tester) async {
+      final opened = await pumpWithFeedback(tester);
+      await showDay(tester, 1);
+      expect(find.text('Hôm nay thế nào? Đánh giá 1 phút để SmartFit điều chỉnh ngày 2.'), findsOneWidget);
+      await tester.tap(find.text('Đánh giá ngày 1'));
+      expect(opened, [1]);
+      await showDay(tester, 2);
+      expect(find.text('ĐÁNH GIÁ CUỐI NGÀY'), findsNothing);
+    });
+
+    testWidgets('ngày 3: ngày 1 đã quá cũ → không có; hôm qua (ngày 2) và hôm nay (ngày 3) có', (tester) async {
+      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 2)));
+      await showDay(tester, 1);
+      expect(find.text('ĐÁNH GIÁ CUỐI NGÀY'), findsNothing);
+      await showDay(tester, 2);
+      expect(find.text('Bạn chưa đánh giá ngày 2 — gửi ngay để điều chỉnh hôm nay.'), findsOneWidget);
+      await showDay(tester, 3);
+      expect(find.text('Đánh giá 1 phút để SmartFit lập kế hoạch 3 ngày tiếp theo.'), findsOneWidget);
+    });
+
+    testWidgets('plan đã hết: vẫn đánh giá được ngày 3 (tạo plan mới)', (tester) async {
+      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 6)));
+      await showDay(tester, 3);
+      expect(find.text('Đánh giá ngày 3'), findsOneWidget);
+    });
+
+    testWidgets('đã gửi ngày 1 → "Đã gửi đánh giá ngày 1", không còn nút; ngày 2 vẫn gửi được', (tester) async {
+      await pumpWithFeedback(tester, now: planStart.add(const Duration(days: 1)), sent: {1});
+      await showDay(tester, 1);
+      expect(find.text('Đã gửi đánh giá ngày 1'), findsOneWidget);
+      expect(find.text('Đánh giá ngày 1'), findsNothing);
+      await showDay(tester, 2);
+      expect(find.text('Đánh giá ngày 2'), findsOneWidget);
+    });
+  });
 }
```

```diff
--- a/frontend_app/test/widget_test.dart
+++ b/frontend_app/test/widget_test.dart
@@ -153,4 +153,31 @@
     expect(find.text('Hồ sơ của bạn'), findsOneWidget);
     expect(tester.widget<TextField>(field('Cân nặng (kg)')).controller!.text, '70');
   });
+
+  // PLAN giai đoạn 7 + D8: câu trả lời đang chọn trong bảng feedback chỉ lưu tạm.
+  testWidgets('bảng feedback đang mở dở, hệ thống tắt app → mở lại vẫn thấy bảng và lựa chọn; không ghi xuống máy', (
+    tester,
+  ) async {
+    final harness = await Harness.create(tester, saved: savedPlan());
+    await tester.pumpWidget(harness.app());
+    await scrollTo(tester, find.text('Đánh giá ngày 1'));
+    await tester.tap(find.text('Đánh giá ngày 1'));
+    await tester.pumpAndSettle();
+    await tester.tap(find.text('Rất mệt'));
+    await tester.tap(find.text('Đau khớp (gối, cổ tay, vai…)'));
+    await tester.pump();
+    final keys = harness.prefs.getKeys();
+
+    await tester.restartAndRestore();
+    expect(find.text('Đánh giá cuối ngày 1'), findsOneWidget);
+    for (final label in ['Rất mệt', 'Đau khớp (gối, cổ tay, vai…)']) {
+      final chip = tester.widget(
+        find
+            .ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is SelectableChipAttributes))
+            .first,
+      ) as SelectableChipAttributes;
+      expect(chip.selected, isTrue, reason: label);
+    }
+    expect(harness.prefs.getKeys(), keys);
+  });
 }
```

### Kiểm

```bash
cd frontend_app
flutter analyze             # No issues found!
flutter test                # +125: All tests passed!
flutter build apk --debug   # ✓ Built
flutter build web           # ✓ Built build/web
flutter build macos --debug # ✓ Built  (export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer nếu cần)
```
