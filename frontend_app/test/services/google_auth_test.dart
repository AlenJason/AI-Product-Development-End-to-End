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
