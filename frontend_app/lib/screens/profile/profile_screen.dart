import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarding = context.watch<OnboardingProvider>();
    final bmi = (onboarding.weightKg / ((onboarding.heightCm / 100) * (onboarding.heightCm / 100))).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cá nhân', style: AppTextStyles.h1.copyWith(fontSize: 28)),
              const SizedBox(height: 8),
              Text('Thông tin và tùy chỉnh của bạn', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
              const SizedBox(height: 24),
              _buildUserCard(context),
              const SizedBox(height: 24),
              _buildBodyMetricsCard(onboarding, bmi),
              const SizedBox(height: 24),
              _buildGoalCard(onboarding),
              const SizedBox(height: 24),
              _buildRestrictionsCard(onboarding),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const EditProfileSheet(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Text('Chỉnh sửa hồ sơ', style: AppTextStyles.h3),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('MN', style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Minh Nguyễn', style: AppTextStyles.h3.copyWith(fontSize: 18)),
                const SizedBox(height: 4),
                Text('minh.nguyen@gmail.com', style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.g_mobiledata, color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 4),
                    Text('Đã kết nối Google', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF22C55E))),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.ink),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMetricsCard(OnboardingProvider data, String bmi) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chỉ số cơ thể', style: AppTextStyles.h2),
          const SizedBox(height: 4),
          Text('Cập nhật hôm nay', style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricBox('${data.age}', 'Tuổi'),
              _buildMetricBox(data.gender, 'Giới tính'),
              _buildMetricBox('${data.heightCm} cm', 'Chiều cao'),
              _buildMetricBox('${data.weightKg} kg', 'Cân nặng'),
              _buildMetricBox(bmi, 'BMI'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.h3.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildGoalCard(OnboardingProvider data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mục tiêu', style: AppTextStyles.h2),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.trending_down, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.goal, style: AppTextStyles.h3),
                    const SizedBox(height: 4),
                    Text('Tiến độ bền vững · 0,3 kg/tuần', style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('Đang theo', style: AppTextStyles.label.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictionsCard(OnboardingProvider data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('SmartFit cần lưu ý', style: AppTextStyles.h2),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildRestrictionRow('Dị ứng', data.allergies.isEmpty ? 'Không có' : data.allergies),
          const Divider(height: 1, color: AppColors.background, indent: 20, endIndent: 20),
          _buildRestrictionRow('Chấn thương', data.injuries.isEmpty ? 'Đau gối' : data.injuries),
          const Divider(height: 1, color: AppColors.background, indent: 20, endIndent: 20),
          _buildRestrictionRow('Sức khoẻ', data.healthConditions.isEmpty ? 'Không có' : data.healthConditions),
        ],
      ),
    );
  }

  Widget _buildRestrictionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted)),
          Text(value, style: AppTextStyles.h3.copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}
