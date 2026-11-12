import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../models/restriction_options.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/progress_header.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/restriction_fields.dart';

class RestrictionsScreen extends StatefulWidget {
  const RestrictionsScreen({super.key});
  @override
  State<RestrictionsScreen> createState() => _RestrictionsScreenState();
}

class _RestrictionsScreenState extends State<RestrictionsScreen> {
  final _other = <RestrictionKind, TextEditingController>{};
  bool _openingPlan = false;
  String? _submitError;
  @override
  void initState() {
    super.initState();
    final form = context.read<OnboardingProvider>();
    for (final kind in RestrictionKind.values) {
      _other[kind] = TextEditingController(text: form.selection(kind).other);
    }
  }

  @override
  void dispose() {
    for (final controller in _other.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_openingPlan) return;
    final form = context.read<OnboardingProvider>();
    try {
      final profile = form.toProfile();
      setState(() {
        _openingPlan = true;
        _submitError = null;
      });
      await Navigator.pushNamed(
        context,
        AppRoutes.generatingPlan,
        arguments: profile,
      );
    } on FormatException {
      if (mounted) {
        setState(
          () => _submitError =
              'Hồ sơ chưa hợp lệ. Hãy kiểm tra lại các bước trước.',
        );
      }
    } finally {
      if (mounted) setState(() => _openingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<OnboardingProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ProgressHeader(
              currentStep: 3,
              totalSteps: 3,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeading(
                      title: 'Hạn chế và sức khoẻ',
                      subtitle: 'Có điều gì SmartFit cần lưu ý? Thông tin này giúp gợi ý an toàn hơn.',
                      icon: Icons.shield_outlined,
                    ),
                    const SizedBox(height: 16),
                    for (final kind in RestrictionKind.values)
                      _section(form, kind),
                    const NoticePanel(
                      message: 'Gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Người có bệnh nền nên hỏi ý kiến bác sĩ.',
                    ),
                    const SizedBox(height: 12),
                    const NoticePanel(
                      message: 'Khi dùng kế hoạch mẫu, máy chủ chỉ lọc dị ứng/chấn thương phổ biến theo từ khoá; chưa điều chỉnh thực đơn theo bệnh nền. Nội dung không nhận ra sẽ có cảnh báo.',
                    ),
                    if (!form.goalsValid)
                      const Text(
                        'Hãy quay lại các bước trước để hoàn thiện hồ sơ.',
                      ),
                    if (_submitError != null) Text(_submitError!),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                text: 'Tạo kế hoạch của tôi',
                onPressed: form.canSubmit && !_openingPlan ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(OnboardingProvider form, RestrictionKind kind) =>
      RestrictionFields(form: form, kind: kind, controller: _other[kind]!);
}
