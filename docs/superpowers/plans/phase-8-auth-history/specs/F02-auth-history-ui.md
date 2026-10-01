# F02 — Màn chào, bảng đăng nhập, tab Lịch sử, xem lại plan cũ, tài khoản, xử lý 401

## Feature

| Phần | Việc |
|---|---|
| `lib/widgets/login_panel.dart` (mới) | `LoginPanel`: hỏi `loginMode()` khi mở — `mock` → ô email + "Đăng nhập demo" (khoá nút tới khi email hợp lệ; email đang gõ lưu tạm — #35); `google` → theo `GoogleAuth.support`: nút "Đăng nhập với Google" / nút web của Google / "chưa hỗ trợ trên Windows" (Q3) / "chưa được cấu hình". Huỷ → im lặng; lỗi Google → câu tiếng Việt; backend 401 lúc đăng nhập → "Máy chủ không chấp nhận lần đăng nhập này" (không phải "phiên hết hạn"); `/health` lỗi → câu lỗi + "Thử lại". `LoginSheet` + `loginSheetRoute` (route khôi phục được). `GuestBanner` (Q6; biến thể "Phiên đăng nhập đã hết hạn") |
| `lib/screens/welcome_screen.dart` (mới) | Màn chào lần đầu (FR-6.1): `LoginPanel` + "Dùng ngay, không cần đăng nhập" (FR-7) |
| `lib/screens/history_screen.dart` (mới) | Tab "Lịch sử" (FR-7.2): khách → `GuestBanner`; đã đăng nhập → tải mỗi lần mở tab, kéo để tải lại, ngày giờ theo giờ máy, calo mục tiêu, nhãn "Đang dùng"; plan đang dùng không có trong danh sách → ghi chú (Q4); lỗi → "Thử lại"; vừa đăng nhập khi đang mở tab → tự tải |
| `lib/screens/plan_detail_screen.dart` (mới) | Xem lại plan cũ — chỉ xem (P10): 3 tab ngày, `PlanWarnings`, `PlanDayView`; 404 → "Kế hoạch này không còn trong lịch sử" + "Về danh sách" (tải lại danh sách); route khôi phục được |
| `lib/screens/dashboard_screen.dart` | Tách thẻ bữa ăn / buổi tập thành `_MealCard`, `_WorkoutCard` (nút đổi truyền vào), thêm `PlanDayView` (một ngày chỉ xem) và đổi `_Warnings` → `PlanWarnings` để màn chi tiết dùng lại; 401 khi đổi món/bài → SnackBar "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại" (`onSignIn`) |
| `lib/screens/profile_screen.dart` | Khách → `GuestBanner`; đã đăng nhập → thẻ "Tài khoản": tên, email, "Đăng xuất" (plan trên máy giữ), "Xoá tài khoản" (hộp hỏi lại → FR-6.4) |
| `lib/screens/loading_screen.dart` | 401 → nút chính "Đăng nhập lại", thêm "Tạo không cần đăng nhập" |
| `lib/widgets/feedback_sheet.dart` | 401 → "Đăng nhập lại" mở bảng đăng nhập chồng lên, câu trả lời vẫn còn để gửi lại |
| `lib/main.dart` | `HistoryProvider`; màn chào trước Onboarding khi `showWelcome`; tab Lịch sử thay chỗ giữ; `_loginRoute` (`RestorableRouteFuture`) — đăng nhập xong sau 401 lúc tạo plan thì tạo tiếp; `_createPlan()` hỏi khách trước khi thay plan (Q5) — dùng cho Dashboard, tab Cá nhân, 409 của bảng feedback |

**Phát hiện khi lập plan:**

| # | Phát hiện | Xử lý |
|---|---|---|
| P16 | Test bắt được: nút "Thử lại" gọi `setState(() => _mode = …)` — hàm mũi tên trả về `Future` → Flutter ném lỗi "setState() callback argument returned a Future" | Thân hàm dạng khối (`LoginPanel`, `PlanDetailScreen`) |
| P17 | Fixture `history` có đúng `plan_id` của fixture `generate_plan` → plan đang dùng luôn "có trong lịch sử" | Test ghi chú Q4 thay danh sách bằng một plan khác (`responses`) |
| P18 | `HistoryProvider.load()` bị 401: `onUnauthorized` đăng xuất **trước** khi lỗi về tới `catch`, đổi `_userId` → lỗi bị coi là của tài khoản cũ và bỏ | Nhánh riêng `on UnauthorizedException` luôn giữ lỗi (F01) |
| P19 | Khách bấm "Tạo kế hoạch mới" ở bảng feedback (409) giờ bị hỏi lại (Q5) — test cũ của giai đoạn 7 đỏ | Test bấm "Thay kế hoạch" — đúng hành vi mới |
| P20 | Hai file test cũ chưa từng format (`auth_provider_test.dart`, `feedback_sheet_test.dart`) — `dart format` cả file sẽ gộp dòng không liên quan | Chỉ thêm phần mới, không format lại |

## Scope

UI-only:

- `frontend_app/lib/widgets/login_panel.dart`, `lib/screens/welcome_screen.dart`, `history_screen.dart`, `plan_detail_screen.dart` (mới)
- `frontend_app/lib/screens/dashboard_screen.dart`, `profile_screen.dart`, `loading_screen.dart`, `lib/widgets/feedback_sheet.dart`, `lib/main.dart` (sửa)
- `frontend_app/test/widgets/login_panel_test.dart`, `test/screens/history_screen_test.dart` (mới); `test/app_harness.dart`, `test/widget_test.dart`, `test/screens/profile_screen_test.dart`, `test/screens/dashboard_screen_test.dart`, `test/widgets/feedback_sheet_test.dart`, `integration_test/backend_smoke_test.dart` (sửa)

## Implementation

### API Routes

Không có route mới. Thời gian chờ: `/health`, đăng nhập, lịch sử, xoá tài khoản 15 s; tạo plan 60 s (backend dừng Gemini sau 40 s — #15). Màn hình không gọi `ApiClient` trực tiếp — qua `AuthProvider`, `HistoryProvider`, `PlanProvider`.

### UI Components

| Màn / widget | Trạng thái |
|---|---|
| `WelcomeScreen` | không lưu gì; email trong `LoginPanel` lưu tạm |
| `LoginPanel` | `_mode` (Future), `_sending`, `_error`, email (`RestorableTextEditingController`), đăng ký nghe `webTokens` khi `support = button` |
| `HistoryScreen` | đọc `HistoryProvider`, `AuthProvider`, `PlanProvider` (plan đang dùng); hẹn `load()` sau frame (không `notifyListeners()` lúc đang dựng) |
| `PlanDetailScreen` | `_plan` (Future), ngày đang xem (`RestorableInt`) |
| `ProfileScreen` | `_deleting` |
| `MainShell` | `_loginRoute` (khôi phục được — `login_sheet`) |

### DB / KV Changes

Không có (khoá `smartfit.welcome_done.v1` có từ F01).

### Ràng buộc áp dụng

- **#12, #28** không log email, token; lịch sử không chứa hồ sơ → chi tiết chỉ xem.
- **#22** 401 → đăng xuất + câu tiếng Việt + "Đăng nhập lại"; không tự gọi lại như khách.
- **#24** không "dùng lại" plan cũ làm plan hiện tại (thiếu hồ sơ của nó → 409).
- **#35** bảng đăng nhập, email đang gõ, ngày đang xem ở chi tiết: lưu tạm, không ghi xuống máy (test `restartAndRestore()`).
- **#36** bảng feedback giữ nguyên câu trả lời khi mở bảng đăng nhập chồng lên.
- **#37** (mới).

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+174: All tests passed!`
- [ ] `flutter build apk --debug`, `flutter build web`, `flutter build macos --debug` → `✓ Built`

## Test Checklist

1. **@welcome**: lần đầu → màn chào, chỉ gọi `/health`; "Dùng ngay" → Onboarding, mở lại không hiện; đăng nhập demo → Onboarding, tạo plan có token
2. **@login**: `mock` → ô email (mọi nền tảng), email sai khoá nút, gửi chữ thường; `google` → nút Google, không có ô email; huỷ → im lặng, không gọi backend; lỗi Google → câu tiếng Việt; backend 401 → "Máy chủ không chấp nhận…", không nói "hết hạn"; Windows → "chưa hỗ trợ"; thiếu Client ID → "chưa được cấu hình"; web → nút của Google, token từ nút → đăng nhập, lỗi nút → câu tiếng Việt; `/health` lỗi → "Thử lại"
3. **@history**: khách → dải nhắc, không gọi server; danh sách (giờ máy, calo, "Đang dùng"); Q4 ghi chú; rỗng; lỗi → "Thử lại"; 401 → "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"; đăng nhập khi đang mở tab → tự tải; chi tiết chỉ xem 3 ngày; 404 → câu tiếng Việt, "Về danh sách" tải lại
4. **@account**: khách → dải nhắc; đăng xuất → về khách, plan giữ, thoát Google; xoá tài khoản: hỏi lại, Huỷ không gọi server, xác nhận → `DELETE /api/v1/me`, plan giữ; lỗi → câu lỗi, vẫn đăng nhập
5. **@guest-replace** (Q5): khách có plan → hỏi; Huỷ → không gọi server; đã đăng nhập → không hỏi
6. **@token / 401**: tạo plan 401 → "Đăng nhập lại" → đăng nhập xong tự tạo tiếp với token; đổi món 401 → SnackBar + "Đăng nhập lại", plan giữ; bảng feedback 401 → bảng đăng nhập chồng lên, lựa chọn còn, gửi lại được
7. **@restore**: bảng đăng nhập đang mở + email đang gõ → khôi phục, không ghi khoá mới
8. **@timeout**, **@db**: không đổi

## Tasks

### Task 1 — Bảng đăng nhập, dải nhắc khách

```dart
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
```

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/services/google_auth.dart';
import 'package:my_ai_app/widgets/login_panel.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Bảng đăng nhập (PLAN 8.1, quyết định Q1–Q3): cách đăng nhập theo /health của backend; Google giả (#17).
void main() {
  Future<(Harness, List<String>)> pumpPanel(
    WidgetTester tester, {
    String authMode = 'mock',
    GoogleAuthSupport support = GoogleAuthSupport.interactive,
  }) async {
    final harness = await Harness.create(tester);
    harness.backend.responses['/health'] = {...loadFixture('health'), 'auth_mode': authMode};
    harness.google.support = support;
    final done = <String>[];
    await tester.pumpWidget(harness.screen(LoginPanel(onSignedIn: () => done.add('xong'))));
    await tester.pumpAndSettle();
    return (harness, done);
  }

  Map<String, dynamic> loginBody(Harness harness) =>
      jsonDecode(utf8.decode(harness.backend.requests.last.bodyBytes)) as Map<String, dynamic>;

  testWidgets('backend giả lập → ô email "Đăng nhập demo" (mọi nền tảng); email sai thì chưa bấm được', (tester) async {
    final (harness, done) = await pumpPanel(tester, support: GoogleAuthSupport.unsupported);
    expect(harness.backend.paths, ['/health']);
    expect(find.textContaining('Chế độ demo'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);

    await tester.enterText(field('Email'), 'lan@');
    await tester.pump();
    expect(enabled(tester, 'Đăng nhập demo'), isFalse);

    await tester.enterText(field('Email'), 'Lan@Example.com');
    await tester.pump();
    await tester.tap(find.text('Đăng nhập demo'));
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'mock:lan@example.com'});
    expect(harness.auth.isSignedIn, isTrue);
    expect(done, ['xong']);
  });

  testWidgets('backend Google, Android/macOS → nút Google; người dùng huỷ → không báo lỗi, không gọi backend', (
    tester,
  ) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google');
    expect(find.byType(TextField), findsNothing, reason: 'không có đăng nhập demo khi backend dùng Google (#21)');

    harness.google.token = null;
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(harness.backend.paths, ['/health']);
    expect(done, isEmpty);
    expect(find.textContaining('không thành công'), findsNothing);

    harness.google.token = 'google-id-token';
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'google-id-token'});
    expect(done, ['xong']);
  });

  testWidgets('lỗi Google → câu tiếng Việt; backend từ chối (401) → không nói "phiên hết hạn"', (tester) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google');
    harness.google.error = const GoogleAuthException('Đăng nhập Google không thành công. Vui lòng thử lại.');
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Google không thành công. Vui lòng thử lại.'), findsOneWidget);

    harness.google.error = null;
    harness.backend.failWith = 401;
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ không chấp nhận lần đăng nhập này. Vui lòng thử lại.'), findsOneWidget);
    expect(find.textContaining('hết hạn'), findsNothing);
    expect(harness.auth.isSignedIn, isFalse);
    expect(done, isEmpty);
  });

  testWidgets('backend Google trên Windows → nói rõ chưa hỗ trợ, vẫn dùng được (quyết định Q3)', (tester) async {
    await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.unsupported);
    expect(find.textContaining('chưa hỗ trợ trên Windows'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);
  });

  testWidgets('bản build thiếu GOOGLE_WEB_CLIENT_ID → nói chưa cấu hình, không có nút', (tester) async {
    await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.notConfigured);
    expect(find.textContaining('chưa được cấu hình đăng nhập Google'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);
  });

  testWidgets('web → nút do Google vẽ; token tới từ nút → đăng nhập backend; lỗi của nút → câu tiếng Việt', (
    tester,
  ) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.button);
    expect(find.byKey(const Key('google-web-button')), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);

    harness.google.sendWebError(const GoogleAuthException('Không mở được cửa sổ đăng nhập Google trên thiết bị này.'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được cửa sổ đăng nhập Google trên thiết bị này.'), findsOneWidget);

    harness.google.sendWebToken('web-token');
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'web-token'});
    expect(done, ['xong']);
  });

  testWidgets('không tới được máy chủ khi hỏi cách đăng nhập → câu lỗi + "Thử lại"', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.failWith = 503;
    await tester.pumpWidget(harness.screen(LoginPanel(onSignedIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập demo'), findsOneWidget);
    expect(harness.backend.paths, ['/health', '/health']);
  });

  testWidgets('dải nhắc khách: thường / vừa hết phiên', (tester) async {
    final harness = await Harness.create(tester);
    final taps = <String>[];
    await tester.pumpWidget(harness.screen(GuestBanner(onSignIn: () => taps.add('đăng nhập'))));
    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
    await tester.tap(find.text('Đăng nhập'));
    expect(taps, ['đăng nhập']);

    await tester.pumpWidget(harness.screen(GuestBanner(onSignIn: () {}, expired: true)));
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsOneWidget);
  });
}
```

### Task 2 — Màn chào

```dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/login_panel.dart';

// Màn chào lần đầu mở app (BRD FR-6.1, FR-7): đăng nhập là tuỳ chọn — "Dùng ngay" vào thẳng Onboarding. Đăng nhập
// xong MainShell tự chuyển sang Onboarding (AuthProvider.showWelcome thành false).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.page,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.restaurant_menu, size: 40, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SmartFit AI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thực đơn món Việt và bài tập tại nhà cho 3 ngày, tự điều chỉnh theo cảm nhận của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Đăng nhập để xem lại các kế hoạch cũ trên mọi thiết bị.',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.heading),
                    ),
                    const SizedBox(height: 12),
                    LoginPanel(onSignedIn: () {}),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onSkip,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Dùng ngay, không cần đăng nhập'),
              ),
              const SizedBox(height: 6),
              const Text(
                'Không đăng nhập: kế hoạch chỉ lưu trên máy này. Bạn có thể đăng nhập sau ở tab Cá nhân.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

### Task 3 — Dashboard: `PlanDayView`, 401 khi đổi món/bài

```diff
--- a/frontend_app/lib/screens/dashboard_screen.dart
+++ b/frontend_app/lib/screens/dashboard_screen.dart
@@ -13,12 +13,14 @@
 // Kế hoạch 3 ngày (BRD FR-2): mở đúng ngày hôm nay (D6-B1), đủ 3 bữa, tổng calo + macro mỗi ngày (FR-2.3),
 // buổi tập, `warnings` (NFR-9). Đổi món / đổi bài gọi API (FR-4.1, FR-4.2 — chuyển lên giai đoạn 6).
 class DashboardScreen extends StatefulWidget {
-  const DashboardScreen({super.key, required this.onCreatePlan, this.onFeedback});
+  const DashboardScreen({super.key, required this.onCreatePlan, this.onFeedback, this.onSignIn});
 
   // Tạo plan mới từ hồ sơ hiện tại (bản nháp nếu có) — plan hết hạn, hồ sơ đã đổi, hoặc server báo 409.
   final VoidCallback onCreatePlan;
   // Mở bảng feedback cuối ngày cho ngày được chọn (giai đoạn 7). null → không có thẻ feedback.
   final ValueChanged<int>? onFeedback;
+  // Mở bảng đăng nhập khi server trả 401 (phiên hết hạn — giai đoạn 8).
+  final VoidCallback? onSignIn;
 
   @override
   State<DashboardScreen> createState() => _DashboardScreenState();
@@ -72,6 +74,16 @@
           action: SnackBarAction(label: 'Tạo mới', onPressed: widget.onCreatePlan),
         ),
       );
+    } on UnauthorizedException catch (error) {
+      // AuthProvider đã đăng xuất; đổi lại được như khách, nhưng plan đã lưu trong lịch sử không được cập nhật.
+      final onSignIn = widget.onSignIn;
+      messenger.showSnackBar(
+        SnackBar(
+          content: Text(error.message),
+          behavior: SnackBarBehavior.floating,
+          action: onSignIn == null ? null : SnackBarAction(label: 'Đăng nhập lại', onPressed: onSignIn),
+        ),
+      );
     } on ApiException catch (error) {
       messenger.showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
     } finally {
@@ -111,13 +123,38 @@
             )
           else if (today < 1)
             _Banner(icon: Icons.schedule, text: 'Kế hoạch bắt đầu từ ${vietnameseDate(schedule.startDate)}.'),
-          if (plan.warnings.isNotEmpty) _Warnings(warnings: plan.warnings),
+          if (plan.warnings.isNotEmpty) PlanWarnings(warnings: plan.warnings),
           const SizedBox(height: 12),
           _daySelector(schedule, dayNumber, today),
           const SizedBox(height: 12),
           _NutritionSummary(day: day, target: plan.dailyTarget),
-          for (final meal in day.meals) _mealCard(plans, meal),
-          _workoutCard(plans, day.workout),
+          for (final meal in day.meals)
+            _MealCard(
+              meal: meal,
+              action: _SwapButton(
+                label: 'Đổi món',
+                pending: _pendingId == meal.mealId,
+                onPressed: plans.busy
+                    ? null
+                    : () => _swap(meal.mealId, () => plans.swapMeal(meal.mealId), () {
+                        final swapped = _findMeal(plans.plan, meal.mealId);
+                        return 'Đã đổi ${mealTypeLabels[meal.mealType]!.toLowerCase()} sang: ${swapped?.name ?? ''}';
+                      }),
+              ),
+            ),
+          _WorkoutCard(
+            workout: day.workout,
+            actionFor: (exercise) => _SwapButton(
+              label: 'Đổi bài',
+              pending: _pendingId == exercise.exerciseId,
+              onPressed: plans.busy
+                  ? null
+                  : () => _swap(exercise.exerciseId, () => plans.swapExercise(exercise.exerciseId), () {
+                      final swapped = _findExercise(plans.plan, exercise.exerciseId);
+                      return 'Đã đổi bài sang: ${swapped?.name ?? ''}';
+                    }),
+            ),
+          ),
           ?_feedbackCard(plans, dayNumber, today),
         ],
       ),
@@ -170,7 +207,94 @@
     onSelectionChanged: (value) => setState(() => _selectedDay = value.first),
   );
 
-  Widget _mealCard(PlanProvider plans, Meal meal) => _Card(
+  // Thẻ feedback cuối ngày: đã gửi → báo đã gửi (khoá — BRD 6.4); được đánh giá (quyết định Q2) → nút mở bảng.
+  Widget? _feedbackCard(PlanProvider plans, int dayNumber, int today) {
+    final onFeedback = widget.onFeedback;
+    if (onFeedback == null) return null;
+    if (plans.feedbackDays.contains(dayNumber)) {
+      return _Card(
+        child: Row(
+          children: [
+            const Icon(Icons.check_circle, color: AppColors.primary),
+            const SizedBox(width: 10),
+            Expanded(
+              child: Text(
+                'Đã gửi đánh giá ngày $dayNumber',
+                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
+              ),
+            ),
+          ],
+        ),
+      );
+    }
+    if (!canReviewDay(dayNumber, today: today, sent: plans.feedbackDays)) return null;
+    final text = dayNumber == 3
+        ? 'Đánh giá 1 phút để SmartFit lập kế hoạch 3 ngày tiếp theo.'
+        : dayNumber == today
+        ? 'Hôm nay thế nào? Đánh giá 1 phút để SmartFit điều chỉnh ngày ${dayNumber + 1}.'
+        : 'Bạn chưa đánh giá ngày $dayNumber — gửi ngay để điều chỉnh hôm nay.';
+    return _Card(
+      child: Column(
+        crossAxisAlignment: CrossAxisAlignment.start,
+        children: [
+          const Text(
+            'ĐÁNH GIÁ CUỐI NGÀY',
+            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
+          ),
+          const SizedBox(height: 6),
+          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.heading)),
+          const SizedBox(height: 10),
+          ElevatedButton.icon(
+            onPressed: plans.busy ? null : () => onFeedback(dayNumber),
+            icon: const Icon(Icons.rate_review_outlined, size: 18),
+            label: Text('Đánh giá ngày $dayNumber'),
+            style: ElevatedButton.styleFrom(
+              backgroundColor: AppColors.primaryBright,
+              foregroundColor: Colors.white,
+              elevation: 0,
+              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
+            ),
+          ),
+        ],
+      ),
+    );
+  }
+
+  static Meal? _findMeal(MealPlan? plan, String id) =>
+      plan?.days.expand((day) => day.meals).where((meal) => meal.mealId == id).firstOrNull;
+
+  static Exercise? _findExercise(MealPlan? plan, String id) =>
+      plan?.days.expand((day) => day.workout.exercises).where((exercise) => exercise.exerciseId == id).firstOrNull;
+}
+
+// Một ngày của plan chỉ để xem — plan cũ trong lịch sử (giai đoạn 8): tổng trong ngày, 3 bữa, buổi tập, không có nút
+// đổi món/bài.
+class PlanDayView extends StatelessWidget {
+  const PlanDayView({super.key, required this.day, required this.target});
+
+  final PlanDay day;
+  final DailyTarget target;
+
+  @override
+  Widget build(BuildContext context) => Column(
+    crossAxisAlignment: CrossAxisAlignment.stretch,
+    children: [
+      _NutritionSummary(day: day, target: target),
+      for (final meal in day.meals) _MealCard(meal: meal),
+      _WorkoutCard(workout: day.workout),
+    ],
+  );
+}
+
+class _MealCard extends StatelessWidget {
+  const _MealCard({required this.meal, this.action});
+
+  final Meal meal;
+  // Nút "Đổi món" trên Dashboard; null khi chỉ xem.
+  final Widget? action;
+
+  @override
+  Widget build(BuildContext context) => _Card(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
@@ -187,16 +311,7 @@
                 ),
               ),
             ),
-            _SwapButton(
-              label: 'Đổi món',
-              pending: _pendingId == meal.mealId,
-              onPressed: plans.busy
-                  ? null
-                  : () => _swap(meal.mealId, () => plans.swapMeal(meal.mealId), () {
-                      final swapped = _findMeal(plans.plan, meal.mealId);
-                      return 'Đã đổi ${mealTypeLabels[meal.mealType]!.toLowerCase()} sang: ${swapped?.name ?? ''}';
-                    }),
-            ),
+            ?action,
           ],
         ),
         const SizedBox(height: 6),
@@ -234,8 +349,17 @@
       ],
     ),
   );
+}
 
-  Widget _workoutCard(PlanProvider plans, Workout workout) => _Card(
+class _WorkoutCard extends StatelessWidget {
+  const _WorkoutCard({required this.workout, this.actionFor});
+
+  final Workout workout;
+  // Nút "Đổi bài" của từng động tác trên Dashboard; null khi chỉ xem.
+  final Widget? Function(Exercise exercise)? actionFor;
+
+  @override
+  Widget build(BuildContext context) => _Card(
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
@@ -277,81 +401,13 @@
                     ],
                   ),
                 ),
-                _SwapButton(
-                  label: 'Đổi bài',
-                  pending: _pendingId == exercise.exerciseId,
-                  onPressed: plans.busy
-                      ? null
-                      : () => _swap(exercise.exerciseId, () => plans.swapExercise(exercise.exerciseId), () {
-                          final swapped = _findExercise(plans.plan, exercise.exerciseId);
-                          return 'Đã đổi bài sang: ${swapped?.name ?? ''}';
-                        }),
-                ),
+                ?actionFor?.call(exercise),
               ],
             ),
           ),
       ],
     ),
   );
-
-  // Thẻ feedback cuối ngày: đã gửi → báo đã gửi (khoá — BRD 6.4); được đánh giá (quyết định Q2) → nút mở bảng.
-  Widget? _feedbackCard(PlanProvider plans, int dayNumber, int today) {
-    final onFeedback = widget.onFeedback;
-    if (onFeedback == null) return null;
-    if (plans.feedbackDays.contains(dayNumber)) {
-      return _Card(
-        child: Row(
-          children: [
-            const Icon(Icons.check_circle, color: AppColors.primary),
-            const SizedBox(width: 10),
-            Expanded(
-              child: Text(
-                'Đã gửi đánh giá ngày $dayNumber',
-                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
-              ),
-            ),
-          ],
-        ),
-      );
-    }
-    if (!canReviewDay(dayNumber, today: today, sent: plans.feedbackDays)) return null;
-    final text = dayNumber == 3
-        ? 'Đánh giá 1 phút để SmartFit lập kế hoạch 3 ngày tiếp theo.'
-        : dayNumber == today
-        ? 'Hôm nay thế nào? Đánh giá 1 phút để SmartFit điều chỉnh ngày ${dayNumber + 1}.'
-        : 'Bạn chưa đánh giá ngày $dayNumber — gửi ngay để điều chỉnh hôm nay.';
-    return _Card(
-      child: Column(
-        crossAxisAlignment: CrossAxisAlignment.start,
-        children: [
-          const Text(
-            'ĐÁNH GIÁ CUỐI NGÀY',
-            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
-          ),
-          const SizedBox(height: 6),
-          Text(text, style: const TextStyle(fontSize: 14, color: AppColors.heading)),
-          const SizedBox(height: 10),
-          ElevatedButton.icon(
-            onPressed: plans.busy ? null : () => onFeedback(dayNumber),
-            icon: const Icon(Icons.rate_review_outlined, size: 18),
-            label: Text('Đánh giá ngày $dayNumber'),
-            style: ElevatedButton.styleFrom(
-              backgroundColor: AppColors.primaryBright,
-              foregroundColor: Colors.white,
-              elevation: 0,
-              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
-            ),
-          ),
-        ],
-      ),
-    );
-  }
-
-  static Meal? _findMeal(MealPlan? plan, String id) =>
-      plan?.days.expand((day) => day.meals).where((meal) => meal.mealId == id).firstOrNull;
-
-  static Exercise? _findExercise(MealPlan? plan, String id) =>
-      plan?.days.expand((day) => day.workout.exercises).where((exercise) => exercise.exerciseId == id).firstOrNull;
 }
 
 class _NutritionSummary extends StatelessWidget {
@@ -419,8 +475,8 @@
   }
 }
 
-class _Warnings extends StatelessWidget {
-  const _Warnings({required this.warnings});
+class PlanWarnings extends StatelessWidget {
+  const PlanWarnings({super.key, required this.warnings});
 
   final List<String> warnings;
```

```diff
--- a/frontend_app/test/screens/dashboard_screen_test.dart
+++ b/frontend_app/test/screens/dashboard_screen_test.dart
@@ -73,6 +73,24 @@
     expect(harness.plans.plan!.toJson(), loadFixture('generate_plan'));
   });
 
+  // Giai đoạn 8: phiên hết hạn giữa chừng → không âm thầm thành khách, nói rõ và cho đăng nhập lại.
+  testWidgets('401 khi đổi món → "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"; món cũ giữ nguyên', (tester) async {
+    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
+    final signIns = <String>[];
+    await tester.pumpWidget(
+      harness.screen(DashboardScreen(onCreatePlan: () {}, onSignIn: () => signIns.add('đăng nhập'))),
+    );
+    harness.backend.failWith = 401;
+    await tester.tap(find.text('Đổi món').first);
+    await tester.pumpAndSettle();
+
+    expect(find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'), findsOneWidget);
+    expect(harness.auth.isSignedIn, isFalse);
+    expect(harness.plans.plan!.toJson(), loadFixture('generate_plan'));
+    await tester.tap(find.text('Đăng nhập lại'));
+    expect(signIns, ['đăng nhập']);
+  });
+
   testWidgets('hồ sơ đã sửa ở tab Cá nhân → dải nhắc tạo kế hoạch mới', (tester) async {
     final (harness, created) = await pumpDashboard(tester);
     await harness.plans.saveDraft(Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'}));
```

### Task 4 — Tab Lịch sử, xem lại plan cũ

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/account.dart';
import '../models/plan_schedule.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/login_panel.dart';
import 'dashboard_screen.dart' show formatNumber;
import 'plan_detail_screen.dart';

// Tab "Lịch sử" (BRD FR-7.2, PLAN 8.3): các plan đã tạo khi đăng nhập, mới nhất trước; bấm để xem lại (chỉ xem).
// Tải lại mỗi lần mở tab và khi kéo xuống. Chưa đăng nhập → lời mời đăng nhập (quyết định Q6).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

// "Thứ Tư, 30/9/2026 · 14:05" theo giờ trên máy (server trả UTC).
String historyTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${vietnameseDate(local)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Lần tải đã hẹn sau frame này — tránh gọi load() (notifyListeners) giữa lúc đang dựng.
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  void _scheduleLoad() {
    if (_loadScheduled) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) context.read<HistoryProvider>().load();
    });
  }

  void _open(PlanSummary summary) => Navigator.of(
    context,
  ).restorablePush(planDetailRoute, arguments: {'id': summary.id, 'created_at': summary.createdAt.toIso8601String()});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final history = context.watch<HistoryProvider>();
    // Vừa đăng nhập khi đang mở tab → tải danh sách của tài khoản đó.
    if (auth.isSignedIn && history.items == null && history.error == null && !history.loading) _scheduleLoad();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: history.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const Text(
              'Lịch sử kế hoạch',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kế hoạch tạo khi đã đăng nhập được lưu trên máy chủ, xem lại trên mọi thiết bị.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (!auth.isSignedIn)
              GuestBanner(onSignIn: widget.onSignIn, expired: history.error is UnauthorizedException)
            else
              ..._signedIn(context, history),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedIn(BuildContext context, HistoryProvider history) {
    final items = history.items;
    final error = history.error;
    final currentId = context.watch<PlanProvider>().plan?.planId;
    return [
      // Plan đang dùng tạo lúc chưa đăng nhập (hoặc bằng tài khoản khác) không bao giờ vào lịch sử (quyết định Q4).
      if (items != null && currentId != null && !items.any((item) => item.id == currentId))
        const _Note(
          icon: Icons.info_outline,
          text:
              'Kế hoạch đang dùng chưa có trong lịch sử của tài khoản này (được tạo lúc chưa đăng nhập). '
              'Tạo kế hoạch mới để lưu vào lịch sử.',
        ),
      if (error != null) ...[
        _Note(icon: Icons.cloud_off_rounded, text: error.message),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: history.load, child: const Text('Thử lại')),
        ),
      ],
      if (items == null && error == null)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(color: AppColors.primaryBright)),
        )
      else if (items != null && items.isEmpty)
        const _Note(icon: Icons.history, text: 'Chưa có kế hoạch nào. Kế hoạch bạn tạo từ giờ sẽ được lưu ở đây.')
      else if (items != null)
        for (final item in items) _item(item, current: item.id == currentId),
    ];
  }

  Widget _item(PlanSummary item, {required bool current}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: current ? AppColors.primaryBright : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(item),
        leading: const Icon(Icons.event_note, color: AppColors.primary),
        title: Text(
          historyTime(item.createdAt),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        subtitle: Text(
          'Mục tiêu ${formatNumber(item.targetCalories)} kcal/ngày',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                child: const Text(
                  'Đang dùng',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.heading)),
        ),
      ],
    ),
  );
}
```

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/meal_plan.dart';
import '../providers/history_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart' show PlanDayView, PlanWarnings;
import 'history_screen.dart' show historyTime;

// Route khôi phục được (#35): tham số là {id, created_at} (chuỗi) — plan tải lại từ server khi mở lại.
@pragma('vm:entry-point')
Route<void> planDetailRoute(BuildContext context, Object? arguments) {
  final args = (arguments! as Map).cast<String, Object?>();
  return MaterialPageRoute<void>(
    builder: (context) =>
        PlanDetailScreen(id: args['id']! as String, createdAt: DateTime.parse(args['created_at']! as String)),
  );
}

// Xem lại một plan cũ (FR-7.2): chỉ xem. Không "dùng lại" làm plan hiện tại — lịch sử không lưu hồ sơ đã tạo ra plan
// (#12), đổi món/feedback sẽ bị 409 (P10 giai đoạn 8).
class PlanDetailScreen extends StatefulWidget {
  const PlanDetailScreen({super.key, required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> with RestorationMixin {
  late Future<MealPlan> _plan;
  final _day = RestorableInt(1);

  @override
  String get restorationId => 'plan_detail';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) => registerForRestoration(_day, 'day');

  @override
  void initState() {
    super.initState();
    _plan = context.read<HistoryProvider>().plan(widget.id);
  }

  @override
  void dispose() {
    _day.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F9FA),
    appBar: AppBar(
      title: Text(historyTime(widget.createdAt), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    body: SafeArea(
      child: FutureBuilder<MealPlan>(
        future: _plan,
        builder: (context, snapshot) {
          final plan = snapshot.data;
          if (snapshot.hasError) return _failed(snapshot.error);
          if (plan == null) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBright));
          }
          final day = plan.days[_day.value - 1];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Chỉ xem lại — kế hoạch cũ không đổi món, đổi bài hay gửi đánh giá được.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (plan.warnings.isNotEmpty) PlanWarnings(warnings: plan.warnings),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var number = 1; number <= 3; number++) ButtonSegment(value: number, label: Text('Ngày $number')),
                ],
                selected: {_day.value},
                onSelectionChanged: (value) => setState(() => _day.value = value.first),
              ),
              PlanDayView(day: day, target: plan.dailyTarget),
            ],
          );
        },
      ),
    ),
  );

  Widget _failed(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
          const SizedBox(height: 12),
          Text(
            error is NotFoundException
                ? 'Kế hoạch này không còn trong lịch sử.'
                : error is ApiException
                ? error.message
                : const ServerException().message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.heading),
          ),
          const SizedBox(height: 12),
          if (error is NotFoundException || error is UnauthorizedException)
            TextButton(
              onPressed: () {
                // Plan đã bị xoá trên server → danh sách đang hiện cũng đã cũ.
                if (error is NotFoundException) context.read<HistoryProvider>().load();
                Navigator.pop(context);
              },
              child: const Text('Về danh sách'),
            )
          else
            TextButton(
              onPressed: () => setState(() {
                _plan = context.read<HistoryProvider>().plan(widget.id);
              }),
              child: const Text('Thử lại'),
            ),
        ],
      ),
    ),
  );
}
```

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/screens/history_screen.dart';
import 'package:my_ai_app/screens/plan_detail_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Tab "Lịch sử" và màn xem lại plan cũ (PLAN 8.3, BRD FR-7.2; quyết định Q4, Q6).
void main() {
  const fixtureId = '00000000-0000-4000-8000-000000000002';

  Future<(Harness, List<String>)> pumpHistory(WidgetTester tester, {Map<String, Object>? saved}) async {
    final harness = await Harness.create(tester, saved: saved ?? {...savedPlan(), ...signedIn()});
    final signIns = <String>[];
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () => signIns.add('đăng nhập'))));
    await tester.pumpAndSettle();
    return (harness, signIns);
  }

  testWidgets('chưa đăng nhập → dải nhắc khách + nút đăng nhập, không gọi server', (tester) async {
    final (harness, signIns) = await pumpHistory(tester, saved: savedPlan());
    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
    await tester.tap(find.text('Đăng nhập'));
    expect(signIns, ['đăng nhập']);
  });

  testWidgets('đã đăng nhập → danh sách: ngày giờ trên máy, calo mục tiêu, nhãn "Đang dùng" cho plan hiện tại', (
    tester,
  ) async {
    final (harness, _) = await pumpHistory(tester);
    expect(harness.backend.paths, ['/api/v1/plans/history']);
    expect(harness.backend.requests.single.headers['Authorization'], startsWith('Bearer '));
    expect(find.text(historyTime(DateTime.utc(2026, 9, 24))), findsOneWidget);
    expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
    expect(find.text('Đang dùng'), findsOneWidget, reason: 'fixture lịch sử có đúng plan_id của plan đang dùng');
    expect(find.textContaining('chưa có trong lịch sử'), findsNothing);
  });

  testWidgets('plan đang dùng không có trong lịch sử (tạo lúc chưa đăng nhập) → ghi chú (quyết định Q4)', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.responses['/api/v1/plans/history'] = {
      'plans': [
        {
          'id': '11111111-2222-4333-8444-555555555555',
          'created_at': '2026-09-20T02:05:00.000Z',
          'target_calories': 1500,
        },
      ],
    };
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Đang dùng'), findsNothing);
    expect(find.textContaining('chưa có trong lịch sử của tài khoản này'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('chưa có plan nào → câu mời; lỗi mạng → câu lỗi + "Thử lại"', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.responses['/api/v1/plans/history'] = {'plans': <Object>[]};
    harness.backend.failWith = 503;
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có kế hoạch nào'), findsOneWidget);
  });

  testWidgets('401 (token hết hạn) → về khách, dải nhắc "Phiên đăng nhập đã hết hạn" + "Đăng nhập lại"', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    harness.backend.failWith = 401;
    await tester.pumpWidget(harness.screen(HistoryScreen(onSignIn: () {})));
    await tester.pumpAndSettle();
    expect(harness.auth.isSignedIn, isFalse);
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsOneWidget);
  });

  testWidgets('đăng nhập khi đang mở tab → tự tải danh sách', (tester) async {
    final (harness, _) = await pumpHistory(tester, saved: savedPlan());
    await harness.auth.signIn('mock:sv@vku.edu.vn');
    await tester.pumpAndSettle();
    expect(harness.backend.paths.last, '/api/v1/plans/history');
    expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
  });

  testWidgets('bấm một plan → màn chỉ xem: 3 ngày, không có nút đổi món/bài hay đánh giá', (tester) async {
    final (harness, _) = await pumpHistory(tester);
    harness.backend.responses['/api/v1/plans/history/$fixtureId'] = loadFixture('generate_plan');
    await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanDetailScreen), findsOneWidget);
    expect(harness.backend.paths.last, '/api/v1/plans/history/$fixtureId');
    expect(find.text('BỮA SÁNG'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsOneWidget);
    expect(find.text('Đổi món'), findsNothing);
    expect(find.text('Đổi bài'), findsNothing);
    expect(find.textContaining('Đánh giá ngày'), findsNothing);

    await tester.tap(find.text('Ngày 2'));
    await tester.pumpAndSettle();
    expect(find.text('Bánh mì trứng ốp la'), findsOneWidget);
  });

  testWidgets('plan không còn trên server (404) → câu tiếng Việt; "Về danh sách" tải lại danh sách', (tester) async {
    final (harness, _) = await pumpHistory(tester);
    harness.backend.failWith = 404;
    await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Kế hoạch này không còn trong lịch sử.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Về danh sách'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanDetailScreen), findsNothing);
    expect(harness.backend.paths.last, '/api/v1/plans/history');
  });
}
```

### Task 5 — Tài khoản ở tab Cá nhân

```diff
--- a/frontend_app/lib/screens/profile_screen.dart
+++ b/frontend_app/lib/screens/profile_screen.dart
@@ -5,17 +5,22 @@
 
 import '../models/api/codes.dart';
 import '../models/api/profile.dart';
+import '../providers/auth_provider.dart';
 import '../providers/plan_provider.dart';
+import '../services/api_exception.dart';
 import '../theme/app_colors.dart';
 import 'dashboard_screen.dart' show formatNumber;
+import '../widgets/login_panel.dart';
 import '../widgets/profile_form.dart';
 
 // Tab "Cá nhân" (BRD FR-1.6): xem và sửa hồ sơ bất cứ lúc nào. Sửa xong lưu thành bản nháp — plan đang có vẫn dùng
-// hồ sơ cũ (đổi món/feedback không bị 409) — và gợi ý tạo lại plan.
+// hồ sơ cũ (đổi món/feedback không bị 409) — và gợi ý tạo lại plan. Mục "Tài khoản" (FR-6, giai đoạn 8): đăng xuất,
+// xoá tài khoản; chưa đăng nhập → dải nhắc (quyết định Q6).
 class ProfileScreen extends StatefulWidget {
-  const ProfileScreen({super.key, required this.onCreatePlan});
+  const ProfileScreen({super.key, required this.onCreatePlan, required this.onSignIn});
 
   final ValueChanged<Profile> onCreatePlan;
+  final VoidCallback onSignIn;
 
   @override
   State<ProfileScreen> createState() => _ProfileScreenState();
@@ -26,6 +31,8 @@
   ProfileFormController? _form;
   // Phần đang sửa dở, lưu tạm như Onboarding (PLAN D8); null = không sửa.
   final _typed = RestorableStringN(null);
+  // Đang chờ server xoá tài khoản.
+  bool _deleting = false;
 
   bool get _editing => _form != null;
 
@@ -71,11 +78,58 @@
     FocusScope.of(context).unfocus();
     await context.read<PlanProvider>().saveDraft(form.toProfile());
     if (mounted) _stopEditing();
+  }
+
+  Future<void> _signOut() async {
+    final messenger = ScaffoldMessenger.of(context);
+    await context.read<AuthProvider>().signOut();
+    messenger.showSnackBar(
+      const SnackBar(
+        content: Text('Đã đăng xuất. Kế hoạch trên máy này vẫn giữ.'),
+        behavior: SnackBarBehavior.floating,
+      ),
+    );
+  }
+
+  // FR-6.4: hỏi lại, nói rõ mất gì và giữ gì.
+  Future<void> _deleteAccount() async {
+    final auth = context.read<AuthProvider>();
+    final messenger = ScaffoldMessenger.of(context);
+    final confirmed = await showDialog<bool>(
+      context: context,
+      builder: (context) => AlertDialog(
+        title: const Text('Xoá tài khoản?'),
+        content: const Text(
+          'Tài khoản và toàn bộ lịch sử kế hoạch trên máy chủ sẽ bị xoá vĩnh viễn. '
+          'Kế hoạch đang dùng trên máy này vẫn giữ, bạn dùng tiếp như khách.',
+        ),
+        actions: [
+          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
+          TextButton(
+            onPressed: () => Navigator.pop(context, true),
+            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
+            child: const Text('Xoá vĩnh viễn'),
+          ),
+        ],
+      ),
+    );
+    if (confirmed != true || !mounted) return;
+    setState(() => _deleting = true);
+    String message;
+    try {
+      await auth.deleteAccount();
+      message = 'Đã xoá tài khoản và lịch sử kế hoạch.';
+    } on ApiException catch (error) {
+      message = error.message;
+    }
+    if (mounted) setState(() => _deleting = false);
+    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
   }
 
   @override
   Widget build(BuildContext context) {
     final plans = context.watch<PlanProvider>();
+    final auth = context.watch<AuthProvider>();
     final profile = plans.editableProfile;
     if (profile == null) return const SizedBox.shrink();
 
@@ -92,6 +146,7 @@
             'Chỉ lưu trên máy này, không gửi lưu ở máy chủ.',
             style: TextStyle(fontSize: 12, color: AppColors.muted),
           ),
+          if (!auth.isSignedIn && !_editing) GuestBanner(onSignIn: widget.onSignIn),
           if (plans.hasPendingProfile && !_editing)
             Container(
               margin: const EdgeInsets.only(top: 12),
@@ -117,6 +172,7 @@
               ),
             ),
           if (_form case final form?) ..._editor(form) else ..._summary(plans, profile),
+          if (auth.user case final user? when !_editing) _account(user.name, user.email),
         ],
       ),
     );
@@ -159,6 +215,50 @@
     ];
   }
 
+  Widget _account(String name, String email) => Container(
+    margin: const EdgeInsets.only(top: 20),
+    padding: const EdgeInsets.all(16),
+    decoration: BoxDecoration(
+      color: Colors.white,
+      borderRadius: BorderRadius.circular(18),
+      border: Border.all(color: AppColors.border),
+    ),
+    child: Column(
+      crossAxisAlignment: CrossAxisAlignment.start,
+      children: [
+        const Text(
+          'TÀI KHOẢN',
+          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
+        ),
+        const SizedBox(height: 8),
+        Text(
+          name,
+          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
+        ),
+        Text(email, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
+        const SizedBox(height: 12),
+        Wrap(
+          spacing: 8,
+          runSpacing: 8,
+          children: [
+            OutlinedButton.icon(
+              onPressed: _deleting ? null : _signOut,
+              icon: const Icon(Icons.logout, size: 18),
+              label: const Text('Đăng xuất'),
+            ),
+            TextButton(
+              onPressed: _deleting ? null : _deleteAccount,
+              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
+              child: _deleting
+                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
+                  : const Text('Xoá tài khoản'),
+            ),
+          ],
+        ),
+      ],
+    ),
+  );
+
   List<Widget> _editor(ProfileFormController form) => [
     BodySection(form: form),
     GoalSection(form: form),
```

```diff
--- a/frontend_app/test/screens/profile_screen_test.dart
+++ b/frontend_app/test/screens/profile_screen_test.dart
@@ -12,7 +12,7 @@
   ) async {
     final harness = await Harness.create(tester, saved: savedPlan());
     final created = <Profile>[];
-    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: created.add)));
+    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: created.add, onSignIn: () {})));
 
     expect(find.text('Nữ'), findsOneWidget);
     expect(find.text('Hải sản'), findsOneWidget);
@@ -37,4 +37,71 @@
     expect(created.single.goal, Goal.bulk);
     expect(created.single.restrictions.allergies, 'Hải sản');
   });
+
+  // Giai đoạn 8 (FR-6, quyết định Q6): mục Tài khoản khi đã đăng nhập, dải nhắc khi dùng như khách.
+  testWidgets('khách → dải nhắc "chỉ lưu trên máy này" + nút đăng nhập; không có mục Tài khoản', (tester) async {
+    final harness = await Harness.create(tester, saved: savedPlan());
+    final signIns = <String>[];
+    await tester.pumpWidget(
+      harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () => signIns.add('đăng nhập'))),
+    );
+    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
+    expect(find.text('TÀI KHOẢN'), findsNothing);
+    await tester.tap(find.text('Đăng nhập'));
+    expect(signIns, ['đăng nhập']);
+  });
+
+  testWidgets('đã đăng nhập → tên, email; "Đăng xuất" về khách, plan trên máy giữ nguyên', (tester) async {
+    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
+    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
+    expect(find.textContaining('Bạn đang dùng không đăng nhập'), findsNothing);
+    await scrollTo(tester, find.text('TÀI KHOẢN'));
+    expect(find.text('sv@vku.edu.vn'), findsOneWidget);
+
+    await tester.tap(find.text('Đăng xuất'));
+    await tester.pumpAndSettle();
+    expect(harness.auth.isSignedIn, isFalse);
+    expect(harness.plans.hasPlan, isTrue);
+    expect(find.text('Đã đăng xuất. Kế hoạch trên máy này vẫn giữ.'), findsOneWidget);
+    expect(find.text('TÀI KHOẢN'), findsNothing);
+    expect(harness.google.signOutCalls, 1);
+  });
+
+  testWidgets('xoá tài khoản: hỏi lại; Huỷ → không gọi server; xác nhận → DELETE /me, về khách, plan giữ', (
+    tester,
+  ) async {
+    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
+    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
+    await scrollTo(tester, find.text('Xoá tài khoản'));
+    await tester.tap(find.text('Xoá tài khoản'));
+    await tester.pumpAndSettle();
+    expect(find.textContaining('toàn bộ lịch sử kế hoạch trên máy chủ sẽ bị xoá vĩnh viễn'), findsOneWidget);
+    await tester.tap(find.text('Huỷ'));
+    await tester.pumpAndSettle();
+    expect(harness.backend.requests, isEmpty);
+    expect(harness.auth.isSignedIn, isTrue);
+
+    await tester.tap(find.text('Xoá tài khoản'));
+    await tester.pumpAndSettle();
+    await tester.tap(find.text('Xoá vĩnh viễn'));
+    await tester.pumpAndSettle();
+    expect(harness.backend.requests.single.method, 'DELETE');
+    expect(harness.backend.paths, ['/api/v1/me']);
+    expect(harness.auth.isSignedIn, isFalse);
+    expect(harness.plans.hasPlan, isTrue);
+    expect(find.text('Đã xoá tài khoản và lịch sử kế hoạch.'), findsOneWidget);
+  });
+
+  testWidgets('xoá tài khoản lỗi → câu lỗi, vẫn đăng nhập', (tester) async {
+    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
+    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
+    harness.backend.failWith = 503;
+    await scrollTo(tester, find.text('Xoá tài khoản'));
+    await tester.tap(find.text('Xoá tài khoản'));
+    await tester.pumpAndSettle();
+    await tester.tap(find.text('Xoá vĩnh viễn'));
+    await tester.pumpAndSettle();
+    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);
+    expect(harness.auth.isSignedIn, isTrue);
+  });
 }
```

### Task 6 — 401 ở màn chờ và bảng feedback

```diff
--- a/frontend_app/lib/screens/loading_screen.dart
+++ b/frontend_app/lib/screens/loading_screen.dart
@@ -8,13 +8,22 @@
 // Chờ backend tạo plan (NFR-1): chế độ giả lập trả ngay, có Gemini thường 8–15 s, tối đa khoảng 40 s. Câu chờ
 // không bịa số liệu. [error] khác null → báo lỗi và cho thử lại (NFR-2).
 class LoadingScreen extends StatefulWidget {
-  const LoadingScreen({super.key, this.error, required this.onRetry, required this.onEditProfile, this.onBack});
+  const LoadingScreen({
+    super.key,
+    this.error,
+    required this.onRetry,
+    required this.onEditProfile,
+    this.onBack,
+    this.onSignIn,
+  });
 
   final ApiException? error;
   final VoidCallback onRetry;
   final VoidCallback onEditProfile;
   // Có plan cũ thì cho quay về plan đó thay vì kẹt ở màn lỗi.
   final VoidCallback? onBack;
+  // Mở bảng đăng nhập khi lỗi là 401 (phiên hết hạn — giai đoạn 8).
+  final VoidCallback? onSignIn;
 
   @override
   State<LoadingScreen> createState() => _LoadingScreenState();
@@ -38,6 +47,10 @@
     super.dispose();
   }
 
+  // 401 → nút chính là "Đăng nhập lại" (đăng nhập xong MainShell tạo tiếp); "Thử lại" lúc này là tạo như khách,
+  // plan không vào lịch sử.
+  VoidCallback? get _signIn => widget.error is UnauthorizedException ? widget.onSignIn : null;
+
   @override
   Widget build(BuildContext context) {
     final error = widget.error;
@@ -95,17 +108,21 @@
       SizedBox(
         width: double.infinity,
         child: ElevatedButton(
-          onPressed: widget.onRetry,
+          onPressed: _signIn ?? widget.onRetry,
           style: ElevatedButton.styleFrom(
             backgroundColor: AppColors.primaryBright,
             foregroundColor: Colors.white,
             padding: const EdgeInsets.symmetric(vertical: 14),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
           ),
-          child: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w700)),
+          child: Text(
+            _signIn == null ? 'Thử lại' : 'Đăng nhập lại',
+            style: const TextStyle(fontWeight: FontWeight.w700),
+          ),
         ),
       ),
       const SizedBox(height: 8),
+      if (_signIn != null) TextButton(onPressed: widget.onRetry, child: const Text('Tạo không cần đăng nhập')),
       TextButton(onPressed: widget.onEditProfile, child: const Text('Sửa hồ sơ')),
       if (widget.onBack != null) TextButton(onPressed: widget.onBack, child: const Text('Về kế hoạch đang có')),
     ],
```

```diff
--- a/frontend_app/lib/widgets/feedback_sheet.dart
+++ b/frontend_app/lib/widgets/feedback_sheet.dart
@@ -7,6 +7,7 @@
 import '../providers/plan_provider.dart';
 import '../services/api_exception.dart';
 import '../theme/app_colors.dart';
+import 'login_panel.dart';
 
 // Feedback cuối ngày (BRD FR-5, PLAN giai đoạn 7): 3 câu hỏi theo D2, gửi, rồi báo đúng điều đã đổi.
 // Route khôi phục được (#35): hàm top-level, tham số chỉ là số ngày. Trả `true` khi người dùng chọn tạo kế hoạch
@@ -237,6 +238,15 @@
           Align(
             alignment: Alignment.centerLeft,
             child: TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tạo kế hoạch mới')),
+          ),
+        // 401 (giai đoạn 8): bảng đăng nhập mở chồng lên, câu trả lời đang chọn vẫn giữ để gửi lại.
+        if (error is UnauthorizedException)
+          Align(
+            alignment: Alignment.centerLeft,
+            child: TextButton(
+              onPressed: () => Navigator.of(context).restorablePush(loginSheetRoute),
+              child: const Text('Đăng nhập lại'),
+            ),
           ),
       ],
       if (_sending && day == 3) ...[
```

```diff
--- a/frontend_app/test/widgets/feedback_sheet_test.dart
+++ b/frontend_app/test/widgets/feedback_sheet_test.dart
@@ -10,8 +10,13 @@
 
 // Bảng feedback cuối ngày (PLAN giai đoạn 7, quyết định Q1–Q4) — mở từ thẻ trên Dashboard, trong cả app.
 void main() {
-  Future<Harness> openSheet(WidgetTester tester, {int day = 1, DateTime? now}) async {
-    final harness = await Harness.create(tester, saved: savedPlan(), now: now);
+  Future<Harness> openSheet(
+    WidgetTester tester, {
+    int day = 1,
+    DateTime? now,
+    Map<String, Object> account = const {},
+  }) async {
+    final harness = await Harness.create(tester, saved: {...savedPlan(), ...account}, now: now);
     await tester.pumpWidget(harness.app());
     await scrollTo(tester, find.text('Đánh giá ngày $day'));
     await tester.tap(find.text('Đánh giá ngày $day'));
@@ -133,12 +138,47 @@
     harness.backend.responses['/api/v1/generate-plan'] = fresh;
     await tap(tester, 'Tạo kế hoạch mới');
     await tester.pumpAndSettle();
+    // Khách: plan cũ sẽ mất hẳn → hỏi lại (quyết định Q5 giai đoạn 8).
+    expect(find.text('Thay kế hoạch hiện tại?'), findsOneWidget);
+    await tester.tap(find.text('Thay kế hoạch'));
+    await tester.pumpAndSettle();
     expect(find.text('Đánh giá cuối ngày 1'), findsNothing);
     expect(harness.backend.paths.last, '/api/v1/generate-plan');
     expect(harness.plans.plan!.planId, fresh['plan_id']);
     expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
   });
 
+  // Giai đoạn 8: token hết hạn giữa chừng → đăng nhập lại ngay trên bảng, câu trả lời vẫn còn để gửi lại.
+  testWidgets('401 → "Đăng nhập lại" mở bảng đăng nhập chồng lên; đăng nhập xong gửi lại được, lựa chọn còn nguyên', (
+    tester,
+  ) async {
+    final harness = await openSheet(tester, account: signedIn());
+    for (final label in ['Rất mệt', 'Căng mỏi cơ', 'Đúng thực đơn']) {
+      await tap(tester, label);
+    }
+    harness.backend.failWith = 401;
+    await tap(tester, 'Gửi và điều chỉnh ngày 2');
+    await tester.pumpAndSettle();
+    expect(find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'), findsOneWidget);
+    expect(harness.auth.isSignedIn, isFalse);
+
+    harness.backend.failWith = null;
+    await tap(tester, 'Đăng nhập lại');
+    await tester.pumpAndSettle();
+    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sv@vku.edu.vn');
+    await tester.pump();
+    await tester.tap(find.text('Đăng nhập demo'));
+    await tester.pumpAndSettle();
+    expect(harness.auth.isSignedIn, isTrue);
+    expect(find.text('Đăng nhập demo'), findsNothing, reason: 'bảng đăng nhập tự đóng');
+    expect(selected(tester, 'Rất mệt'), isTrue);
+
+    await tap(tester, 'Gửi và điều chỉnh ngày 2');
+    await tester.pumpAndSettle();
+    expect(find.text('Đã lưu đánh giá ngày 1'), findsOneWidget);
+    expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
+  });
+
   testWidgets('ngày 3 → chờ có câu "tới 40 giây"; báo plan mới bắt đầu ngày mai; Dashboard hiện plan mới', (
     tester,
   ) async {
```

### Task 7 — `MainShell` (diff so với mốc F01)

```diff
--- a/frontend_app/lib/main.dart
+++ b/frontend_app/lib/main.dart
@@ -7,18 +7,22 @@
 import 'models/api/profile.dart';
 import 'providers/auth_provider.dart';
 import 'providers/grocery_provider.dart';
+import 'providers/history_provider.dart';
 import 'providers/plan_provider.dart';
 import 'screens/dashboard_screen.dart';
 import 'screens/grocery_screen.dart';
+import 'screens/history_screen.dart';
 import 'screens/loading_screen.dart';
 import 'screens/onboarding_screen.dart';
 import 'screens/profile_screen.dart';
+import 'screens/welcome_screen.dart';
 import 'services/api_client.dart';
 import 'services/api_exception.dart';
 import 'services/google_auth.dart';
 import 'theme/app_colors.dart';
 import 'widgets/app_frame.dart';
 import 'widgets/feedback_sheet.dart';
+import 'widgets/login_panel.dart';
 
 Future<void> main() async {
   WidgetsFlutterBinding.ensureInitialized();
@@ -27,22 +31,25 @@
   // Đọc hết dữ liệu đã lưu một lần trước khi vẽ màn đầu — MainShell biết ngay có plan hay chưa, không cần màn chờ.
   final prefs = await SharedPreferences.getInstance();
   final api = ApiClient(baseUrl: resolveApiBaseUrl());
+  final auth = AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth());
   final plans = PlanProvider(api: api, prefs: prefs);
   runApp(
     SmartFitApp(
-      auth: AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth()),
+      auth: auth,
       plans: plans,
       grocery: GroceryProvider(prefs: prefs, plans: plans),
+      history: HistoryProvider(api: api, auth: auth),
     ),
   );
 }
 
 class SmartFitApp extends StatelessWidget {
-  const SmartFitApp({super.key, required this.auth, required this.plans, required this.grocery});
+  const SmartFitApp({super.key, required this.auth, required this.plans, required this.grocery, required this.history});
 
   final AuthProvider auth;
   final PlanProvider plans;
   final GroceryProvider grocery;
+  final HistoryProvider history;
 
   @override
   Widget build(BuildContext context) {
@@ -51,6 +58,7 @@
         ChangeNotifierProvider.value(value: auth),
         ChangeNotifierProvider.value(value: plans),
         ChangeNotifierProvider.value(value: grocery),
+        ChangeNotifierProvider.value(value: history),
       ],
       child: AnnotatedRegion<SystemUiOverlayStyle>(
         value: const SystemUiOverlayStyle(
@@ -114,14 +122,27 @@
     onPresent: (navigator, arguments) => navigator.restorablePush(feedbackSheetRoute, arguments: arguments),
     onComplete: (createPlan) {
       final profile = context.read<PlanProvider>().editableProfile;
-      if (createPlan == true && profile != null) _generate(profile);
+      if (createPlan == true && profile != null) _createPlan(profile);
     },
   );
 
+  // Bảng đăng nhập (giai đoạn 8) từ tab Cá nhân, Lịch sử, lỗi 401. Tạo plan bị 401 (phiên hết hạn) → đăng nhập
+  // xong thì tạo tiếp, để plan vào lịch sử.
+  late final _loginRoute = RestorableRouteFuture<bool?>(
+    onPresent: (navigator, arguments) => navigator.restorablePush(loginSheetRoute),
+    onComplete: (signedIn) {
+      final requested = _requested;
+      if (signedIn == true && _screen == AppScreen.loading && _error is UnauthorizedException && requested != null) {
+        _generate(requested);
+      }
+    },
+  );
+
   @override
   void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
     registerForRestoration(_tab, 'tab');
     registerForRestoration(_feedbackRoute, 'feedback_sheet');
+    registerForRestoration(_loginRoute, 'login_sheet');
   }
 
   @override
@@ -129,6 +150,7 @@
     WidgetsBinding.instance.removeObserver(this);
     _tab.dispose();
     _feedbackRoute.dispose();
+    _loginRoute.dispose();
     super.dispose();
   }
 
@@ -158,10 +180,35 @@
     }
   }
 
+  // Tạo plan mới thay plan đang có. Khách không có lịch sử nên plan cũ mất hẳn → hỏi trước (quyết định Q5 giai đoạn 8).
+  Future<void> _createPlan(Profile profile) async {
+    if (!context.read<AuthProvider>().isSignedIn && context.read<PlanProvider>().hasPlan) {
+      final replace = await showDialog<bool>(
+        context: context,
+        builder: (context) => AlertDialog(
+          title: const Text('Thay kế hoạch hiện tại?'),
+          content: const Text(
+            'Bạn đang dùng không đăng nhập nên kế hoạch hiện tại sẽ bị thay và không xem lại được. '
+            'Đăng nhập để kế hoạch mới được lưu vào lịch sử.',
+          ),
+          actions: [
+            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
+            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thay kế hoạch')),
+          ],
+        ),
+      );
+      if (replace != true || !mounted) return;
+    }
+    await _generate(profile);
+  }
+
   @override
   Widget build(BuildContext context) {
     final plans = context.watch<PlanProvider>();
+    final auth = context.watch<AuthProvider>();
     final screen = _screen == AppScreen.home && !plans.hasPlan ? AppScreen.onboarding : _screen;
+    // Màn chào chỉ trước Onboarding của lần đầu (FR-6.1); đăng nhập hoặc "Dùng ngay" → Onboarding.
+    if (screen == AppScreen.onboarding && auth.showWelcome) return WelcomeScreen(onSkip: auth.skipWelcome);
     return switch (screen) {
       AppScreen.onboarding => OnboardingScreen(initial: _requested ?? plans.editableProfile, onSubmit: _generate),
       AppScreen.loading => LoadingScreen(
@@ -169,6 +216,7 @@
         onRetry: () => _generate(_requested!),
         onEditProfile: () => setState(() => _screen = AppScreen.onboarding),
         onBack: plans.hasPlan ? () => setState(() => _screen = AppScreen.home) : null,
+        onSignIn: _loginRoute.present,
       ),
       AppScreen.home => _home(plans),
     };
@@ -179,16 +227,13 @@
       // Khoá theo plan_id: plan mới thì Dashboard mở lại đúng ngày hôm nay.
       0 => DashboardScreen(
         key: ValueKey(plans.plan?.planId),
-        onCreatePlan: () => _generate(plans.editableProfile!),
+        onCreatePlan: () => _createPlan(plans.editableProfile!),
         onFeedback: (day) => _feedbackRoute.present(day),
+        onSignIn: _loginRoute.present,
       ),
       1 => const GroceryScreen(),
-      2 => _placeholder(
-        icon: Icons.history_rounded,
-        title: 'Lịch sử kế hoạch',
-        subtitle: 'Đăng nhập để xem lại các kế hoạch đã tạo — tính năng sắp có.',
-      ),
-      _ => ProfileScreen(onCreatePlan: _generate),
+      2 => HistoryScreen(onSignIn: _loginRoute.present),
+      _ => ProfileScreen(onCreatePlan: _createPlan, onSignIn: _loginRoute.present),
     },
     bottomNavigationBar: Container(
       decoration: const BoxDecoration(
@@ -224,34 +269,4 @@
       ),
     ),
   );
-
-  Widget _placeholder({required IconData icon, required String title, required String subtitle}) => SafeArea(
-    child: Center(
-      child: Padding(
-        padding: const EdgeInsets.symmetric(horizontal: 24),
-        child: Column(
-          mainAxisAlignment: MainAxisAlignment.center,
-          children: [
-            Container(
-              padding: const EdgeInsets.all(16),
-              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
-              child: Icon(icon, size: 36, color: AppColors.muted),
-            ),
-            const SizedBox(height: 16),
-            Text(
-              title,
-              textAlign: TextAlign.center,
-              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
-            ),
-            const SizedBox(height: 6),
-            Text(
-              subtitle,
-              textAlign: TextAlign.center,
-              style: const TextStyle(fontSize: 12, color: AppColors.muted),
-            ),
-          ],
-        ),
-      ),
-    ),
-  );
 }
```

### Task 8 — Harness, luồng cả app (diff so với mốc F01)

```diff
--- a/frontend_app/test/app_harness.dart
+++ b/frontend_app/test/app_harness.dart
@@ -6,6 +6,7 @@
 import 'package:my_ai_app/models/plan_schedule.dart';
 import 'package:my_ai_app/providers/auth_provider.dart';
 import 'package:my_ai_app/providers/grocery_provider.dart';
+import 'package:my_ai_app/providers/history_provider.dart';
 import 'package:my_ai_app/providers/plan_provider.dart';
 import 'package:provider/provider.dart';
 import 'package:shared_preferences/shared_preferences.dart';
@@ -14,10 +15,11 @@
 import 'fake_google_auth.dart';
 import 'fixture_loader.dart';
 
-// Dựng app hoặc một màn hình với backend giả (fixture hợp đồng), dữ liệu đã lưu và đồng hồ giả, trên màn hình cỡ
-// điện thoại (411×914 dp — Pixel 8). Không gọi mạng thật.
+// Dựng app hoặc một màn hình với backend giả (fixture hợp đồng), Google giả, dữ liệu đã lưu và đồng hồ giả, trên màn
+// hình cỡ điện thoại (411×914 dp — Pixel 8). Không gọi mạng thật. Mặc định đã qua màn chào (`firstLaunch: true` để
+// thấy màn chào như lần đầu cài app).
 class Harness {
-  Harness._(this.backend, this.google, this.prefs, this.auth, this.plans, this.grocery);
+  Harness._(this.backend, this.google, this.prefs, this.auth, this.plans, this.grocery, this.history);
 
   final FakeBackend backend;
   final FakeGoogleAuth google;
@@ -25,28 +27,36 @@
   final AuthProvider auth;
   final PlanProvider plans;
   final GroceryProvider grocery;
+  final HistoryProvider history;
 
-  static Future<Harness> create(WidgetTester tester, {Map<String, Object> saved = const {}, DateTime? now}) async {
+  static Future<Harness> create(
+    WidgetTester tester, {
+    Map<String, Object> saved = const {},
+    DateTime? now,
+    bool firstLaunch = false,
+  }) async {
     tester.view.physicalSize = const Size(1080, 2400);
     tester.view.devicePixelRatio = 2.625;
     addTearDown(tester.view.reset);
-    SharedPreferences.setMockInitialValues(saved);
+    SharedPreferences.setMockInitialValues({if (!firstLaunch) AuthProvider.welcomeKey: true, ...saved});
     final prefs = await SharedPreferences.getInstance();
     final backend = FakeBackend();
     final google = FakeGoogleAuth();
     final clock = now ?? planStart;
     final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => clock);
+    final auth = AuthProvider(api: backend.api, prefs: prefs, google: google);
     return Harness._(
       backend,
       google,
       prefs,
-      AuthProvider(api: backend.api, prefs: prefs, google: google),
+      auth,
       plans,
       GroceryProvider(prefs: prefs, plans: plans),
+      HistoryProvider(api: backend.api, auth: auth),
     );
   }
 
-  Widget app() => SmartFitApp(auth: auth, plans: plans, grocery: grocery);
+  Widget app() => SmartFitApp(auth: auth, plans: plans, grocery: grocery, history: history);
 
   // Một màn hình đứng riêng, có Scaffold để hiện SnackBar.
   Widget screen(Widget child) => MultiProvider(
@@ -54,11 +64,18 @@
       ChangeNotifierProvider.value(value: auth),
       ChangeNotifierProvider.value(value: plans),
       ChangeNotifierProvider.value(value: grocery),
+      ChangeNotifierProvider.value(value: history),
     ],
     child: MaterialApp(home: Scaffold(body: child)),
   );
 }
 
+// Đã đăng nhập bằng tài khoản của fixture auth_login.
+Map<String, Object> signedIn() {
+  final login = loadFixture('auth_login');
+  return {AuthProvider.tokenKey: login['access_token'] as String, AuthProvider.userKey: jsonEncode(login['user'])};
+}
+
 // Plan fixture bắt đầu ngày 26/9/2026.
 final planStart = DateTime(2026, 9, 26, 9);
```

```diff
--- a/frontend_app/test/widget_test.dart
+++ b/frontend_app/test/widget_test.dart
@@ -3,9 +3,12 @@
 
 import 'package:flutter/material.dart';
 import 'package:flutter_test/flutter_test.dart';
+import 'package:my_ai_app/providers/auth_provider.dart';
 import 'package:my_ai_app/providers/plan_provider.dart';
 import 'package:my_ai_app/screens/dashboard_screen.dart';
 import 'package:my_ai_app/screens/onboarding_screen.dart';
+import 'package:my_ai_app/screens/plan_detail_screen.dart';
+import 'package:my_ai_app/screens/welcome_screen.dart';
 import 'package:my_ai_app/widgets/app_frame.dart';
 
 import 'app_harness.dart';
@@ -77,7 +80,7 @@
     expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
   });
 
-  testWidgets('thanh điều hướng: Đi chợ, Lịch sử (sắp có), Cá nhân', (tester) async {
+  testWidgets('thanh điều hướng: Đi chợ, Lịch sử, Cá nhân', (tester) async {
     final harness = await Harness.create(tester, saved: savedPlan());
     await tester.pumpWidget(harness.app());
     await tester.tap(find.text('Đi chợ'));
@@ -125,7 +128,7 @@
     await tester.pumpAndSettle();
     await tester.tap(find.text('Vận động nhẹ'));
     await tester.pump();
-    expect(harness.prefs.getKeys(), isEmpty);
+    expect(harness.prefs.getKeys(), {AuthProvider.welcomeKey});
 
     await tester.restartAndRestore();
     expect(find.textContaining('Bước 2/3'), findsOneWidget);
@@ -179,5 +182,156 @@
       expect(chip.selected, isTrue, reason: label);
     }
     expect(harness.prefs.getKeys(), keys);
+  });
+
+  // Giai đoạn 8 — tài khoản & lịch sử (FR-6, FR-7; quyết định Q1–Q7).
+  group('đăng nhập và lịch sử', () {
+    Future<void> signInDemo(WidgetTester tester, String email) async {
+      await tester.enterText(field('Email'), email);
+      await tester.pump();
+      await tester.tap(find.text('Đăng nhập demo'));
+      await tester.pumpAndSettle();
+    }
+
+    testWidgets('lần đầu mở app → màn chào, chỉ hỏi /health; "Dùng ngay" → Onboarding, lần sau không hiện lại', (
+      tester,
+    ) async {
+      final harness = await Harness.create(tester, firstLaunch: true);
+      await tester.pumpWidget(harness.app());
+      await tester.pumpAndSettle();
+      expect(find.byType(WelcomeScreen), findsOneWidget);
+      expect(find.text('Đăng nhập demo'), findsOneWidget, reason: 'backend giả lập (fixture health: auth_mode mock)');
+      expect(harness.backend.paths, ['/health']);
+
+      await tester.tap(find.text('Dùng ngay, không cần đăng nhập'));
+      await tester.pumpAndSettle();
+      expect(find.byType(OnboardingScreen), findsOneWidget);
+      expect(harness.auth.isSignedIn, isFalse);
+
+      await tester.pumpWidget(const SizedBox());
+      await tester.pumpWidget(harness.app());
+      expect(find.byType(OnboardingScreen), findsOneWidget);
+    });
+
+    testWidgets('màn chào: đăng nhập demo → Onboarding; tạo plan gửi kèm token (server lưu vào lịch sử)', (
+      tester,
+    ) async {
+      final harness = await Harness.create(tester, firstLaunch: true);
+      await tester.pumpWidget(harness.app());
+      await tester.pumpAndSettle();
+      await signInDemo(tester, 'sv@vku.edu.vn');
+      expect(harness.auth.isSignedIn, isTrue);
+      expect(find.byType(OnboardingScreen), findsOneWidget);
+
+      await fillOnboarding(tester);
+      await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
+      await tester.pumpAndSettle();
+      expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
+      expect(harness.backend.requests.last.url.path, '/api/v1/generate-plan');
+      expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
+    });
+
+    testWidgets('khách có plan bấm "Tạo kế hoạch mới" → hỏi lại (Q5); Huỷ → giữ plan, không gọi server', (
+      tester,
+    ) async {
+      final harness = await Harness.create(tester, saved: savedPlan(), now: planStart.add(const Duration(days: 4)));
+      await tester.pumpWidget(harness.app());
+      await tester.tap(find.text('Tạo kế hoạch mới'));
+      await tester.pumpAndSettle();
+      expect(find.text('Thay kế hoạch hiện tại?'), findsOneWidget);
+      await tester.tap(find.text('Huỷ'));
+      await tester.pumpAndSettle();
+      expect(harness.backend.requests, isEmpty);
+      expect(find.textContaining('Kế hoạch 3 ngày đã hết'), findsOneWidget);
+
+      await tester.tap(find.text('Tạo kế hoạch mới'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Thay kế hoạch'));
+      await tester.pumpAndSettle();
+      expect(harness.backend.paths, ['/api/v1/generate-plan']);
+    });
+
+    testWidgets('đã đăng nhập → tạo kế hoạch mới không hỏi (plan cũ nằm trong lịch sử)', (tester) async {
+      final harness = await Harness.create(
+        tester,
+        saved: {...savedPlan(), ...signedIn()},
+        now: planStart.add(const Duration(days: 4)),
+      );
+      await tester.pumpWidget(harness.app());
+      await tester.tap(find.text('Tạo kế hoạch mới'));
+      await tester.pumpAndSettle();
+      expect(find.text('Thay kế hoạch hiện tại?'), findsNothing);
+      expect(harness.backend.paths, ['/api/v1/generate-plan']);
+    });
+
+    testWidgets('tạo plan bị 401 (phiên hết hạn) → "Đăng nhập lại" → đăng nhập xong tự tạo tiếp, có token', (
+      tester,
+    ) async {
+      final harness = await Harness.create(
+        tester,
+        saved: {...savedPlan(), ...signedIn()},
+        now: planStart.add(const Duration(days: 4)),
+      );
+      await tester.pumpWidget(harness.app());
+      harness.backend.failWith = 401;
+      await tester.tap(find.text('Tạo kế hoạch mới'));
+      await tester.pumpAndSettle();
+      expect(find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'), findsOneWidget);
+      expect(find.text('Tạo không cần đăng nhập'), findsOneWidget);
+      expect(harness.auth.isSignedIn, isFalse);
+
+      harness.backend.failWith = null;
+      await tester.tap(find.text('Đăng nhập lại'));
+      await tester.pumpAndSettle();
+      await signInDemo(tester, 'sv@vku.edu.vn');
+      expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
+      expect(harness.backend.paths.sublist(1), ['/health', '/api/v1/auth/google', '/api/v1/generate-plan']);
+      expect(harness.backend.requests.last.headers['Authorization'], startsWith('Bearer '));
+    });
+
+    testWidgets('tab Lịch sử trong app: khách → mời đăng nhập; đăng nhập từ đó → danh sách → xem chi tiết → quay lại', (
+      tester,
+    ) async {
+      final harness = await Harness.create(tester, saved: savedPlan());
+      harness.backend.responses['/api/v1/plans/history/00000000-0000-4000-8000-000000000002'] = loadFixture(
+        'generate_plan',
+      );
+      await tester.pumpWidget(harness.app());
+      await tester.tap(find.text('Lịch sử'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Đăng nhập'));
+      await tester.pumpAndSettle();
+      await signInDemo(tester, 'sv@vku.edu.vn');
+      expect(find.text('Mục tiêu 1624 kcal/ngày'), findsOneWidget);
+      expect(find.text('Đang dùng'), findsOneWidget);
+
+      await tester.tap(find.text('Mục tiêu 1624 kcal/ngày'));
+      await tester.pumpAndSettle();
+      expect(find.byType(PlanDetailScreen), findsOneWidget);
+      await tester.pageBack();
+      await tester.pumpAndSettle();
+      expect(find.text('Lịch sử kế hoạch'), findsOneWidget);
+    });
+
+    // #35: bảng đăng nhập là route khôi phục được; email đang gõ chỉ lưu tạm.
+    testWidgets('bảng đăng nhập đang mở dở, hệ thống tắt app → mở lại còn bảng và email đang gõ; không ghi xuống máy', (
+      tester,
+    ) async {
+      final harness = await Harness.create(tester, saved: savedPlan());
+      await tester.pumpWidget(harness.app());
+      await tester.tap(find.text('Cá nhân'));
+      await tester.pumpAndSettle();
+      await tester.tap(find.text('Đăng nhập'));
+      await tester.pumpAndSettle();
+      await tester.enterText(field('Email'), 'sv@vku');
+      await tester.pump();
+      final keys = harness.prefs.getKeys();
+
+      await tester.restartAndRestore();
+      await tester.pumpAndSettle();
+      expect(find.text('Đăng nhập demo'), findsOneWidget);
+      expect(tester.widget<TextField>(field('Email')).controller!.text, 'sv@vku');
+      expect(harness.prefs.getKeys(), keys);
+    });
   });
 }
```

Integration test chỉ cần biên dịch được ở mốc này (F03 viết lại bài giao diện):

```diff
--- a/frontend_app/integration_test/backend_smoke_test.dart
+++ b/frontend_app/integration_test/backend_smoke_test.dart
@@ -8,6 +8,7 @@
 import 'package:my_ai_app/models/api/profile.dart';
 import 'package:my_ai_app/providers/auth_provider.dart';
 import 'package:my_ai_app/providers/grocery_provider.dart';
+import 'package:my_ai_app/providers/history_provider.dart';
 import 'package:my_ai_app/providers/plan_provider.dart';
 import 'package:my_ai_app/screens/dashboard_screen.dart';
 import 'package:my_ai_app/services/api_client.dart';
@@ -97,7 +98,12 @@
     );
 
     // Có plan đã lưu → app mở thẳng Dashboard.
-    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: GroceryProvider(prefs: prefs, plans: plans)));
+    await tester.pumpWidget(SmartFitApp(
+      auth: auth,
+      plans: plans,
+      grocery: GroceryProvider(prefs: prefs, plans: plans),
+      history: HistoryProvider(api: api, auth: auth),
+    ));
     await tester.pump(const Duration(seconds: 1));
     expect(find.byType(DashboardScreen), findsOneWidget);
     await tester.pumpWidget(const SizedBox());
@@ -119,12 +125,15 @@
   testWidgets('giao diện trên thiết bị: Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1', (tester) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
+    await prefs.setBool(AuthProvider.welcomeKey, true);
     final api = ApiClient(baseUrl: resolveApiBaseUrl());
+    final auth = AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth());
     final plans = PlanProvider(api: api, prefs: prefs);
     await tester.pumpWidget(SmartFitApp(
-      auth: AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth()),
+      auth: auth,
       plans: plans,
       grocery: GroceryProvider(prefs: prefs, plans: plans),
+      history: HistoryProvider(api: api, auth: auth),
     ));
     await fillOnboarding(tester);
     await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
```

### Kiểm

```bash
cd frontend_app
flutter analyze             # No issues found!
flutter test                # +174: All tests passed!
flutter build apk --debug   # ✓ Built
flutter build web           # ✓ Built build/web
flutter build macos --debug # ✓ Built  (export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer nếu cần)
```
