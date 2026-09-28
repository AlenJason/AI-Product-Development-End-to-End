import 'package:flutter/material.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/outline_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySoft,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // Header / Logo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                      
                      const Spacer(),
                      
                      // Placeholder for Character Image
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.accessibility_new, size: 120, color: AppColors.primary),
                            Positioned(
                              left: 0,
                              top: 60,
                              child: _buildFloatingCard(Icons.favorite, 'Ổn định', 'Nhịp tim'),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 60,
                              child: _buildFloatingCard(Icons.local_fire_department, '1.624', 'kcal/ngày'),
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      
                      // Texts & Buttons
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khoẻ hơn mỗi ngày,\ntheo cách của bạn.',
                              style: AppTextStyles.h1.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Kế hoạch ăn uống và tập luyện thích ứng, vừa túi tiền và dành riêng cho bạn.',
                              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted),
                            ),
                            const SizedBox(height: 32),
                            PrimaryButton(
                              text: 'Bắt đầu ngay',
                              icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.onboardingBasicInfo);
                              },
                            ),
                            const SizedBox(height: 16),
                            OutlineButton(
                              text: 'Đăng nhập với Google',
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.onboardingBasicInfo);
                              },
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: Text(
                                'Bạn có thể sử dụng SmartFit mà không cần đăng nhập.',
                                style: AppTextStyles.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildFloatingCard(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}


