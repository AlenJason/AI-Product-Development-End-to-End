import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import 'ui_kit.dart';

/// Mở bảng Đăng nhập / Đăng ký bằng email và mật khẩu.
/// Trả về `true` nếu xác thực thành công.
Future<bool> startAuthSignIn(
  BuildContext context, {
  bool initialRegister = false,
}) async {
  final auth = context.read<AuthProvider?>();
  if (auth == null) return false;
  auth.clearError();
  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 430),
    backgroundColor: Colors.transparent,
    builder: (_) => PasswordAuthSheet(initialRegister: initialRegister),
  );
  return signedIn == true;
}

Future<bool> showChangePasswordSheet(BuildContext context) async {
  final auth = context.read<AuthProvider?>();
  if (auth == null || !auth.isSignedIn) return false;
  auth.clearError();
  final changed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 430),
    backgroundColor: Colors.transparent,
    builder: (_) => const ChangePasswordSheet(),
  );
  return changed == true;
}

class PasswordAuthSheet extends StatefulWidget {
  const PasswordAuthSheet({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  State<PasswordAuthSheet> createState() => _PasswordAuthSheetState();
}

class _PasswordAuthSheetState extends State<PasswordAuthSheet> {
  late bool _isRegister = widget.initialRegister;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _localError;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _switchMode(bool register) {
    if (_isRegister == register) return;
    context.read<AuthProvider>().clearError();
    setState(() {
      _isRegister = register;
      _localError = null;
    });
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    setState(() => _localError = null);

    bool ok;
    if (_isRegister) {
      if (_password.text != _confirmPassword.text) {
        setState(() => _localError = 'Mật khẩu xác nhận không khớp.');
        return;
      }
      ok = await auth.register(
        email: _email.text,
        name: _name.text,
        password: _password.text,
      );
    } else {
      ok = await auth.loginWithPassword(
        email: _email.text,
        password: _password.text,
      );
    }
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final errorMessage = _localError ?? auth.error;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(22, 18, 22, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTab(
                      key: const Key('auth-tab-login'),
                      label: 'Đăng nhập',
                      selected: !_isRegister,
                      onTap: auth.busy ? null : () => _switchMode(false),
                    ),
                  ),
                  Expanded(
                    child: _ModeTab(
                      key: const Key('auth-tab-register'),
                      label: 'Đăng ký',
                      selected: _isRegister,
                      onTap: auth.busy ? null : () => _switchMode(true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRegister ? 'Tạo tài khoản mới' : 'Đăng nhập tài khoản',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 4),
            Text(
              _isRegister
                  ? 'Lưu tài khoản và lịch sử kế hoạch của bạn vào cơ sở dữ liệu.'
                  : 'Đăng nhập bằng email và mật khẩu đã đăng ký.',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_isRegister) ...[
              TextField(
                key: const Key('auth-name-input'),
                controller: _name,
                enabled: !auth.busy,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _localError = null),
                decoration: const InputDecoration(
                  labelText: 'Họ và tên',
                  hintText: 'Nguyễn Công Minh',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('auth-email-input'),
              controller: _email,
              enabled: !auth.busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                auth.clearError();
                if (_localError != null) setState(() => _localError = null);
              },
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'minh@vku.edu.vn',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('auth-password-input'),
              controller: _password,
              enabled: !auth.busy,
              obscureText: _obscurePassword,
              textInputAction:
                  _isRegister ? TextInputAction.next : TextInputAction.done,
              onChanged: (_) {
                auth.clearError();
                if (_localError != null) setState(() => _localError = null);
              },
              onSubmitted: (_) => (_isRegister || auth.busy) ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                hintText: _isRegister ? 'Tối thiểu 6 ký tự' : 'Nhập mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            if (_isRegister) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('auth-confirm-password-input'),
                controller: _confirmPassword,
                enabled: !auth.busy,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_localError != null) setState(() => _localError = null);
                },
                onSubmitted: (_) => auth.busy ? null : _submit(),
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu',
                  hintText: 'Nhập lại mật khẩu',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              NoticePanel(message: errorMessage, error: true),
            ],
            const SizedBox(height: 16),
            GradientButton(
              key: const Key('auth-submit-button'),
              label: auth.busy
                  ? (_isRegister ? 'Đang đăng ký…' : 'Đang đăng nhập…')
                  : (_isRegister ? 'Đăng ký' : 'Đăng nhập'),
              icon: _isRegister ? Icons.person_add_alt_1 : Icons.login,
              onPressed: auth.busy ? null : _submit,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: auth.busy ? null : () => Navigator.pop(context, false),
              child: const Text('Bỏ qua, dùng chế độ khách'),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNext = true;
  String? _localError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    auth.clearError();
    setState(() => _localError = null);

    if (_next.text != _confirm.text) {
      setState(() => _localError = 'Mật khẩu mới xác nhận không khớp.');
      return;
    }

    final ok = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final errorMessage = _localError ?? auth.error;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(22, 18, 22, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Đổi mật khẩu', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Nhập mật khẩu hiện tại và mật khẩu mới (tối thiểu 6 ký tự).',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('change-current-password-input'),
              controller: _current,
              enabled: !auth.busy,
              obscureText: _obscureCurrent,
              textInputAction: TextInputAction.next,
              onChanged: (_) => auth.clearError(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('change-new-password-input'),
              controller: _next,
              enabled: !auth.busy,
              obscureText: _obscureNext,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                auth.clearError();
                if (_localError != null) setState(() => _localError = null);
              },
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                hintText: 'Tối thiểu 6 ký tự',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscureNext = !_obscureNext),
                  icon: Icon(
                    _obscureNext
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('change-confirm-password-input'),
              controller: _confirm,
              enabled: !auth.busy,
              obscureText: _obscureNext,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_localError != null) setState(() => _localError = null);
              },
              onSubmitted: (_) => auth.busy ? null : _submit(),
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                prefixIcon: Icon(Icons.check_circle_outline),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              NoticePanel(message: errorMessage, error: true),
            ],
            const SizedBox(height: 16),
            GradientButton(
              key: const Key('change-password-submit'),
              label: auth.busy ? 'Đang cập nhật…' : 'Lưu mật khẩu mới',
              icon: Icons.save_outlined,
              onPressed: auth.busy ? null : _submit,
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: auth.busy ? null : () => Navigator.pop(context, false),
              child: const Text('Huỷ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? AppColors.primaryDark : AppColors.muted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Thông báo khi server trả 401 (JWT hết hạn hoặc tài khoản bị xoá) kèm nút đăng nhập lại.
class SessionExpiredBanner extends StatelessWidget {
  const SessionExpiredBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider?>();
    if (auth == null || !auth.sessionExpired || auth.isSignedIn) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SurfacePanel(
        color: AppColors.warningSoft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_clock_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tiếp tục lưu lịch sử kế hoạch.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: auth.busy ? null : auth.dismissSessionExpired,
                  child: const Text('Để sau'),
                ),
                ElevatedButton(
                  key: const Key('relogin-button'),
                  onPressed: auth.busy ? null : () => startAuthSignIn(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Đăng nhập lại'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
