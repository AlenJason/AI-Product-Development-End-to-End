import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/routes.dart';
import '../core/theme/app_text_styles.dart';
import '../models/plan_schedule.dart';
import '../providers/plan_provider.dart';
import 'ui_kit.dart';

class PlanStatus extends StatelessWidget {
  const PlanStatus({super.key, this.dayNumber});
  final int? dayNumber;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>(), day = plans.todayNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedbackEntry(dayNumber: dayNumber),
        if (plans.currentSafetyWarning != null)
          NoticePanel(message: plans.currentSafetyWarning!, error: true),
        if (plans.nextCycle != null) ...[
          NoticePanel(
            message:
                'Chu kỳ mới đã sẵn sàng, bắt đầu ${vietnameseDate(plans.nextCycle!.schedule.dateOfDay(1))}. Kế hoạch hiện tại vẫn được giữ đến ngày bắt đầu.',
          ),
          if (plans.nextCycleDue)
            TextButton(
              onPressed: plans.busy ? null : plans.activateScheduledCycle,
              child: const Text('Thử lại mở chu kỳ mới'),
            ),
          const SizedBox(height: 12),
        ],
        if (plans.restoreWarning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoticePanel(message: plans.restoreWarning!),
          ),
        if (day != null && day >= 1 && day <= 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Hôm nay: Ngày $day', style: AppTextStyles.bodySmall),
          ),
        if (day != null && day < 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NoticePanel(
              message:
                  'Kế hoạch chưa bắt đầu. Ngày đầu là ${vietnameseDate(plans.schedule!.dateOfDay(1))}. Bạn có thể xem trước cả 3 ngày.',
            ),
          ),
        if (day != null &&
            day > 3 &&
            plans.nextCycle == null &&
            plans.pendingFeedback == null) ...[
          const NoticePanel(
            message: 'Kế hoạch đã hết hạn sau 3 ngày. Bạn vẫn xem được dữ liệu đã lưu; hãy tạo kế hoạch mới khi sẵn sàng.',
          ),
          const SizedBox(height: 10),
          GradientButton(
            label: 'Tạo kế hoạch mới',
            onPressed: plans.busy
                ? null
                : () => Navigator.pushNamed(
                    context,
                    AppRoutes.onboardingBasicInfo,
                    arguments: plans.editableProfile,
                  ),
          ),
          const SizedBox(height: 12),
        ],
        if (plans.hasPendingProfile)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SurfacePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hồ sơ mới đang chờ áp dụng.'),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed:
                        plans.busy ||
                            plans.pendingFeedback != null ||
                            plans.nextCycle != null
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            AppRoutes.generatingPlan,
                            arguments: plans.editableProfile,
                          ),
                    child: const Text('Tạo lại theo hồ sơ đã lưu'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class FeedbackEntry extends StatelessWidget {
  const FeedbackEntry({super.key, this.dayNumber, this.planId});
  final int? dayNumber;
  final String? planId;
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final id = planId ?? plans.plan?.planId;
    final day =
        dayNumber ??
        plans.pendingFeedback?.answers.dayNumber ??
        plans.todayNumber;
    if (id == null || day == null || day < 1 || day > 3) {
      return const SizedBox.shrink();
    }
    final saved = plans.feedbackFor(id, day);
    final canOpen =
        saved != null ||
        (id == plans.plan?.planId &&
            (plans.pendingFeedback != null || day == plans.todayNumber));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              saved != null
                  ? 'Ngày $day · Đã gửi phản hồi ✓'
                  : 'Phản hồi ngày $day',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              saved?.summary ??
                  (canOpen
                      ? 'Hoàn thành ngày hôm nay? Chia sẻ để điều chỉnh ngày tiếp theo.'
                      : 'Phản hồi mở vào đúng ngày kế hoạch.'),
            ),
            if (canOpen)
              TextButton.icon(
                onPressed: plans.busy
                    ? null
                    : () => Navigator.pushNamed(
                        context,
                        AppRoutes.dailyFeedback,
                        arguments: {
                          'day': saved != null
                              ? day
                              : plans.pendingFeedback?.answers.dayNumber ?? day,
                          'plan_id': id,
                        },
                      ),
                icon: Icon(
                  saved != null
                      ? Icons.check_circle_outline
                      : Icons.rate_review_outlined,
                ),
                label: Text(
                  saved != null
                      ? 'Xem phản hồi đã lưu'
                      : plans.pendingFeedback != null
                      ? 'Thử lại phản hồi đang chờ'
                      : 'Hoàn thành ngày & phản hồi',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
