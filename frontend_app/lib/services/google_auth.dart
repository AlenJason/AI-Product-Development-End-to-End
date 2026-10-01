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
