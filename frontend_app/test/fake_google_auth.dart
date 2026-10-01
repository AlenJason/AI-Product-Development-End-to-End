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
