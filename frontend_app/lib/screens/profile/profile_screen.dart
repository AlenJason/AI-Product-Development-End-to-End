import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/api/codes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>(),
        profile = plans.editableProfile;
    final auth = context.watch<AuthProvider?>();
    final user = auth?.user;
    if (profile == null) {
      return const SafeArea(
        child: PlanEmpty(message: 'Chưa có hồ sơ được lưu.'),
      );
    }
    final bmi = profile.heightCm > 0
        ? profile.weightKg /
              ((profile.heightCm / 100) * (profile.heightCm / 100))
        : null;
    final goal = switch (profile.goal) {
      Goal.cut => 'Giảm mỡ',
      Goal.bulk => 'Tăng cơ',
      Goal.maintain => 'Duy trì',
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        children: [
          const ScreenHeading(
            title: 'Cá nhân',
            subtitle: 'Thông tin và tùy chỉnh của bạn',
          ),
          const SizedBox(height: 22),
          const SessionExpiredBanner(),
          if (auth?.error case final String authError)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NoticePanel(message: authError, error: true),
            ),
          SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const ToneIcon(icon: Icons.person_outline, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Hồ sơ trên thiết bị',
                            style: AppTextStyles.h4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'Sử dụng SmartFit ở chế độ khách',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                if (auth != null && user == null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('profile-signin-button'),
                    onPressed: auth.busy
                        ? null
                        : () => startAuthSignIn(context),
                    icon: const Icon(Icons.login),
                    label: Text(
                      auth.busy
                          ? 'Đang đăng nhập…'
                          : 'Đăng nhập để lưu lịch sử',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const Key('profile-history-button'),
              onTap: () => Navigator.pushNamed(context, AppRoutes.history),
              leading: const ToneIcon(icon: Icons.history_outlined, size: 42),
              title: Text('Lịch sử kế hoạch', style: AppTextStyles.h4),
              subtitle: Text(
                user != null
                    ? 'Xem lại các kế hoạch đã lưu trên tài khoản'
                    : 'Đăng nhập để đồng bộ và xem kế hoạch cũ',
                style: AppTextStyles.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
            ),
          ),
          if (plans.restoreWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: NoticePanel(message: plans.restoreWarning!),
            ),
          if (plans.hasPendingProfile) ...[
            const SizedBox(height: 14),
            const NoticePanel(
              message: 'Hồ sơ mới đang chờ áp dụng. Kế hoạch và các thao tác đổi món/bài vẫn dùng hồ sơ cũ.',
            ),
            const SizedBox(height: 10),
            GradientButton(
              label: 'Tạo lại theo hồ sơ đã lưu',
              icon: Icons.auto_awesome,
              onPressed: plans.busy
                  ? null
                  : () => Navigator.pushNamed(
                      context,
                      AppRoutes.generatingPlan,
                      arguments: profile,
                    ),
            ),
          ],
          const SectionTitle(title: 'Chỉ số cơ thể'),
          SurfacePanel(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final metric in [
                  ('${profile.age}', 'Tuổi'),
                  (profile.gender == Gender.female ? 'Nữ' : 'Nam', 'Giới tính'),
                  ('${number(profile.heightCm)} cm', 'Chiều cao'),
                  ('${number(profile.weightKg)} kg', 'Cân nặng'),
                  (bmi == null ? '—' : number(bmi), 'BMI'),
                ])
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.panel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(metric.$1, style: AppTextStyles.label),
                        Text(metric.$2, style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionTitle(title: 'Mục tiêu'),
          SurfacePanel(
            child: Row(
              children: [
                ToneIcon(
                  icon: profile.goal == Goal.cut
                      ? Icons.trending_down
                      : Icons.trending_up,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal, style: AppTextStyles.h4),
                      Text(switch (profile.activityLevel) {
                        ActivityLevel.sedentary => 'Ít vận động',
                        ActivityLevel.light => 'Vận động nhẹ',
                        ActivityLevel.active => 'Vận động nhiều',
                      }, style: AppTextStyles.bodySmall),
                      if (!plans.hasPendingProfile && plans.plan != null)
                        Text(
                          '${number(plans.plan!.dailyTarget.targetCalories)} kcal/ngày',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: 'SmartFit cần lưu ý'),
          SurfacePanel(
            child: Column(
              children: [
                for (final entry in [
                  ('Dị ứng', profile.restrictions.allergies),
                  ('Chấn thương', profile.restrictions.injuries),
                  ('Sức khoẻ', profile.restrictions.healthConditions),
                  (
                    'Mang thai / cho con bú',
                    profile.pregnantOrBreastfeeding ? 'Có' : 'Không',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(entry.$1, style: AppTextStyles.bodySmall),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.$2.isEmpty ? 'Không có' : entry.$2,
                            style: AppTextStyles.label,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Chỉnh sửa hồ sơ',
            icon: Icons.edit_outlined,
            onPressed: plans.busy
                ? null
                : () => showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    constraints: const BoxConstraints(maxWidth: 430),
                    builder: (_) => const EditProfileSheet(),
                  ),
          ),
        ],
      ),
    );
  }
}
