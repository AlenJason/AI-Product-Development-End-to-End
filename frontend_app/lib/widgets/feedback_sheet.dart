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
