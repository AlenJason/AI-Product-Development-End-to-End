import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/google_auth.dart';
import '../theme/app_colors.dart';

// Bảng đăng nhập mở từ tab Cá nhân, Lịch sử, lỗi 401 (giai đoạn 8). Route khôi phục được (#35) như bảng feedback.
// Trả `true` khi đã đăng nhập.
@pragma('vm:entry-point')
Route<bool?> loginSheetRoute(BuildContext context, Object? arguments) => ModalBottomSheetRoute<bool?>(
  builder: (context) => const LoginSheet(),
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
);

class LoginSheet extends StatelessWidget {
  const LoginSheet({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    // Bàn phím mở (ô email demo) → đẩy bảng lên.
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Đăng nhập',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lưu kế hoạch vào lịch sử để xem lại trên mọi thiết bị. Hồ sơ sức khoẻ vẫn chỉ nằm trên máy này.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            LoginPanel(onSignedIn: () => Navigator.pop(context, true)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Để sau')),
          ],
        ),
      ),
    ),
  );
}

// Nút đăng nhập theo chế độ của backend (quyết định Q1): hỏi `/health` khi mở — `mock` → ô email "Đăng nhập demo",
// `google` → nút Google (Android, macOS: hộp chọn tài khoản; web: nút do Google vẽ; Windows: chưa hỗ trợ — Q3).
// Dùng ở màn chào và trong [LoginSheet]. Email đang gõ lưu tạm (#35), không ghi xuống máy.
class LoginPanel extends StatefulWidget {
  const LoginPanel({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<LoginPanel> createState() => _LoginPanelState();
}

class _LoginPanelState extends State<LoginPanel> with RestorationMixin {
  final _email = RestorableTextEditingController();
  late Future<LoginMode> _mode;
  StreamSubscription<String>? _webTokens;
  bool _sending = false;
  String? _error;

  @override
  String get restorationId => 'login';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) => registerForRestoration(_email, 'email');

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _mode = auth.loginMode();
    if (auth.google.support == GoogleAuthSupport.button) {
      _webTokens = auth.google.webTokens.listen(
        (token) => _run(() async {
          await auth.signIn(token);
          return true;
        }),
        onError: (Object error) {
          if (mounted && error is GoogleAuthException) setState(() => _error = error.message);
        },
      );
    }
  }

  @override
  void dispose() {
    unawaited(_webTokens?.cancel());
    _email.dispose();
    super.dispose();
  }

  // `action` trả false khi người dùng tự huỷ (đóng hộp chọn tài khoản) — không báo lỗi.
  Future<void> _run(Future<bool> Function() action) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    String? error;
    var signedIn = false;
    try {
      signedIn = await action();
    } on UnauthorizedException {
      // 401 lúc đăng nhập: server không nhận id_token này — không phải "phiên hết hạn".
      error = 'Máy chủ không chấp nhận lần đăng nhập này. Vui lòng thử lại.';
    } on ApiException catch (failure) {
      error = failure.message;
    } on GoogleAuthException catch (failure) {
      error = failure.message;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
    if (signedIn) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LoginMode>(
    future: _mode,
    builder: (context, snapshot) {
      if (snapshot.hasError) return _modeFailed(snapshot.error);
      final mode = snapshot.data;
      if (mode == null) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Center(child: CircularProgressIndicator(color: AppColors.primaryBright)),
        );
      }
      final error = _error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...switch (mode) {
            LoginMode.demo => _demo(),
            LoginMode.google => _google(),
          },
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
          ],
        ],
      );
    },
  );

  Widget _modeFailed(Object? error) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        error is ApiException ? error.message : const ServerException().message,
        style: const TextStyle(fontSize: 13, color: AppColors.danger),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() {
            _mode = context.read<AuthProvider>().loginMode();
          }),
          child: const Text('Thử lại'),
        ),
      ),
    ],
  );

  List<Widget> _demo() => [
    const Text(
      'Chế độ demo — không cần tài khoản Google. Nhập một email bất kỳ để có lịch sử kế hoạch riêng.',
      style: TextStyle(fontSize: 12, color: AppColors.muted),
    ),
    const SizedBox(height: 10),
    ListenableBuilder(
      listenable: _email.value,
      builder: (context, _) {
        final valid = AuthProvider.validDemoEmail(_email.value.text);
        void submit() => _run(() async {
          await context.read<AuthProvider>().signInDemo(_email.value.text);
          return true;
        });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email.value,
              enabled: !_sending,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: valid ? (_) => submit() : null,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'ten@example.com',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            _primaryButton(label: 'Đăng nhập demo', onPressed: valid ? submit : null),
          ],
        );
      },
    ),
  ];

  List<Widget> _google() {
    final auth = context.read<AuthProvider>();
    return switch (auth.google.support) {
      GoogleAuthSupport.interactive => [
        _primaryButton(label: 'Đăng nhập với Google', icon: Icons.login, onPressed: () => _run(auth.signInWithGoogle)),
      ],
      GoogleAuthSupport.button => [Center(child: _sending ? const CircularProgressIndicator() : auth.google.button())],
      GoogleAuthSupport.unsupported => [
        const _Note('Đăng nhập Google chưa hỗ trợ trên Windows — bạn vẫn dùng đầy đủ tính năng, trừ lịch sử kế hoạch.'),
      ],
      GoogleAuthSupport.notConfigured => [
        const _Note(
          'Bản app này chưa được cấu hình đăng nhập Google — bạn vẫn dùng đầy đủ tính năng, trừ lịch sử kế hoạch.',
        ),
      ],
    };
  }

  Widget _primaryButton({required String label, IconData? icon, VoidCallback? onPressed}) => ElevatedButton.icon(
    onPressed: _sending ? null : onPressed,
    icon: _sending
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon ?? Icons.person_outline, size: 18),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryBright,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.heading)),
  );
}

// Dải nhắc khi dùng như khách (quyết định Q6): dữ liệu chỉ nằm trên máy này — tab Cá nhân và tab Lịch sử.
class GuestBanner extends StatelessWidget {
  const GuestBanner({super.key, required this.onSignIn, this.expired = false});

  final VoidCallback onSignIn;
  // Vừa bị đăng xuất vì server trả 401 (token hết hạn, tài khoản đã xoá).
  final bool expired;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.warningBorder),
    ),
    child: Row(
      children: [
        const Icon(Icons.phone_android, color: AppColors.warning),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            expired
                ? 'Phiên đăng nhập đã hết hạn. Kế hoạch mới chỉ lưu trên máy này tới khi bạn đăng nhập lại.'
                : 'Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.',
            style: const TextStyle(fontSize: 13, color: AppColors.warning),
          ),
        ),
        TextButton(onPressed: onSignIn, child: Text(expired ? 'Đăng nhập lại' : 'Đăng nhập')),
      ],
    ),
  );
}
