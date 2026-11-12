import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/progress_header.dart';
import '../../widgets/ui_kit.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final form = context.watch<OnboardingProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ProgressHeader(
              currentStep: 2,
              totalSteps: 3,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeading(
                      title: 'Mục tiêu và vận động',
                      subtitle: 'Chọn mục tiêu và mức gần nhất với nhịp sống hiện tại.',
                      icon: Icons.bolt,
                    ),
                    const SizedBox(height: 24),
                    Text('Mục tiêu', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final goal in ['Giảm mỡ', 'Tăng cơ', 'Duy trì'])
                          ChoiceChip(
                            key: Key('goal-$goal'),
                            label: Text(goal),
                            selected: form.goal == goal,
                            onSelected:
                                goal == 'Giảm mỡ' && form.cutReason != null
                                ? null
                                : (_) => form.updateGoal(goal),
                          ),
                      ],
                    ),
                    if (form.cutReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          form.cutReason!,
                          key: const Key('cut-block-reason'),
                        ),
                      ),
                    if (form.goal.isEmpty)
                      const Text('Chọn một mục tiêu để tiếp tục.'),
                    const SizedBox(height: 22),
                    Text(
                      'Mức độ vận động hằng ngày',
                      style: AppTextStyles.label,
                    ),
                    const SizedBox(height: 10),
                    for (final item in [
                      (
                        Icons.schedule,
                        'Ít vận động',
                        'Chủ yếu ngồi học hoặc làm việc',
                      ),
                      (
                        Icons.trending_up,
                        'Vận động nhẹ',
                        'Đi lại và tập luyện nhẹ',
                      ),
                      (
                        Icons.bolt,
                        'Vận động nhiều',
                        'Tập luyện và vận động thường xuyên',
                      ),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LayoutBuilder(
                          builder: (context, constraints) => SizedBox(
                            width: double.infinity,
                            child: ChoiceChip(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              avatar: Icon(
                                item.$1,
                                color: AppColors.primaryDark,
                              ),
                              showCheckmark: true,
                              label: SizedBox(
                                width: (constraints.maxWidth - 110)
                                    .clamp(80, double.infinity)
                                    .toDouble(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.$2, style: AppTextStyles.label),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.$3,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              selected: form.activityLevel == item.$2,
                              onSelected: (_) => form.updateActivity(item.$2),
                            ),
                          ),
                        ),
                      ),
                    if (form.activityError != null)
                      const Text('Chọn mức độ vận động để tiếp tục.'),
                    if (!form.bodyValid)
                      const Text('Hãy quay lại bước 1 để sửa chỉ số cơ thể.'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: PrimaryButton(
                text: 'Tiếp tục',
                onPressed: form.goalsValid
                    ? () => Navigator.pushNamed(
                        context,
                        AppRoutes.onboardingRestrictions,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
