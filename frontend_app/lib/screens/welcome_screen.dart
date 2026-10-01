import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/login_panel.dart';

// Màn chào lần đầu mở app (BRD FR-6.1, FR-7): đăng nhập là tuỳ chọn — "Dùng ngay" vào thẳng Onboarding. Đăng nhập
// xong MainShell tự chuyển sang Onboarding (AuthProvider.showWelcome thành false).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.restaurant_menu, size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SmartFit AI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thực đơn món Việt và bài tập tại nhà cho 3 ngày, tự điều chỉnh theo cảm nhận của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Đăng nhập để xem lại các kế hoạch cũ trên mọi thiết bị.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 12),
                    LoginPanel(onSignedIn: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Dùng ngay, không cần đăng nhập'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Không đăng nhập: kế hoạch chỉ lưu trên máy này. Bạn có thể đăng nhập sau ở tab Cá nhân.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
