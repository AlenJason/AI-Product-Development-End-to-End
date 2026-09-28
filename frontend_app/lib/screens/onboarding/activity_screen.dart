import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/progress_header.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _selectedActivity = 'Vận động nhẹ';

  final List<Map<String, dynamic>> _activities = [
    {
      'title': 'Ít vận động',
      'subtitle': 'Chủ yếu ngồi học / làm việc',
      'icon': Icons.schedule,
    },
    {
      'title': 'Vận động nhẹ',
      'subtitle': '1-3 buổi tập mỗi tuần',
      'icon': Icons.trending_up,
    },
    {
      'title': 'Vận động nhiều',
      'subtitle': '4-5 buổi tập mỗi tuần',
      'icon': Icons.bolt,
    },
  ];

  void _onContinue() {
    context.read<OnboardingProvider>().updateActivity(_selectedActivity);
    Navigator.pushNamed(context, AppRoutes.onboardingGoal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressHeader(
              currentStep: 2,
              totalSteps: 4,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.bolt, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 24),
                    Text('Bạn vận động như thế nào?', style: AppTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Chọn mức gần nhất với nhịp sống hiện tại.', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 32),
                    ..._activities.map((activity) => _buildOption(activity)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                text: 'Tiếp tục',
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(Map<String, dynamic> data) {
    final isSelected = _selectedActivity == data['title'];
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = data['title']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.transparent : AppColors.panel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                data['icon'],
                color: isSelected ? AppColors.primary : AppColors.ink,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'],
                    style: AppTextStyles.h2.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['subtitle'],
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

