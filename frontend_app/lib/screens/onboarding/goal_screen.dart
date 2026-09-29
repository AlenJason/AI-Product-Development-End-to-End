import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/progress_header.dart';

class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  String _selectedGoal = 'Giảm mỡ';

  final List<Map<String, dynamic>> _goals = [
    {
      'title': 'Giảm mỡ',
      'subtitle': 'Cân đối vóc dáng, giảm mỡ an toàn',
      'icon': Icons.trending_down,
    },
    {
      'title': 'Tăng cơ',
      'subtitle': 'Mạnh hơn với dinh dưỡng đủ chất',
      'icon': Icons.fitness_center,
    },
    {
      'title': 'Duy trì',
      'subtitle': 'Giữ cân và xây thói quen tốt',
      'icon': Icons.balance,
    },
  ];

  void _onContinue() {
    context.read<OnboardingProvider>().updateGoal(_selectedGoal);
    Navigator.pushNamed(context, AppRoutes.onboardingRestrictions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressHeader(
              currentStep: 3,
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
                      child: const Icon(Icons.track_changes, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 24),
                    Text('Mục tiêu của bạn là gì?', style: AppTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Bạn luôn có thể thay đổi mục tiêu sau này.', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 32),
                    ..._goals.map((goal) => _buildOption(goal)),
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
    final isSelected = _selectedGoal == data['title'];
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = data['title']),
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
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

