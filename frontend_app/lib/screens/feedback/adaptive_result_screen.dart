import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/common/primary_button.dart';

class AdaptiveResultScreen extends StatelessWidget {
  final bool intensityChanged;
  final List<String> bodyStatus;

  const AdaptiveResultScreen({
    super.key,
    required this.intensityChanged,
    required this.bodyStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              _buildSuccessIcon(),
              const SizedBox(height: 32),
              Text(
                'Kế hoạch đã được\nđiều chỉnh',
                style: AppTextStyles.h1.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'SmartFit đã cập nhật ngày tiếp theo dựa trên phản hồi của bạn.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              _buildReasonBox(),
              const Spacer(),
              PrimaryButton(
                text: 'Xem kế hoạch mới',
                icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                onPressed: () {
                  // Go to plan tab (index 1) in main screen
                  Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 1);
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Go to home tab (index 0)
                  Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false, arguments: 0);
                },
                child: Text(
                  'Về trang Hôm nay',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: Color(0xFF22C55E),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ),
        Positioned(
          top: 0,
          left: 0,
          child: const Icon(Icons.auto_awesome, color: Color(0xFF22C55E), size: 24),
        ),
        Positioned(
          bottom: 20,
          right: -10,
          child: const Icon(Icons.auto_awesome, color: Color(0xFF22C55E), size: 16),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center, color: Colors.blueAccent),
            ),
            title: Text('LUYỆN TẬP', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
            subtitle: Text(intensityChanged ? 'Giảm nhẹ cường độ' : 'Giữ nguyên cường độ', style: AppTextStyles.h3),
            trailing: Text(intensityChanged ? '-15%' : '0%', style: AppTextStyles.h3.copyWith(color: const Color(0xFF16A34A))),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.eco_outlined, color: Color(0xFF16A34A)),
            ),
            title: Text('DINH DƯỠNG', style: AppTextStyles.label.copyWith(color: AppColors.muted)),
            subtitle: Text('Giữ mức năng lượng', style: AppTextStyles.h3),
            trailing: Text('1.624', style: AppTextStyles.h3.copyWith(color: const Color(0xFF16A34A))),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonBox() {
    final status = bodyStatus.isNotEmpty ? bodyStatus.first : 'bình thường';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF), // Light purple
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vì sao có thay đổi này?', style: AppTextStyles.h3.copyWith(color: const Color(0xFF7C3AED))),
                const SizedBox(height: 4),
                Text(
                  intensityChanged
                    ? 'Bạn thấy buổi tập rất mệt hoặc có cảm giác $status. Ngày mai sẽ ưu tiên phục hồi chủ động.'
                    : 'Phản hồi của bạn cho thấy tiến độ tốt. Kế hoạch ngày mai sẽ được duy trì.',
                  style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF5B21B6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

