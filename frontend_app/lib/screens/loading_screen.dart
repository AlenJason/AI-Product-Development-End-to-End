import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../theme/app_colors.dart';

// Chờ backend tạo plan (NFR-1): chế độ giả lập trả ngay, có Gemini thường 8–15 s, tối đa khoảng 40 s. Câu chờ
// không bịa số liệu. [error] khác null → báo lỗi và cho thử lại (NFR-2).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({
    super.key,
    this.error,
    required this.onRetry,
    required this.onEditProfile,
    this.onBack,
    this.onSignIn,
  });

  final ApiException? error;
  final VoidCallback onRetry;
  final VoidCallback onEditProfile;
  // Có plan cũ thì cho quay về plan đó thay vì kẹt ở màn lỗi.
  final VoidCallback? onBack;
  // Mở bảng đăng nhập khi lỗi là 401 (phiên hết hạn — giai đoạn 8).
  final VoidCallback? onSignIn;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const slowAfter = Duration(seconds: 15);

  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(slowAfter, () => setState(() => _slow = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 401 → nút chính là "Đăng nhập lại" (đăng nhập xong MainShell tạo tiếp); "Thử lại" lúc này là tạo như khách,
  // plan không vào lịch sử.
  VoidCallback? get _signIn => widget.error is UnauthorizedException ? widget.onSignIn : null;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: error == null ? _waiting() : _failed(error)),
          ),
        ),
      ),
    );
  }

  Widget _waiting() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(color: AppColors.primaryBright)),
      const SizedBox(height: 24),
      const Text(
        'Đang lập kế hoạch 3 ngày cho bạn',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      const SizedBox(height: 8),
      Text(
        _slow
            ? 'AI đang chọn món và bài tập, có thể mất tới 40 giây. Vui lòng không tắt ứng dụng.'
            : 'Tính mục tiêu calo, chọn món Việt và bài tập tại nhà phù hợp với bạn…',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  );

  Widget _failed(ApiException error) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
      const SizedBox(height: 16),
      const Text(
        'Chưa tạo được kế hoạch',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      const SizedBox(height: 8),
      Text(
        error.message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _signIn ?? widget.onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBright,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            _signIn == null ? 'Thử lại' : 'Đăng nhập lại',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (_signIn != null) TextButton(onPressed: widget.onRetry, child: const Text('Tạo không cần đăng nhập')),
      TextButton(onPressed: widget.onEditProfile, child: const Text('Sửa hồ sơ')),
      if (widget.onBack != null) TextButton(onPressed: widget.onBack, child: const Text('Về kế hoạch đang có')),
    ],
  );
}
