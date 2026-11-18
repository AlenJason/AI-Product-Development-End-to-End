import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/api/profile.dart';
import '../../models/profile_rules.dart';
import '../../providers/plan_provider.dart';
import '../../services/api_exception.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/ui_kit.dart';

class GeneratingPlanScreen extends StatefulWidget {
  const GeneratingPlanScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<GeneratingPlanScreen> createState() => _GeneratingPlanScreenState();
}

class _GeneratingPlanScreenState extends State<GeneratingPlanScreen> {
  bool _requesting = true;
  bool _inFlight = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Provider notifyListeners: bắt đầu sau frame đầu, không thay state trong build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _generate();
    });
  }

  Future<void> _generate() async {
    if (_inFlight) return;
    _inFlight = true;
    setState(() {
      _requesting = true;
      _error = null;
    });
    final plans = context.read<PlanProvider>();
    try {
      final problems = profileProblems(widget.profile);
      if (problems.isNotEmpty) {
        _showError(problems.join('\n'));
        return;
      }
      // generate() bỏ qua khi provider đang bận; không coi request bị bỏ qua là thành công.
      if (plans.busy) {
        setState(() {
          _requesting = false;
          _error = 'Đang xử lý một yêu cầu khác. Vui lòng thử lại sau.';
        });
        return;
      }
      await plans.generate(widget.profile);
      if (!mounted) return;
      // Future chỉ hoàn tất sau khi ApiClient parse và provider lưu plan/profile/schedule.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.threeDayPlan,
        (route) => false,
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (_) {
      // Lỗi lưu trữ không được chuyển sang kết quả mock.
      _showError('Không thể lưu hoặc tạo kế hoạch. Vui lòng thử lại.');
    } finally {
      _inFlight = false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_requesting,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFECFDF3), Colors.white],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
            children: [
              const BrandLogo(compact: true),
              const SizedBox(height: 54),
              if (_requesting) ...[
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.greenTint,
                              width: 10,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 166,
                          height: 166,
                          child: CircularProgressIndicator(
                            key: Key('generate-loading'),
                            strokeWidth: 8,
                            color: AppColors.greenLight,
                            backgroundColor: AppColors.primarySoft,
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: .08),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: AppColors.primary,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'SmartFit đang chuẩn bị kế hoạch cho bạn...',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(fontSize: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  'AI kết hợp dinh dưỡng và vận động phù hợp với hồ sơ của bạn.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 28),
                const NoticePanel(
                  message: 'Đang chờ phản hồi từ máy chủ.',
                  success: true,
                  icon: Icons.cloud_sync_outlined,
                ),
                const SizedBox(height: 20),
                for (final item in [
                  (Icons.restaurant_outlined, 'Dinh dưỡng theo mục tiêu'),
                  (Icons.fitness_center, 'Vận động theo hồ sơ'),
                  (
                    Icons.shopping_basket_outlined,
                    'Danh sách nguyên liệu đồng bộ',
                  ),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Icon(item.$1, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item.$2, style: AppTextStyles.bodySmall),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Vui lòng giữ màn hình mở trong khi tạo kế hoạch.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ] else ...[
                const Center(
                  child: ToneIcon(icon: Icons.cloud_off_outlined, size: 76),
                ),
                const SizedBox(height: 24),
                Text(
                  'Chưa tạo được kế hoạch',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 18),
                NoticePanel(
                  key: const Key('generate-error'),
                  message: _error!,
                  error: true,
                ),
                const SizedBox(height: 24),
                GradientButton(label: 'Thử lại', onPressed: _generate),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sửa hồ sơ'),
                ),
                if (context.watch<PlanProvider>().hasPlan)
                  TextButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (_) => false,
                    ),
                    child: const Text('Về kế hoạch đang có'),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
