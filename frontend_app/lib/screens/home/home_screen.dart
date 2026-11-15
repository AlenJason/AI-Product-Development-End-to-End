import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/api/account.dart';
import '../../models/plan_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/auth_sheet.dart';
import '../../widgets/plan_content.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/plan_status.dart';
import '../profile/edit_profile_sheet.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Widget _buildHeader(BuildContext context, AuthUser? user, DateTime? date) {
    final displayName = user?.name.trim().isNotEmpty == true ? user!.name : 'bạn';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                date == null
                    ? 'KẾ HOẠCH CỦA BẠN'
                    : vietnameseDate(date).toUpperCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Chào $displayName',
                      style: AppTextStyles.h1.copyWith(fontSize: 26),
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.waving_hand_outlined,
                    color: AppColors.fat,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Hôm nay mình cùng tiến một bước nhé.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          key: const Key('home-header-edit-profile'),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            constraints: const BoxConstraints(maxWidth: 430),
            builder: (_) => const EditProfileSheet(),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_note_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  'Sửa hồ sơ',
                  style: AppTextStyles.label.copyWith(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>(), plan = plans.plan;
    final auth = context.watch<AuthProvider?>();
    final user = auth?.user;

    if (plan == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
          children: [
            _buildHeader(context, user, null),
            const SizedBox(height: 24),
            const SessionExpiredBanner(),
            SurfacePanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ToneIcon(icon: Icons.calendar_month_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text('Chưa có kế hoạch hoạt động', textAlign: TextAlign.center, style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  Text(
                    'Bạn có thể chỉnh sửa thông tin hồ sơ hoặc tạo kế hoạch dinh dưỡng & tập luyện 3 ngày mới bằng AI.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  GradientButton(
                    key: const Key('home-create-plan-button'),
                    label: 'Tạo kế hoạch 3 ngày mới',
                    icon: Icons.auto_awesome,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.onboardingBasicInfo,
                      arguments: plans.editableProfile,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('home-edit-profile-button'),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        useSafeArea: true,
                        isScrollControlled: true,
                        constraints: const BoxConstraints(maxWidth: 430),
                        builder: (_) => const EditProfileSheet(),
                      ),
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('Chỉnh sửa hồ sơ thể trạng'),
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        key: const Key('home-history-button'),
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.history),
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('Xem lịch sử kế hoạch đã lưu'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final matches = plan.days.where((d) => d.dayNumber == plans.todayNumber);
    final day = matches.isEmpty ? null : matches.first;
    final date = day == null ? null : plans.schedule?.dateOfDay(day.dayNumber);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        children: [
          _buildHeader(context, user, date),
          const SizedBox(height: 24),
          const SessionExpiredBanner(),
          const PlanStatus(),
          if (day == null)
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.threeDayPlan),
              child: const Text('Xem kế hoạch 3 ngày'),
            )
          else ...[
            EnergySummary(day: day, target: plan.dailyTarget, dashboard: true),
            const SizedBox(height: 14),
            PlanNotice(plan: plan),
            SectionTitle(
              title: 'Bữa ăn hôm nay',
              subtitle:
                  '${day.meals.length} bữa · ${number(day.meals.fold<num>(0, (sum, m) => sum + m.calories))} kcal',
              action: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.threeDayPlan),
                child: const Text('Xem kế hoạch'),
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final meal in day.meals)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: (constraints.maxWidth * .86)
                              .clamp(240, 320)
                              .toDouble(),
                          child: MealCard(meal: meal),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SectionTitle(title: 'Buổi tập hôm nay'),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  const WorkoutArtwork(),
                  SurfacePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(day.workout.title, style: AppTextStyles.h3),
                        const SizedBox(height: 8),
                        Text(
                          '${day.workout.durationMinutes} phút · ${day.workout.exercises.length} bài tập',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        if (day.workout.exercises.isNotEmpty)
                          GradientButton(
                            label: 'Xem buổi tập',
                            icon: Icons.bolt,
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/workout_detail',
                              arguments: day.workout.exercises.first.exerciseId,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (final (index, exercise) in day.workout.exercises.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ExerciseCard(exercise: exercise, index: index + 1),
              ),
          ],
        ],
      ),
    );
  }
}
