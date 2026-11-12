import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/ui_kit.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleSignIn(BuildContext context) async {
    final ok = await startAuthSignIn(context);
    if (!ok || !context.mounted) return;
    final hasPlan = context.read<PlanProvider?>()?.hasPlan ?? false;
    Navigator.pushNamed(
      context,
      hasPlan ? AppRoutes.home : AppRoutes.onboardingBasicInfo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    final plans = context.watch<PlanProvider?>();
    final isBusy = auth?.busy ?? false;
    final user = auth?.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFFBF3), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            children: [
              if (plans?.restoreWarning case final String warning)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NoticePanel(message: warning),
                ),
              const SessionExpiredBanner(),
              if (auth?.error case final String authError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: NoticePanel(message: authError, error: true),
                ),
              const BrandLogo(),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.08,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _WelcomeIllustration()),
                    ),
                    Positioned(
                      left: 0,
                      top: 70,
                      child: _floating(
                        Icons.favorite_border,
                        'Bền bỉ',
                        'Mỗi ngày',
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 34,
                      child: _floating(
                        Icons.local_fire_department_outlined,
                        'Cân bằng',
                        'Dinh dưỡng',
                      ),
                    ),
                  ],
                ),
              ),
              Text.rich(
                TextSpan(
                  text: 'Khoẻ hơn mỗi ngày,\n',
                  style: AppTextStyles.h1.copyWith(fontSize: 34),
                  children: [
                    const TextSpan(
                      text: 'theo cách của bạn.',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Kế hoạch ăn uống và tập luyện thích ứng, vừa túi tiền và dành riêng cho bạn.',
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (user != null) ...[
                SurfacePanel(
                  child: Row(
                    children: [
                      const ToneIcon(icon: Icons.verified_user_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name, style: AppTextStyles.h4),
                            Text(user.email, style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: isBusy ? null : () => auth?.signOut(),
                        child: const Text('Đăng xuất'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: (plans?.hasPlan ?? false)
                      ? 'Mở Dashboard'
                      : 'Tiếp tục thiết lập hồ sơ',
                  icon: Icons.arrow_forward,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    (plans?.hasPlan ?? false)
                        ? AppRoutes.home
                        : AppRoutes.onboardingBasicInfo,
                  ),
                ),
              ] else ...[
                GradientButton(
                  key: const Key('welcome-start-button'),
                  label: 'Bắt đầu ngay',
                  icon: Icons.arrow_forward,
                  onPressed: isBusy
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          AppRoutes.onboardingBasicInfo,
                        ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('welcome-signin-button'),
                  onPressed: isBusy ? null : () => _handleSignIn(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isBusy) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Icon(Icons.login),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          isBusy ? 'Đang đăng nhập…' : 'Đăng nhập',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('welcome-skip-button'),
                  onPressed: isBusy
                      ? null
                      : () => Navigator.pushNamed(
                          context,
                          AppRoutes.onboardingBasicInfo,
                        ),
                  child: const Text('Bỏ qua đăng nhập, dùng chế độ khách'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  Widget _floating(IconData icon, String title, String subtitle) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .07),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.label.copyWith(fontSize: 12)),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Native drawing translated from the CSS person in the supplied export.
class _WelcomeIllustration extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 340, size.height / 320);
    final fill = Paint();
    canvas.drawCircle(
      const Offset(170, 160),
      143,
      fill..color = AppColors.primary.withValues(alpha: .05),
    );
    canvas.drawCircle(
      const Offset(170, 160),
      120,
      fill..color = AppColors.greenTint,
    );
    canvas.drawCircle(
      const Offset(170, 160),
      143,
      Paint()
        ..color = AppColors.greenLight.withValues(alpha: .3)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      const Offset(170, 160),
      98,
      Paint()
        ..color = AppColors.greenLight.withValues(alpha: .2)
        ..style = PaintingStyle.stroke,
    );
    canvas.drawOval(
      const Rect.fromLTWH(83, 283, 174, 13),
      fill..color = AppColors.primary.withValues(alpha: .13),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(146, 60, 45, 53),
        const Radius.circular(24),
      ),
      fill..color = const Color(0xFF2B2B34),
    );
    canvas.drawOval(
      const Rect.fromLTWH(152, 66, 42, 49),
      fill..color = const Color(0xFFF2B68D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(132, 108, 77, 108),
        const Radius.circular(30),
      ),
      fill..color = AppColors.primary,
    );
    final stroke = Paint()
      ..color = const Color(0xFFF2B68D)
      ..strokeWidth = 21
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(131, 128), const Offset(77, 193), stroke);
    canvas.drawLine(const Offset(211, 128), const Offset(272, 184), stroke);
    stroke
      ..color = const Color(0xFF28344A)
      ..strokeWidth = 27;
    canvas.drawLine(const Offset(154, 214), const Offset(136, 295), stroke);
    canvas.drawLine(const Offset(186, 214), const Offset(204, 295), stroke);
    canvas.drawLine(
      const Offset(149, 139),
      const Offset(190, 133),
      Paint()
        ..color = const Color(0xFFBBF7D0)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
