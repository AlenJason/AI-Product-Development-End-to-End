# F01 — Lớp `GoogleAuth`, cách đăng nhập theo `/health`, cờ màn chào, `HistoryProvider`

## Feature

Phần logic của tài khoản và lịch sử, chưa có giao diện (màn hình ở mốc này chưa đổi):

| File | Việc |
|---|---|
| `pubspec.yaml` | `google_sign_in: ^7.2.0` (Android, iOS, macOS, web — không có Windows); `google_sign_in_web: ^1.1.3` (dependency trực tiếp vì import `web_only.dart`); `google_sign_in_platform_interface: ^3.1.0` chỉ ở `dev_dependencies` (test bản thật trên nền tảng giả) |
| `lib/services/google_auth.dart` (mới) | `GoogleAuth` (lớp trừu tượng): `support` (`unsupported` Windows/Linux, `notConfigured` thiếu `GOOGLE_WEB_CLIENT_ID`, `button` web, `interactive` Android/macOS), `signIn()` (null = người dùng huỷ), `button()`, `webTokens`, `signOut()`. `PluginGoogleAuth` — bản thật trên `google_sign_in` 7.x: `initialize()` một lần; web → `clientId`, Android/macOS → `serverClientId` (quyết định Q2); lỗi SDK → `GoogleAuthException` với câu tiếng Việt, không lộ mô tả của SDK |
| `lib/services/google_button_stub.dart`, `google_button_web.dart` (mới) | Nút Google của bản web (`renderButton()` dùng `dart:js_interop`) — import có điều kiện (brainstorm P2) |
| `lib/providers/auth_provider.dart` | Nhận `google:`; `loginMode()` đọc `auth_mode` của `/health` (Q1); `signInDemo(email)` gửi `mock:<email chữ thường>`; `validDemoEmail()` theo đúng mẫu của backend; `signInWithGoogle()`; `showWelcome` / `skipWelcome()` (khoá `smartfit.welcome_done.v1`); `signOut()` thoát cả phiên Google |
| `lib/providers/history_provider.dart` (mới) | Danh sách lịch sử chỉ trong bộ nhớ (FR-7.3); `load()` (khách → không gọi server; đang tải → bỏ qua); `plan(id)`; đổi tài khoản / đăng xuất → bỏ danh sách; giữ lỗi 401 để tab nói vì sao |
| `lib/main.dart`, `test/app_harness.dart`, `integration_test/backend_smoke_test.dart` | Chỉ truyền `google:` cho `AuthProvider` (F02 sửa tiếp hai file đầu) |
| `test/fake_backend.dart` | `failWith` mã 5xx → body chung kiểu NestJS (không có fixture `error_5xx`) |

## Scope

UI-only (logic + test):

- `frontend_app/pubspec.yaml`, `pubspec.lock` (sửa, qua `flutter pub add`); `macos/Flutter/GeneratedPluginRegistrant.swift` (`flutter pub get` tự sinh); `macos/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`, `macos/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (mới — Xcode sinh khi build macOS, ghim phiên bản GoogleSignIn, AppAuth…; commit để CI build đúng phiên bản đã thử)
- `frontend_app/lib/services/google_auth.dart`, `google_button_stub.dart`, `google_button_web.dart`, `lib/providers/history_provider.dart` (mới)
- `frontend_app/lib/providers/auth_provider.dart`, `lib/main.dart` (sửa)
- `frontend_app/test/fake_google_auth.dart`, `test/services/google_auth_test.dart`, `test/providers/history_provider_test.dart` (mới); `test/providers/auth_provider_test.dart`, `test/app_harness.dart`, `test/fake_backend.dart`, `integration_test/backend_smoke_test.dart` (sửa)

## Implementation

### API Routes

Không có route mới — backend đủ từ giai đoạn 3–4. App dùng:

- `GET /health` → `auth_mode` (`AuthProvider.loginMode()`, timeout 15 s);
- `POST /api/v1/auth/google` (`signIn()`, không gửi token cũ), `GET /api/v1/plans/history`, `/:id` (`HistoryProvider`, có token, 15 s);
- `DELETE /api/v1/me` (`deleteAccount()` sẵn có).

**Token:** Google ID token chỉ đi một lần lên `POST /api/v1/auth/google`, không lưu (FR-6.3). JWT của backend như cũ (`smartfit.access_token`). 401 cho request có token → `onUnauthorized` → `signOut()` (sẵn có) → giờ thoát cả phiên Google.

### UI Components

Không có (F02 dùng). `GoogleAuth.button()` là widget nhưng chỉ được F02 đặt lên màn hình.

### DB / KV Changes

Khoá `shared_preferences` mới `smartfit.welcome_done.v1` (`bool`). Không migration: thiếu → màn chào hiện một lần (người đang có plan không bao giờ thấy, vì màn chào chỉ đứng trước Onboarding). Lịch sử không ghi xuống máy.

### Ràng buộc áp dụng

- **#17** test không gọi Google thật: `FakeGoogleAuth` cho provider/widget; `PluginGoogleAuth` chạy trên `GoogleSignInPlatform` giả.
- **#21** demo chỉ khi backend `mock` — app không tự bật demo, chỉ theo `/health`.
- **#22, #28** 401 → đăng xuất (sẵn có); không log token, email, mô tả lỗi của SDK.
- **#10** không mật khẩu: demo chỉ là `mock:<email>` cho backend giả lập.
- **#37** (mới, F04 ghi vào wiki).

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+145: All tests passed!`
- [ ] `flutter build web` → `✓ Built build/web` (import có điều kiện biên dịch được cho web)

## Test Checklist

1. **@google**: nền tảng → `support` (Windows/Linux `unsupported`, thiếu Client ID `notConfigured`, web `button`, Android/macOS `interactive`); Android gửi Web Client ID làm `serverClientId`, không làm `clientId`; huỷ → `null`; lỗi cấu hình, `PlatformException` keychain, thiếu ID token → "chưa được cấu hình" và không lộ email trong mô tả; lỗi khác → "không thành công"; web: token từ luồng sự kiện, huỷ im lặng, lỗi khác báo; đăng xuất khi chưa khởi tạo không gọi SDK
2. **@auth**: `loginMode()` theo `auth_mode` (`mock`/`google`, mã lạ hoặc 503 → `ServerException`); demo gửi `mock:<email>` chữ thường, bỏ khoảng trắng; email sai dạng hoặc phần trước `@` > 64 ký tự → không hợp lệ; Google: token → backend, huỷ → không gọi backend, lỗi Google → ném nguyên; đăng xuất thoát phiên Google; màn chào: "Dùng ngay" hoặc đăng nhập → không hiện lại; xoá tài khoản lỗi → vẫn đăng nhập
3. **@history**: có token; khách không gọi server; đang tải → bỏ qua; lỗi → giữ để hiện, tải lại xoá lỗi; 401 → đăng xuất, giữ lỗi, đăng nhập lại → xoá; đăng xuất / đổi tài khoản giữa chừng → không hiện danh sách của người trước; `plan(id)` 404 → `NotFoundException`; không ghi khoá nào xuống máy
4. **@token**: đăng nhập lần đầu không gửi `Authorization`; request sau gửi `Bearer <access_token>` (sẵn có, giữ nguyên)
5. **@timeout**, **@db**: không đổi

## Tasks

### Task 1 — Package

```bash
cd frontend_app
flutter pub add google_sign_in:^7.2.0 google_sign_in_web:^1.1.3 dev:google_sign_in_platform_interface:^3.1.0
```

```diff
--- a/frontend_app/pubspec.yaml
+++ b/frontend_app/pubspec.yaml
@@ -37,6 +37,8 @@
   http: ^1.6.0
   provider: ^6.1.5
   shared_preferences: ^2.5.5
+  google_sign_in: ^7.2.0
+  google_sign_in_web: ^1.1.3
 
 dev_dependencies:
   flutter_test:
@@ -50,6 +52,7 @@
   # package. See that file for information about deactivating specific lint
   # rules and activating additional ones.
   flutter_lints: ^6.0.0
+  google_sign_in_platform_interface: ^3.1.0
 
 # For information on the generic Dart part of this file, see the
 # following page: https://dart.dev/tools/pub/pubspec
```

`flutter pub get` sinh lại `macos/Flutter/GeneratedPluginRegistrant.swift` (Windows, Linux không đổi — plugin không có bản cho hai nền tảng đó):

```diff
--- a/frontend_app/macos/Flutter/GeneratedPluginRegistrant.swift
+++ b/frontend_app/macos/Flutter/GeneratedPluginRegistrant.swift
@@ -5,8 +5,10 @@
 import FlutterMacOS
 import Foundation
 
+import google_sign_in_ios
 import shared_preferences_foundation
 
 func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
+  GoogleSignInPlugin.register(with: registry.registrar(forPlugin: "GoogleSignInPlugin"))
   SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
 }
```

`flutter build macos` lần đầu sinh hai file `Package.resolved` giống nhau (`macos/Runner.xcworkspace/…`, `macos/Runner.xcodeproj/project.xcworkspace/…`) — commit cả hai.

### Task 2 — `GoogleAuth`

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_button_stub.dart' if (dart.library.js_interop) 'google_button_web.dart';

// Đăng nhập Google (BRD FR-6.1, PLAN giai đoạn 8). App chỉ lấy ID token rồi gửi backend (`POST /api/v1/auth/google`),
// không giữ token của Google, không xin thêm quyền nào. Test dùng bản giả, không gọi Google thật (#17).
enum GoogleAuthSupport {
  // Windows, Linux: google_sign_in không có bản cho nền tảng này — dùng như khách (quyết định Q3).
  unsupported,
  // Build thiếu --dart-define=GOOGLE_WEB_CLIENT_ID (docs/SETUP_CREDENTIALS.md mục 3).
  notConfigured,
  // Web: người dùng bấm nút do Google vẽ ([GoogleAuth.button]); token tới qua [GoogleAuth.webTokens].
  button,
  // Android, macOS: app gọi [GoogleAuth.signIn], Google mở hộp chọn tài khoản.
  interactive,
}

// Lỗi đăng nhập Google. `message` là câu tiếng Việt hiện thẳng cho người dùng — không chứa mô tả lỗi của SDK.
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message);

  final String message;

  @override
  String toString() => 'GoogleAuthException: $message';
}

abstract class GoogleAuth {
  GoogleAuthSupport get support;

  // [GoogleAuthSupport.interactive]: ID token, hoặc null khi người dùng đóng hộp chọn tài khoản.
  // Lỗi → GoogleAuthException.
  Future<String?> signIn();

  // [GoogleAuthSupport.button]: nút đăng nhập do Google vẽ.
  Widget button();

  // [GoogleAuthSupport.button]: ID token sau mỗi lần đăng nhập bằng nút; lỗi là GoogleAuthException.
  Stream<String> get webTokens;

  Future<void> signOut();
}

const _misconfigured = GoogleAuthException(
  'Đăng nhập Google chưa được cấu hình đúng cho bản app này. Bạn vẫn dùng được mọi tính năng khi không đăng nhập.',
);
const _failed = GoogleAuthException('Đăng nhập Google không thành công. Vui lòng thử lại.');

// Bản thật, dùng google_sign_in 7.x. `GOOGLE_WEB_CLIENT_ID` là Client ID loại "Web application" — cũng là
// GOOGLE_CLIENT_ID của backend: web dùng làm `clientId`, Android và macOS dùng làm `serverClientId` để ID token cấp cho
// đúng Client ID backend kiểm. macOS còn cần GIDClientID, URL scheme trong Info.plist và keychain sharing (SETUP).
class PluginGoogleAuth implements GoogleAuth {
  PluginGoogleAuth({
    this.webClientId = const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    bool? web,
    TargetPlatform? platform,
  }) : _web = web ?? kIsWeb,
       _platform = platform ?? defaultTargetPlatform;

  final String webClientId;
  final bool _web;
  final TargetPlatform _platform;
  final _webTokens = StreamController<String>.broadcast();
  Future<void>? _ready;

  static const _native = {TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS};

  @override
  GoogleAuthSupport get support => !_web && !_native.contains(_platform)
      ? GoogleAuthSupport.unsupported
      : webClientId.isEmpty
      ? GoogleAuthSupport.notConfigured
      : _web
      ? GoogleAuthSupport.button
      : GoogleAuthSupport.interactive;

  @override
  Stream<String> get webTokens => _webTokens.stream;

  // initialize() chỉ gọi một lần (google_sign_in 7.x); lỗi → lần sau thử lại.
  Future<void> _init() async {
    final ready = _ready ??= _initialize();
    try {
      await ready;
    } catch (_) {
      if (identical(_ready, ready)) _ready = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final google = GoogleSignIn.instance;
    await google.initialize(clientId: _web ? webClientId : null, serverClientId: _web ? null : webClientId);
    if (_web) google.authenticationEvents.listen(_onWebEvent, onError: _onWebError);
  }

  void _onWebEvent(GoogleSignInAuthenticationEvent event) {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final token = event.user.authentication.idToken;
    if (token == null) {
      _webTokens.addError(_misconfigured);
    } else {
      _webTokens.add(token);
    }
  }

  void _onWebError(Object error) {
    final mapped = _describe(error);
    if (mapped != null) _webTokens.addError(mapped);
  }

  @override
  Future<String?> signIn() async {
    if (support != GoogleAuthSupport.interactive) throw StateError('signIn() chỉ dùng khi support = interactive');
    try {
      await _init();
      final token = (await GoogleSignIn.instance.authenticate()).authentication.idToken;
      if (token == null) throw _misconfigured;
      return token;
    } on GoogleAuthException {
      rethrow;
    } catch (error) {
      final mapped = _describe(error);
      if (mapped == null) return null;
      throw mapped;
    }
  }

  @override
  Widget button() => support != GoogleAuthSupport.button
      ? const SizedBox.shrink()
      : FutureBuilder<void>(
          future: _init(),
          builder: (context, snapshot) => snapshot.connectionState == ConnectionState.done && !snapshot.hasError
              ? renderGoogleButton()
              : const SizedBox(height: 44),
        );

  @override
  Future<void> signOut() async {
    // Chưa từng khởi tạo (chưa đăng nhập bằng Google lần nào trong phiên này, hoặc Windows) → không có gì để thoát.
    if (_ready == null) return;
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Phiên của backend đã xoá; phiên Google còn lại chỉ khiến lần sau hộp chọn tài khoản chọn sẵn.
    }
  }

  // null = người dùng tự huỷ, không báo lỗi. Không đưa mô tả lỗi của SDK ra ngoài (có thể chứa email).
  static GoogleAuthException? _describe(Object error) => switch (error) {
    GoogleSignInException(code: GoogleSignInExceptionCode.canceled || GoogleSignInExceptionCode.interrupted) => null,
    GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError,
    ) =>
      _misconfigured,
    GoogleSignInException(code: GoogleSignInExceptionCode.uiUnavailable) => const GoogleAuthException(
      'Không mở được cửa sổ đăng nhập Google trên thiết bị này.',
    ),
    // macOS thiếu keychain sharing → PlatformException "keychain error" (README của google_sign_in_ios).
    PlatformException() => _misconfigured,
    _ => _failed,
  };
}
```

```dart
import 'package:flutter/widgets.dart';

// Android, macOS, Windows: không có nút do Google vẽ — Android, macOS dùng GoogleAuth.signIn(). Bản web ở
// google_button_web.dart (import có điều kiện trong google_auth.dart).
Widget renderGoogleButton() => const SizedBox.shrink();
```

```dart
import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

// Web: Google bắt buộc đăng nhập bằng nút của Google Identity Services (google_sign_in 7.x không có authenticate()
// trên web). File này dùng dart:js_interop nên chỉ biên dịch cho web.
Widget renderGoogleButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    text: web.GSIButtonText.signinWith,
    shape: web.GSIButtonShape.pill,
    locale: 'vi',
  ),
);
```

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:my_ai_app/services/google_auth.dart';

// Bản thật của GoogleAuth chạy trên google_sign_in 7.x với một nền tảng giả (thay GoogleSignInPlatform.instance) —
// kiểm cách gọi SDK và cách đổi lỗi thành câu tiếng Việt mà không gọi Google thật (#17).
class FakePlatform extends GoogleSignInPlatform {
  FakePlatform({this.web = false});

  final bool web;
  InitParameters? initParams;
  int authenticateCalls = 0;
  int signOutCalls = 0;
  Object? failure;
  String? idToken = 'id-token-from-google';
  final events = StreamController<AuthenticationEvent>.broadcast();

  @override
  Future<void> init(InitParameters params) async => initParams = params;

  @override
  Stream<AuthenticationEvent>? get authenticationEvents => web ? events.stream : null;

  @override
  bool supportsAuthenticate() => !web;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    authenticateCalls++;
    final error = failure;
    if (error != null) throw error;
    return AuthenticationResults(
      user: const GoogleSignInUserData(email: 'lan@example.com', id: '42'),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  Future<void> signOut(SignOutParams params) async => signOutCalls++;

  @override
  Future<void> disconnect(DisconnectParams params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(AttemptLightweightAuthenticationParameters params) =>
      null;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;
}

void main() {
  late FakePlatform platform;

  FakePlatform use(FakePlatform fake) => GoogleSignInPlatform.instance = platform = fake;

  test('nền tảng và cấu hình → cách đăng nhập', () {
    GoogleAuthSupport on(TargetPlatform target, {String id = 'web-id', bool web = false}) =>
        PluginGoogleAuth(webClientId: id, platform: target, web: web).support;

    expect(on(TargetPlatform.android), GoogleAuthSupport.interactive);
    expect(on(TargetPlatform.macOS), GoogleAuthSupport.interactive);
    expect(on(TargetPlatform.windows), GoogleAuthSupport.unsupported, reason: 'google_sign_in không có bản Windows');
    expect(on(TargetPlatform.linux), GoogleAuthSupport.unsupported);
    expect(on(TargetPlatform.android, id: ''), GoogleAuthSupport.notConfigured);
    expect(
      on(TargetPlatform.windows, web: true),
      GoogleAuthSupport.button,
      reason: 'web chạy trên trình duyệt Windows',
    );
    expect(on(TargetPlatform.windows, id: '', web: true), GoogleAuthSupport.notConfigured);
  });

  test('Android: Web Client ID là serverClientId (ID token cấp cho Client ID backend kiểm) → trả ID token', () async {
    use(FakePlatform());
    final google = PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.android, web: false);

    expect(await google.signIn(), 'id-token-from-google');
    expect(platform.initParams!.serverClientId, 'web-id');
    expect(platform.initParams!.clientId, isNull, reason: 'Android nhận diện app bằng package + SHA-1');

    await google.signIn();
    expect(platform.authenticateCalls, 2);
  });

  test('người dùng đóng hộp chọn tài khoản → null, không lỗi', () async {
    use(FakePlatform()..failure = const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));
    expect(
      await PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.android, web: false).signIn(),
      isNull,
    );
  });

  test(
    'lỗi cấu hình, thiếu keychain sharing (macOS), không có ID token → câu tiếng Việt, không lộ mô tả của SDK',
    () async {
      Future<Object?> failWith(Object? error, {String? idToken = 'x'}) async {
        use(
          FakePlatform()
            ..failure = error
            ..idToken = idToken,
        );
        try {
          await PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.macOS, web: false).signIn();
          return null;
        } catch (thrown) {
          return thrown;
        }
      }

      final config = await failWith(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.clientConfigurationError,
          description: 'client lan@example.com',
        ),
      );
      expect(config, isA<GoogleAuthException>().having((e) => e.message, 'message', contains('chưa được cấu hình')));
      expect(config.toString(), isNot(contains('lan@example.com')));

      final keychain = await failWith(PlatformException(code: 'keychain error'));
      expect(keychain, isA<GoogleAuthException>().having((e) => e.message, 'message', contains('chưa được cấu hình')));

      final noToken = await failWith(null, idToken: null);
      expect(noToken, isA<GoogleAuthException>().having((e) => e.message, 'message', contains('chưa được cấu hình')));

      final other = await failWith(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError));
      expect(other, isA<GoogleAuthException>().having((e) => e.message, 'message', contains('không thành công')));
    },
  );

  test('web: Web Client ID là clientId; token tới qua luồng khi người dùng bấm nút của Google', () async {
    use(FakePlatform(web: true));
    final google = PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.windows, web: true);
    final tokens = <String>[];
    final errors = <Object>[];
    google.webTokens.listen(tokens.add, onError: errors.add);

    await initWeb(google);
    expect(platform.initParams!.clientId, 'web-id');

    platform.events.add(
      AuthenticationEventSignIn(
        user: const GoogleSignInUserData(email: 'lan@example.com', id: '42'),
        authenticationTokens: const AuthenticationTokenData(idToken: 'web-token'),
      ),
    );
    platform.events.add(
      AuthenticationEventException(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)),
    );
    platform.events.add(
      AuthenticationEventException(const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError)),
    );
    await pumpEventQueue();

    expect(tokens, ['web-token']);
    expect(errors, [isA<GoogleAuthException>()], reason: 'huỷ thì im lặng, lỗi khác thì báo');
  });

  test('đăng xuất: chưa từng khởi tạo → không gọi SDK; đã đăng nhập → thoát phiên Google', () async {
    use(FakePlatform());
    final fresh = PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.android, web: false);
    await fresh.signOut();
    expect(platform.signOutCalls, 0);
    expect(platform.initParams, isNull);

    await fresh.signIn();
    await fresh.signOut();
    expect(platform.signOutCalls, 1);

    final windows = PluginGoogleAuth(webClientId: 'web-id', platform: TargetPlatform.windows, web: false);
    await windows.signOut();
    expect(() => windows.signIn(), throwsStateError);
  });
}

// Web khởi tạo SDK khi dựng nút: gọi button() rồi chờ lần khởi tạo đó xong.
Future<void> initWeb(PluginGoogleAuth google) async {
  google.button();
  await pumpEventQueue();
}
```

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_ai_app/services/google_auth.dart';

// GoogleAuth giả cho test provider/widget — không gọi Google thật (#17). `token` là ID token lần signIn() tới trả
// (null = người dùng đóng hộp chọn tài khoản), `error` ném thay vì trả token; `sendWebToken()` giả lập bấm nút web.
class FakeGoogleAuth implements GoogleAuth {
  FakeGoogleAuth({this.support = GoogleAuthSupport.interactive, this.token = 'google-id-token', this.error});

  @override
  GoogleAuthSupport support;
  String? token;
  GoogleAuthException? error;
  int signInCalls = 0;
  int signOutCalls = 0;
  final _webTokens = StreamController<String>.broadcast();

  @override
  Future<String?> signIn() async {
    signInCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return token;
  }

  @override
  Widget button() => const SizedBox(key: Key('google-web-button'), width: 200, height: 44);

  @override
  Stream<String> get webTokens => _webTokens.stream;

  void sendWebToken(String token) => _webTokens.add(token);

  void sendWebError(GoogleAuthException error) => _webTokens.addError(error);

  @override
  Future<void> signOut() async => signOutCalls++;
}
```

### Task 3 — `AuthProvider`

```diff
--- a/frontend_app/lib/providers/auth_provider.dart
+++ b/frontend_app/lib/providers/auth_provider.dart
@@ -7,11 +7,21 @@
 import '../models/api/account.dart';
 import '../models/api/json_read.dart';
 import '../services/api_client.dart';
+import '../services/api_exception.dart';
+import '../services/google_auth.dart';
 
+// Cách đăng nhập theo chế độ của backend (`/health` → `auth_mode`, quyết định Q1 giai đoạn 8).
+enum LoginMode {
+  // AUTH_MODE=mock: ô email, gửi "mock:<email>" — mọi nền tảng, chỉ để phát triển/demo (#21).
+  demo,
+  // AUTH_MODE=google: nút Google (GoogleAuth).
+  google,
+}
+
 // Đăng nhập (BRD FR-6, 6.3). Không đăng nhập vẫn dùng đủ tính năng như khách; đăng nhập để có lịch sử plan.
 // JWT (7 ngày) lưu trong shared_preferences như BRD mục 4 — trên web là localStorage.
 class AuthProvider extends ChangeNotifier {
-  AuthProvider({required this._api, required this._prefs}) {
+  AuthProvider({required this._api, required this._prefs, required this.google}) {
     _restore();
     // Token hết hạn hoặc tài khoản đã xoá → server trả 401 → về chế độ khách.
     _api.onUnauthorized = () => unawaited(signOut());
@@ -19,16 +29,35 @@
 
   static const tokenKey = 'smartfit.access_token';
   static const userKey = 'smartfit.user.v1';
+  // Đã qua màn chào (đăng nhập hoặc bấm "Dùng ngay") — không hiện lại.
+  static const welcomeKey = 'smartfit.welcome_done.v1';
 
+  // Như backend (MOCK_TOKEN_PATTERN trong id-token-verifier.ts): gõ sai thì báo ngay, không đợi server trả 401.
+  static final _demoEmail = RegExp(r'^[^\s@]{1,64}@[^\s@]+\.[^\s@]+$');
+
   final ApiClient _api;
   final SharedPreferences _prefs;
+  final GoogleAuth google;
 
   AuthUser? _user;
 
   AuthUser? get user => _user;
   bool get isSignedIn => _user != null;
 
-  // `idToken`: Google ID token (giai đoạn 8), hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
+  // Màn chào (FR-6.1) chỉ hiện lần đầu: chưa đăng nhập và chưa bấm "Dùng ngay".
+  bool get showWelcome => !isSignedIn && _prefs.getBool(welcomeKey) != true;
+
+  static bool validDemoEmail(String email) => _demoEmail.hasMatch(email.trim());
+
+  // Hỏi backend mỗi lần mở bảng đăng nhập: APK/web build một lần dùng được cho cả backend giả lập lẫn thật.
+  // Lỗi mạng → ApiException, gọi lại được.
+  Future<LoginMode> loginMode() async => switch ((await _api.health()).authMode) {
+    'mock' => LoginMode.demo,
+    'google' => LoginMode.google,
+    _ => throw const ServerException(),
+  };
+
+  // `idToken`: Google ID token, hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
   Future<void> signIn(String idToken) async {
     final result = await _api.loginWithGoogle(idToken);
     _api.accessToken = result.accessToken;
@@ -36,14 +65,33 @@
     notifyListeners();
     await _prefs.setString(tokenKey, result.accessToken);
     await _prefs.setString(userKey, jsonEncode(result.user.toJson()));
+    await _prefs.setBool(welcomeKey, true);
   }
 
+  // Chữ hoa/thường khác nhau là hai tài khoản với backend (sub = "mock:<email>") — gửi chữ thường.
+  Future<void> signInDemo(String email) => signIn('mock:${email.trim().toLowerCase()}');
+
+  // Android, macOS. false = người dùng đóng hộp chọn tài khoản. Lỗi → GoogleAuthException hoặc ApiException.
+  Future<bool> signInWithGoogle() async {
+    final token = await google.signIn();
+    if (token == null) return false;
+    await signIn(token);
+    return true;
+  }
+
+  Future<void> skipWelcome() async {
+    await _prefs.setBool(welcomeKey, true);
+    notifyListeners();
+  }
+
+  // Plan trên máy giữ nguyên (plan cục bộ không gắn tài khoản).
   Future<void> signOut() async {
     _api.accessToken = null;
     _user = null;
     notifyListeners();
     await _prefs.remove(tokenKey);
     await _prefs.remove(userKey);
+    await google.signOut();
   }
 
   // Xoá tài khoản và toàn bộ lịch sử trên server (FR-6). Plan đang mở trên máy giữ nguyên, dùng tiếp như khách.
```

```diff
--- a/frontend_app/test/providers/auth_provider_test.dart
+++ b/frontend_app/test/providers/auth_provider_test.dart
@@ -4,9 +4,11 @@
 import 'package:my_ai_app/models/api/profile.dart';
 import 'package:my_ai_app/providers/auth_provider.dart';
 import 'package:my_ai_app/services/api_exception.dart';
+import 'package:my_ai_app/services/google_auth.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 
 import '../fake_backend.dart';
+import '../fake_google_auth.dart';
 import '../fixture_loader.dart';
 
 void main() {
@@ -16,11 +18,14 @@
     AuthProvider.userKey: jsonEncode(login['user']),
   };
 
-  Future<(AuthProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
+  Future<(AuthProvider, FakeBackend, SharedPreferences)> create([
+    Map<String, Object> values = const {},
+    FakeGoogleAuth? google,
+  ]) async {
     SharedPreferences.setMockInitialValues(values);
     final prefs = await SharedPreferences.getInstance();
     final backend = FakeBackend();
-    return (AuthProvider(api: backend.api, prefs: prefs), backend, prefs);
+    return (AuthProvider(api: backend.api, prefs: prefs, google: google ?? FakeGoogleAuth()), backend, prefs);
   }
 
   test('đăng nhập → token gắn vào mọi request sau, lưu lại cho lần mở app sau', () async {
@@ -71,6 +76,13 @@
     expect(prefs.getKeys(), isEmpty);
   });
 
+  test('xoá tài khoản lỗi → vẫn đăng nhập (tài khoản còn trên server)', () async {
+    final (auth, backend, _) = await create(saved);
+    backend.failWith = 500;
+    await expectLater(auth.deleteAccount(), throwsA(isA<ServerException>()));
+    expect(auth.isSignedIn, isTrue);
+  });
+
   test('bản lưu hỏng hoặc thiếu một nửa → coi như chưa đăng nhập, xoá sạch', () async {
     final (broken, _, brokenPrefs) = await create({...saved, AuthProvider.userKey: '[]'});
     expect(broken.isSignedIn, isFalse);
@@ -81,4 +93,75 @@
     expect(halfBackend.api.accessToken, isNull);
     expect(halfPrefs.getKeys(), isEmpty);
   });
+
+  // Giai đoạn 8, quyết định Q1: cách đăng nhập theo /health của backend, không theo cờ lúc build.
+  test('cách đăng nhập theo auth_mode của backend; lỗi mạng → ném, gọi lại được', () async {
+    final (auth, backend, _) = await create();
+    expect(await auth.loginMode(), LoginMode.demo);
+    expect(backend.paths, ['/health']);
+
+    backend.responses['/health'] = {...loadFixture('health'), 'auth_mode': 'google'};
+    expect(await auth.loginMode(), LoginMode.google);
+
+    backend.responses['/health'] = {...loadFixture('health'), 'auth_mode': 'ldap'};
+    await expectLater(auth.loginMode(), throwsA(isA<ServerException>()));
+
+    backend.failWith = 503;
+    await expectLater(auth.loginMode(), throwsA(isA<ServerException>()));
+  });
+
+  test('đăng nhập demo: gửi mock:<email> chữ thường, bỏ khoảng trắng; kiểm email như backend', () async {
+    final (auth, backend, _) = await create();
+    await auth.signInDemo('  Lan@Example.COM ');
+    final body = jsonDecode(utf8.decode(backend.requests.single.bodyBytes)) as Map<String, dynamic>;
+    expect(body, {'id_token': 'mock:lan@example.com'});
+
+    expect(AuthProvider.validDemoEmail(' lan@example.com '), isTrue);
+    for (final bad in ['', 'lan', 'lan@', 'lan@example', '@example.com', 'la n@example.com', 'a@b@c.com']) {
+      expect(AuthProvider.validDemoEmail(bad), isFalse, reason: bad);
+    }
+    expect(AuthProvider.validDemoEmail('${'a' * 65}@example.com'), isFalse, reason: 'backend nhận tối đa 64 ký tự');
+  });
+
+  test('Google: token của Google → backend; người dùng huỷ → không gọi backend; lỗi Google → ném nguyên', () async {
+    final google = FakeGoogleAuth();
+    final (auth, backend, _) = await create(const {}, google);
+
+    expect(await auth.signInWithGoogle(), isTrue);
+    final body = jsonDecode(utf8.decode(backend.requests.single.bodyBytes)) as Map<String, dynamic>;
+    expect(body, {'id_token': 'google-id-token'});
+    await auth.signOut();
+
+    google.token = null;
+    expect(await auth.signInWithGoogle(), isFalse);
+    expect(backend.requests, hasLength(1));
+    expect(auth.isSignedIn, isFalse);
+
+    google.error = const GoogleAuthException('lỗi');
+    await expectLater(auth.signInWithGoogle(), throwsA(isA<GoogleAuthException>()));
+    expect(backend.requests, hasLength(1));
+  });
+
+  test('đăng xuất → thoát cả phiên Google', () async {
+    final google = FakeGoogleAuth();
+    final (auth, _, _) = await create(saved, google);
+    await auth.signOut();
+    expect(google.signOutCalls, 1);
+  });
+
+  test('màn chào chỉ hiện lần đầu: bấm "Dùng ngay" hoặc đăng nhập → không hiện lại', () async {
+    final (fresh, _, prefs) = await create();
+    expect(fresh.showWelcome, isTrue);
+    await fresh.skipWelcome();
+    expect(fresh.showWelcome, isFalse);
+    expect(prefs.getBool(AuthProvider.welcomeKey), isTrue);
+
+    final (signedIn, _, _) = await create();
+    await signedIn.signIn('mock:lan@example.com');
+    await signedIn.signOut();
+    expect(signedIn.showWelcome, isFalse, reason: 'đã qua màn chào bằng cách đăng nhập');
+
+    final (restored, _, _) = await create(saved);
+    expect(restored.showWelcome, isFalse);
+  });
 }
```

### Task 4 — `HistoryProvider`

```dart
import 'package:flutter/foundation.dart';

import '../models/api/account.dart';
import '../models/api/meal_plan.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import 'auth_provider.dart';

// Lịch sử plan của tài khoản đang đăng nhập (BRD FR-7.2, 6.3). Chỉ giữ trong bộ nhớ, không lưu xuống máy: dữ liệu
// nằm ở server (FR-7.3), tải lại mỗi lần mở tab. Đổi tài khoản hoặc đăng xuất → bỏ danh sách của người trước.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider({required this._api, required this._auth}) : _userId = _auth.user?.id {
    _auth.addListener(_onAuthChanged);
  }

  final ApiClient _api;
  final AuthProvider _auth;
  String? _userId;

  List<PlanSummary>? _items;
  bool _loading = false;
  ApiException? _error;

  // null = chưa tải xong lần nào (hoặc vừa đổi tài khoản). Mới nhất trước, tối đa 50 (backend).
  List<PlanSummary>? get items => _items;
  bool get loading => _loading;
  // Lỗi của lần tải gần nhất; 401 → AuthProvider đã đăng xuất, tab hiện lời mời đăng nhập lại.
  ApiException? get error => _error;

  // Chưa đăng nhập → không gọi server. Đang tải → bỏ qua.
  Future<void> load() async {
    if (!_auth.isSignedIn || _loading) return;
    final userId = _userId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final items = await _api.history();
      if (userId == _userId) _items = items;
    } on UnauthorizedException catch (error) {
      // AuthProvider đã đăng xuất (onUnauthorized) → giữ lỗi để tab nói vì sao.
      _error = error;
    } on ApiException catch (error) {
      if (userId == _userId) _error = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // Một plan cũ để xem lại. 404 (đã xoá, của tài khoản khác) → NotFoundException.
  Future<MealPlan> plan(String id) => _api.historyPlan(id);

  void _onAuthChanged() {
    final userId = _auth.user?.id;
    if (userId == _userId) return;
    _userId = userId;
    _items = null;
    // Giữ lỗi 401 để tab nói vì sao bị đăng xuất; đăng nhập lại thì xoá.
    if (userId != null || _error is! UnauthorizedException) _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
```

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/history_provider.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fake_google_auth.dart';
import '../fixture_loader.dart';

void main() {
  final login = loadFixture('auth_login');
  final signedIn = {
    AuthProvider.tokenKey: login['access_token'] as String,
    AuthProvider.userKey: jsonEncode(login['user']),
  };

  Future<(HistoryProvider, AuthProvider, FakeBackend, SharedPreferences)> create([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final auth = AuthProvider(api: backend.api, prefs: prefs, google: FakeGoogleAuth());
    return (HistoryProvider(api: backend.api, auth: auth), auth, backend, prefs);
  }

  test('đã đăng nhập → tải danh sách có token; không ghi gì xuống máy (dữ liệu nằm ở server)', () async {
    final (history, _, backend, prefs) = await create(signedIn);
    final keys = prefs.getKeys();
    await history.load();

    expect(history.items!.single.id, '00000000-0000-4000-8000-000000000002');
    expect(history.items!.single.targetCalories, 1624);
    expect(backend.requests.single.headers['Authorization'], 'Bearer ${login['access_token']}');
    expect(history.loading, isFalse);
    expect(prefs.getKeys(), keys);
  });

  test('chưa đăng nhập → không gọi server', () async {
    final (history, _, backend, _) = await create();
    await history.load();
    expect(backend.requests, isEmpty);
    expect(history.items, isNull);
  });

  test('đang tải → gọi thêm bị bỏ qua', () async {
    final (history, _, backend, _) = await create(signedIn);
    backend.hold = Completer<void>();
    final first = history.load();
    await history.load();
    expect(history.loading, isTrue);
    backend.hold!.complete();
    await first;
    expect(backend.requests, hasLength(1));
  });

  test('lỗi mạng → giữ lỗi để hiện, tải lại thì xoá lỗi', () async {
    final (history, _, backend, _) = await create(signedIn);
    backend.failWith = 503;
    await history.load();
    expect(history.error, isA<ServerException>());

    backend.failWith = null;
    await history.load();
    expect(history.error, isNull);
    expect(history.items, hasLength(1));
  });

  test('401 → AuthProvider đăng xuất; lỗi giữ lại để tab nói vì sao; đăng nhập lại → xoá lỗi', () async {
    final (history, auth, backend, _) = await create(signedIn);
    backend.failWith = 401;
    await history.load();
    expect(auth.isSignedIn, isFalse);
    expect(history.error, isA<UnauthorizedException>());
    expect(history.items, isNull);

    backend.failWith = null;
    await auth.signIn('mock:sv@vku.edu.vn');
    expect(history.error, isNull);
  });

  test('đăng xuất → bỏ danh sách của người trước', () async {
    final (history, auth, _, _) = await create(signedIn);
    await history.load();
    await auth.signOut();
    expect(history.items, isNull);
  });

  test('đổi tài khoản khi đang tải → không hiện danh sách của tài khoản cũ', () async {
    final (history, auth, backend, _) = await create(signedIn);
    backend.hold = Completer<void>();
    final loading = history.load();
    await auth.signOut();
    backend.hold!.complete();
    await loading;
    expect(history.items, isNull);
  });

  test('xem một plan cũ: GET /:id; không có → NotFoundException', () async {
    final (history, _, backend, _) = await create(signedIn);
    backend.responses['/api/v1/plans/history/abc'] = loadFixture('generate_plan');
    expect((await history.plan('abc')).planId, loadFixture('generate_plan')['plan_id']);

    backend.failWith = 404;
    await expectLater(history.plan('abc'), throwsA(isA<NotFoundException>()));
  });
}
```

### Task 5 — Truyền `google:` (mốc F01)

```diff
--- a/frontend_app/lib/main.dart
+++ b/frontend_app/lib/main.dart
@@ -15,6 +15,7 @@
 import 'screens/profile_screen.dart';
 import 'services/api_client.dart';
 import 'services/api_exception.dart';
+import 'services/google_auth.dart';
 import 'theme/app_colors.dart';
 import 'widgets/app_frame.dart';
 import 'widgets/feedback_sheet.dart';
@@ -29,7 +30,7 @@
   final plans = PlanProvider(api: api, prefs: prefs);
   runApp(
     SmartFitApp(
-      auth: AuthProvider(api: api, prefs: prefs),
+      auth: AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth()),
       plans: plans,
       grocery: GroceryProvider(prefs: prefs, plans: plans),
     ),
```

```diff
--- a/frontend_app/test/app_harness.dart
+++ b/frontend_app/test/app_harness.dart
@@ -11,14 +11,16 @@
 import 'package:shared_preferences/shared_preferences.dart';
 
 import 'fake_backend.dart';
+import 'fake_google_auth.dart';
 import 'fixture_loader.dart';
 
 // Dựng app hoặc một màn hình với backend giả (fixture hợp đồng), dữ liệu đã lưu và đồng hồ giả, trên màn hình cỡ
 // điện thoại (411×914 dp — Pixel 8). Không gọi mạng thật.
 class Harness {
-  Harness._(this.backend, this.prefs, this.auth, this.plans, this.grocery);
+  Harness._(this.backend, this.google, this.prefs, this.auth, this.plans, this.grocery);
 
   final FakeBackend backend;
+  final FakeGoogleAuth google;
   final SharedPreferences prefs;
   final AuthProvider auth;
   final PlanProvider plans;
@@ -31,12 +33,14 @@
     SharedPreferences.setMockInitialValues(saved);
     final prefs = await SharedPreferences.getInstance();
     final backend = FakeBackend();
+    final google = FakeGoogleAuth();
     final clock = now ?? planStart;
     final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => clock);
     return Harness._(
       backend,
+      google,
       prefs,
-      AuthProvider(api: backend.api, prefs: prefs),
+      AuthProvider(api: backend.api, prefs: prefs, google: google),
       plans,
       GroceryProvider(prefs: prefs, plans: plans),
     );
```

```diff
--- a/frontend_app/test/fake_backend.dart
+++ b/frontend_app/test/fake_backend.dart
@@ -8,7 +8,7 @@
 import 'fixture_loader.dart';
 
 // Backend giả cho test provider/widget: trả fixture hợp đồng theo đường dẫn, ghi lại request đã nhận.
-// `failWith` đặt mã lỗi (và fixture error_<mã>) cho mọi request tiếp theo; `hold` giữ response tới khi complete;
+// `failWith` đặt mã lỗi (và fixture error_<mã>; 5xx: body chung như NestJS) cho mọi request tiếp theo; `hold` giữ response tới khi complete;
 // `responses` thay JSON trả về cho một đường dẫn (ví dụ plan mới sau feedback ngày 3).
 class FakeBackend {
   final requests = <http.Request>[];
@@ -32,7 +32,10 @@
       requests.add(request);
       await hold?.future;
       final status = failWith;
-      if (status != null) return _json(loadFixture('error_$status'), status);
+      if (status != null) {
+        final body = status >= 500 ? {'statusCode': status, 'message': 'Internal server error'} : loadFixture('error_$status');
+        return _json(body, status);
+      }
       if (request.method == 'DELETE') return http.Response('', 204);
       final custom = responses[request.url.path];
       if (custom != null) return _json(custom, 200);
```

```diff
--- a/frontend_app/integration_test/backend_smoke_test.dart
+++ b/frontend_app/integration_test/backend_smoke_test.dart
@@ -12,6 +12,7 @@
 import 'package:my_ai_app/screens/dashboard_screen.dart';
 import 'package:my_ai_app/services/api_client.dart';
 import 'package:my_ai_app/services/api_exception.dart';
+import 'package:my_ai_app/services/google_auth.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 
 import '../test/app_harness.dart' show fillOnboarding, scrollTo;
@@ -51,7 +52,7 @@
     expect(health.gemini, 'fallback', reason: 'Tắt GEMINI_API_KEY trong backend_api/.env rồi khởi động lại backend');
     expect(health.authMode, 'mock', reason: 'Test đăng nhập bằng mock:<email> — cần AUTH_MODE=mock');
 
-    final auth = AuthProvider(api: api, prefs: prefs);
+    final auth = AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth());
     final plans = PlanProvider(api: api, prefs: prefs);
     await auth.signIn('mock:android-smoke@example.com');
     expect(auth.isSignedIn, isTrue);
@@ -84,7 +85,9 @@
     // Lưu thật trên thiết bị: đọc lại từ shared_preferences ra đúng plan đang có.
     final reloaded = PlanProvider(api: api, prefs: prefs);
     expect(reloaded.plan!.toJson(), plans.plan!.toJson());
-    expect(AuthProvider(api: ApiClient(baseUrl: resolveApiBaseUrl()), prefs: prefs).isSignedIn, isTrue);
+    expect(
+        AuthProvider(api: ApiClient(baseUrl: resolveApiBaseUrl()), prefs: prefs, google: PluginGoogleAuth()).isSignedIn,
+        isTrue);
 
     // Lỗi của server qua mạng thật → đúng loại lỗi, câu tiếng Việt của server.
     await expectLater(
@@ -119,7 +122,7 @@
     final api = ApiClient(baseUrl: resolveApiBaseUrl());
     final plans = PlanProvider(api: api, prefs: prefs);
     await tester.pumpWidget(SmartFitApp(
-      auth: AuthProvider(api: api, prefs: prefs),
+      auth: AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth()),
       plans: plans,
       grocery: GroceryProvider(prefs: prefs, plans: plans),
     ));
```

### Kiểm

```bash
cd frontend_app
flutter analyze     # No issues found!
flutter test        # +145: All tests passed!
flutter build web   # ✓ Built build/web
```
