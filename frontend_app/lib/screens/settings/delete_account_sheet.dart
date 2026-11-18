import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/ui_kit.dart';

class DeleteAccountSheet extends StatefulWidget {
  const DeleteAccountSheet({super.key});

  @override
  State<DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<DeleteAccountSheet> {
  String? _error;
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final auth = context.read<AuthProvider?>();
    if (auth == null || _deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await auth.deleteAccount();
      if (!mounted) return;
      final hasPlan = context.read<PlanProvider?>()?.hasPlan ?? false;
      if (hasPlan) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã xoá tài khoản và lịch sử trên máy chủ. Bạn vẫn có thể dùng tiếp ở chế độ khách.',
            ),
          ),
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.welcome,
          (route) => false,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = auth.error ?? 'Không thể xoá tài khoản. Vui lòng thử lại.';
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
                size: 28,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Xóa tài khoản?',
              style: AppTextStyles.h1.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'Tài khoản và toàn bộ lịch sử kế hoạch trên máy chủ sẽ bị xóa vĩnh viễn. Thao tác này không thể hoàn tác.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (_error case final String err) ...[
              const SizedBox(height: 16),
              NoticePanel(message: err, error: true),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('confirm-delete-account-button'),
                onPressed: _deleting ? null : _confirmDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEF2F2),
                  foregroundColor: AppColors.danger,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                  ),
                ),
                child: Text(
                  _deleting ? 'Đang xóa tài khoản…' : 'Xóa tài khoản',
                  style: AppTextStyles.h3.copyWith(color: AppColors.danger),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _deleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Huỷ', style: AppTextStyles.h3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
