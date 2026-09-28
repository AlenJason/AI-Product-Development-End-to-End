import 'package:flutter/material.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GeneratingPlanScreen extends StatefulWidget {
  const GeneratingPlanScreen({super.key});

  @override
  State<GeneratingPlanScreen> createState() => _GeneratingPlanScreenState();
}

class _GeneratingPlanScreenState extends State<GeneratingPlanScreen> {
  int _currentStep = 1;

  @override
  void initState() {
    super.initState();
    _startMockLoading();
  }

  void _startMockLoading() async {
    for (int i = 1; i <= 4; i++) {
      if (mounted) {
        setState(() => _currentStep = i);
      }
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header / Logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.fitness_center, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Text.rich(
                      TextSpan(
                        text: 'SmartFit ',
                        style: AppTextStyles.h2,
                        children: [
                          TextSpan(
                            text: 'AI',
                            style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                
                // Spinner
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: _currentStep / 4,
                        strokeWidth: 8,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 40),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                
                Text(
                  'SmartFit đang chuẩn bị\nkế hoạch cho bạn...',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Một chút thôi, AI đang kết hợp dinh dưỡng và\nvận động phù hợp nhất.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Steps
                _buildStepItem(1, 'Đang tính nhu cầu năng lượng...'),
                _buildStepItem(2, 'Đang chọn món Việt phù hợp...'),
                _buildStepItem(3, 'Đang xây dựng lịch tập...'),
                _buildStepItem(4, 'Đang chuẩn bị danh sách đi chợ...'),
                
                const SizedBox(height: 24),
                Text(
                  'Thường mất khoảng 8-15 giây',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(int stepNumber, String text) {
    bool isCompleted = _currentStep > stepNumber;
    bool isActive = _currentStep == stepNumber;
    

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isActive ? 16 : 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        children: [
          if (isCompleted)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            )
          else if (isActive)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: AppColors.muted.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Center(
                child: Text(
                  stepNumber.toString(),
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.muted),
                ),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: (isCompleted || isActive) ? FontWeight.bold : FontWeight.normal,
                color: (isCompleted || isActive) ? AppColors.primary : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

