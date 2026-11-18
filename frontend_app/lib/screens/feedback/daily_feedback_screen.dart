import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/primary_button.dart';
import '../../providers/plan_provider.dart';
import '../../models/api/account.dart';
import '../../models/feedback_state.dart';
import '../../models/api/codes.dart';
import '../../services/api_exception.dart';
import '../../core/constants/routes.dart';
import '../../widgets/ui_kit.dart';

class DailyFeedbackScreen extends StatefulWidget {
  const DailyFeedbackScreen({super.key, this.dayNumber, this.planId});
  final int? dayNumber;
  final String? planId;

  @override
  State<DailyFeedbackScreen> createState() => _DailyFeedbackScreenState();
}

class _DailyFeedbackScreenState extends State<DailyFeedbackScreen> {
  String? _error;
  late final int? _day;
  late final String? _planId;
  LocalFeedbackReceipt? get _receipt => _planId == null || _day == null
      ? null
      : context.read<PlanProvider>().feedbackFor(_planId, _day);
  @override
  void initState() {
    super.initState();
    final plans = context.read<PlanProvider>();
    _day =
        widget.dayNumber ??
        plans.pendingFeedback?.answers.dayNumber ??
        plans.todayNumber;
    _planId = widget.planId ?? plans.plan?.planId;
    final answers =
        _receipt?.answers ??
        (_pendingMatches(plans) ? plans.pendingFeedback?.answers : null);
    if (answers != null) {
      _workoutIntensity = switch (answers.intensity) {
        Intensity.easy => 'Nhẹ nhàng',
        Intensity.hard => 'Rất mệt',
        _ => 'Vừa sức',
      };
      _mealStatus = switch (answers.eating) {
        Eating.over => 'Ăn nhiều hơn',
        Eating.under => 'Ăn ít hơn / bỏ bữa',
        _ => 'Đúng thực đơn',
      };
      _bodyStatus.clear();
      _bodyStatus.addAll(
        answers.bodyStates.map(
          (s) => switch (s) {
            BodyState.normal => 'Bình thường',
            BodyState.sore => 'Căng mỏi cơ',
            BodyState.jointPain => 'Đau khớp',
            BodyState.fatigued => 'Uể oải / thiếu ngủ',
            _ => 'Dấu hiệu bất thường',
          },
        ),
      );
    }
  }

  bool _pendingMatches(PlanProvider plans) =>
      plans.pendingFeedback?.cycle.plan.planId == _planId &&
      plans.pendingFeedback?.answers.dayNumber == _day;
  bool _canSubmit(PlanProvider plans) =>
      _receipt == null &&
      _planId == plans.plan?.planId &&
      (_pendingMatches(plans) ||
          (plans.pendingFeedback == null &&
              (_day == plans.todayNumber &&
                  _day != null &&
                  _day >= 1 &&
                  _day <= 3 &&
                  plans.nextCycle == null)));
  bool _submitting = false;
  Future<void> _submit() async {
    final plans = context.read<PlanProvider>();
    final day = _day;
    if (_submitting || plans.busy || !_canSubmit(plans) || day == null) return;
    final states = <BodyState>{
      for (final label in _bodyStatus)
        switch (label) {
          'Bình thường' => BodyState.normal,
          'Căng mỏi cơ' => BodyState.sore,
          'Đau khớp' => BodyState.jointPain,
          'Uể oải / thiếu ngủ' => BodyState.fatigued,
          _ => BodyState.dangerSign,
        },
    };
    final answers = FeedbackAnswers(
      dayNumber: day,
      intensity: switch (_workoutIntensity) {
        'Nhẹ nhàng' => Intensity.easy,
        'Rất mệt' => Intensity.hard,
        _ => Intensity.moderate,
      },
      bodyStates: states,
      eating: switch (_mealStatus) {
        'Ăn nhiều hơn' => Eating.over,
        'Ăn ít hơn / bỏ bữa' => Eating.under,
        _ => Eating.onPlan,
      },
    );
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = plans.pendingFeedback == null
          ? await plans.submitFeedback(answers)
          : await plans.retryFeedback();
      if (!mounted || result == null) return;
      if (result.safetyWarning != null) {
        setState(() => _submitting = false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Lưu ý sức khỏe'),
            content: Text(result.safetyWarning!),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không thể lưu điều chỉnh. Kế hoạch đang có được giữ nguyên.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _workoutIntensity = 'Vừa sức'; // Default selected
  final Set<String> _bodyStatus = {'Bình thường'};
  String _mealStatus = 'Đúng thực đơn';

  final List<Map<String, String>> _intensityOptions = [
    {'title': 'Nhẹ nhàng', 'sub': 'Có thể tập thêm'},
    {'title': 'Vừa sức', 'sub': 'Đúng khả năng'},
    {'title': 'Rất mệt', 'sub': 'Cần giảm nhẹ'},
  ];

  final List<Map<String, dynamic>> _statusOptions = [
    {'label': 'Bình thường', 'type': 'normal'},
    {'label': 'Căng mỏi cơ', 'type': 'warning'},
    {'label': 'Đau khớp', 'type': 'warning'},
    {'label': 'Uể oải / thiếu ngủ', 'type': 'warning'},
    {'label': 'Chóng mặt', 'type': 'danger'},
    {'label': 'Khó thở bất thường', 'type': 'danger'},
    {'label': 'Đau ngực', 'type': 'danger'},
    {'label': 'Dấu hiệu bất thường', 'type': 'danger'},
  ];

  final List<String> _mealOptions = [
    'Đúng thực đơn',
    'Ăn nhiều hơn',
    'Ăn ít hơn / bỏ bữa',
  ];

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final locked =
        plans.busy ||
        _submitting ||
        _receipt != null ||
        plans.pendingFeedback != null ||
        !_canSubmit(plans);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AbsorbPointer(
                  absorbing: locked,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(
                        'Bạn cảm thấy hôm nay thế nào?',
                        style: AppTextStyles.h1.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Phản hồi giúp SmartFit điều chỉnh kế hoạch ngày mai.',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 32),

                      _buildSectionHeader('1', 'Cường độ buổi tập'),
                      const SizedBox(height: 16),
                      _buildIntensityCards(),
                      const SizedBox(height: 32),

                      _buildSectionHeader('2', 'Tình trạng cơ thể'),
                      const SizedBox(height: 16),
                      _buildBodyStatusChips(),
                      const SizedBox(height: 32),

                      _buildSectionHeader('3', 'Ăn uống hôm nay'),
                      const SizedBox(height: 16),
                      _buildMealRadioGroup(),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .48,
              ),
              child: SingleChildScrollView(child: _buildBottomBar(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.ink,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: AppTextStyles.label.copyWith(color: const Color(0xFF16A34A)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: AppTextStyles.h3)),
      ],
    );
  }

  Widget _buildIntensityCards() {
    return Row(
      children: _intensityOptions.map((opt) {
        final isSelected = _workoutIntensity == opt['title'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _workoutIntensity = opt['title']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF22C55E)
                      : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    isSelected ? Icons.sentiment_satisfied_alt : Icons.remove,
                    color: isSelected ? AppColors.ink : AppColors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    opt['title']!,
                    style: AppTextStyles.h3.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opt['sub']!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBodyStatusChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: _statusOptions
          .where(
            (opt) =>
                opt['label'] != 'Dấu hiệu bất thường' ||
                _bodyStatus.contains('Dấu hiệu bất thường'),
          )
          .map((opt) {
            final label = opt['label'] as String;
            final type = opt['type'] as String;
            final isSelected = _bodyStatus.contains(label);

            Color borderColor = AppColors.border;
            Color textColor = AppColors.ink;

            if (isSelected) {
              borderColor = const Color(0xFF22C55E);
              textColor = const Color(0xFF16A34A);
            } else if (type == 'danger') {
              borderColor = const Color(0xFFFDE68A); // Yellow/Orange warning
              textColor = const Color(0xFFB45309);
            }

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (label == 'Bình thường') {
                    _bodyStatus.clear();
                    _bodyStatus.add(label);
                  } else {
                    _bodyStatus.remove('Bình thường');
                    if (isSelected) {
                      _bodyStatus.remove(label);
                      if (_bodyStatus.isEmpty) _bodyStatus.add('Bình thường');
                    } else {
                      _bodyStatus.add(label);
                    }
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check,
                        color: Color(0xFF16A34A),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(),
    );
  }

  Widget _buildMealRadioGroup() {
    return Column(
      children: _mealOptions.map((opt) {
        final isSelected = _mealStatus == opt;
        return GestureDetector(
          onTap: () => setState(() => _mealStatus = opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF22C55E) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF22C55E)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF22C55E)
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    opt,
                    style: AppTextStyles.h3.copyWith(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final plans = context.watch<PlanProvider>(), receipt = _receipt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: AppColors.background),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) NoticePanel(message: _error!, error: true),
          if (receipt != null) ...[
            NoticePanel(message: receipt.summary),
            if (receipt.safetyWarning != null)
              NoticePanel(message: receipt.safetyWarning!, error: true),
            const SizedBox(height: 12),
            PrimaryButton(
              text: 'Mở Dashboard',
              onPressed: () =>
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
            ),
          ] else ...[
            if (plans.pendingFeedback != null)
              const NoticePanel(
                message: 'Phản hồi đang chờ xác nhận. Nội dung được giữ nguyên để thử lại an toàn, kể cả sau khi mở lại ứng dụng.',
              ),
            if (!_canSubmit(plans))
              const NoticePanel(
                message: 'Chỉ gửi phản hồi cho ngày hiện tại trong kế hoạch đang diễn ra.',
              ),
            const SizedBox(height: 10),
            PrimaryButton(
              text: plans.pendingFeedback != null && !plans.busy
                  ? 'Thử lại phản hồi'
                  : 'Điều chỉnh kế hoạch',
              icon: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
              isLoading: _submitting || plans.busy,
              onPressed: plans.busy || _submitting || !_canSubmit(plans)
                  ? null
                  : _submit,
            ),
            const SizedBox(height: 12),
            Text(
              'SmartFit chỉ điều chỉnh sau khi bạn xác nhận.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
