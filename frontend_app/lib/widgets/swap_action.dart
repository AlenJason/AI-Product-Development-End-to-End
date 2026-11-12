import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/routes.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'ui_kit.dart';

/// The server chooses the replacement; no local candidate list or invented IDs.
class SwapAction extends StatefulWidget {
  const SwapAction({super.key, required this.id, required this.meal});
  final String id;
  final bool meal;
  @override
  State<SwapAction> createState() => _SwapActionState();
}

class _SwapActionState extends State<SwapAction> {
  String? _error;
  bool _outdated = false;
  bool _pending = false;
  Future<void> _swap() async {
    final plans = context.read<PlanProvider>();
    if (_pending || plans.busy) return;
    setState(() {
      _pending = true;
      _error = null;
      _outdated = false;
    });
    try {
      if (widget.meal) {
        await plans.swapMeal(widget.id);
      } else {
        await plans.swapExercise(widget.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.meal
                ? 'Đã cập nhật món ăn và danh sách đi chợ.'
                : 'Đã cập nhật bài tập.',
          ),
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _outdated = error is PlanOutdatedException;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể lưu thay đổi. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final busy = plans.busy || _pending;
    final meals = plans.plan?.days
        .expand((d) => d.meals)
        .where((m) => m.mealId == widget.id);
    final exercises = plans.plan?.days
        .expand((d) => d.workout.exercises)
        .where((e) => e.exerciseId == widget.id);
    final currentMeal = meals == null || meals.isEmpty ? null : meals.first;
    final currentExercise = exercises == null || exercises.isEmpty
        ? null
        : exercises.first;
    final title = widget.meal ? currentMeal?.name : currentExercise?.name;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ToneIcon(icon: Icons.auto_awesome),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.meal ? 'Đổi món ăn' : 'Đổi bài tập',
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.meal
                              ? 'Món ăn phù hợp với hồ sơ và mục tiêu của bạn.'
                              : 'Động tác thay thế theo hồ sơ của kế hoạch.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SurfacePanel(
                color: AppColors.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HIỆN TẠI',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title ?? 'Không tìm thấy nội dung trong kế hoạch.',
                      style: AppTextStyles.label,
                    ),
                    if (currentMeal != null)
                      Text(
                        '${currentMeal.calories} kcal · ${currentMeal.portion}',
                        style: AppTextStyles.bodySmall,
                      ),
                    if (currentExercise != null)
                      Text(
                        '${currentExercise.sets} hiệp · ${currentExercise.repsOrDuration}',
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              NoticePanel(
                message: 'Máy chủ chọn phương án phù hợp với hồ sơ của kế hoạch. Kết quả sẽ được cập nhật sau khi bạn xác nhận.',
                success: true,
                icon: Icons.swap_horiz,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                NoticePanel(message: _error!, error: !_outdated),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_outdated)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GradientButton(
                    onPressed: busy
                        ? null
                        : () {
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator.pushNamed(AppRoutes.onboardingBasicInfo);
                          },
                    label: 'Tạo kế hoạch mới',
                  ),
                ),
              const SizedBox(height: 18),
              GradientButton(
                onPressed: busy || _outdated || title == null ? null : _swap,
                label: _error == null ? 'Xác nhận đổi' : 'Thử lại',
                icon: Icons.swap_horiz,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
