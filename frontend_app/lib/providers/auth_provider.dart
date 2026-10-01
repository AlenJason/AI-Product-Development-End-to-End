import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/google_auth.dart';

// Cách đăng nhập theo chế độ của backend (`/health` → `auth_mode`, quyết định Q1 giai đoạn 8).
enum LoginMode {
  // AUTH_MODE=mock: ô email, gửi "mock:<email>" — mọi nền tảng, chỉ để phát triển/demo (#21).
  demo,
  // AUTH_MODE=google: nút Google (GoogleAuth).
  google,
}

// Đăng nhập (BRD FR-6, 6.3). Không đăng nhập vẫn dùng đủ tính năng như khách; đăng nhập để có lịch sử plan.
// JWT (7 ngày) lưu trong shared_preferences như BRD mục 4 — trên web là localStorage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._prefs, required this.google}) {
    _restore();
    // Token hết hạn hoặc tài khoản đã xoá → server trả 401 → về chế độ khách.
    _api.onUnauthorized = () => unawaited(signOut());
  }

  static const tokenKey = 'smartfit.access_token';
  static const userKey = 'smartfit.user.v1';
  // Đã qua màn chào (đăng nhập hoặc bấm "Dùng ngay") — không hiện lại.
  static const welcomeKey = 'smartfit.welcome_done.v1';

  // Như backend (MOCK_TOKEN_PATTERN trong id-token-verifier.ts): gõ sai thì báo ngay, không đợi server trả 401.
  static final _demoEmail = RegExp(r'^[^\s@]{1,64}@[^\s@]+\.[^\s@]+$');

  final ApiClient _api;
  final SharedPreferences _prefs;
  final GoogleAuth google;

  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;

  // Màn chào (FR-6.1) chỉ hiện lần đầu: chưa đăng nhập và chưa bấm "Dùng ngay".
  bool get showWelcome => !isSignedIn && _prefs.getBool(welcomeKey) != true;

  static bool validDemoEmail(String email) => _demoEmail.hasMatch(email.trim());

  // Hỏi backend mỗi lần mở bảng đăng nhập: APK/web build một lần dùng được cho cả backend giả lập lẫn thật.
  // Lỗi mạng → ApiException, gọi lại được.
  Future<LoginMode> loginMode() async => switch ((await _api.health()).authMode) {
    'mock' => LoginMode.demo,
    'google' => LoginMode.google,
    _ => throw const ServerException(),
  };

  // `idToken`: Google ID token, hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
  Future<void> signIn(String idToken) async {
    final result = await _api.loginWithGoogle(idToken);
    _api.accessToken = result.accessToken;
    _user = result.user;
    notifyListeners();
    await _prefs.setString(tokenKey, result.accessToken);
    await _prefs.setString(userKey, jsonEncode(result.user.toJson()));
    await _prefs.setBool(welcomeKey, true);
  }

  // Chữ hoa/thường khác nhau là hai tài khoản với backend (sub = "mock:<email>") — gửi chữ thường.
  Future<void> signInDemo(String email) => signIn('mock:${email.trim().toLowerCase()}');

  // Android, macOS. false = người dùng đóng hộp chọn tài khoản. Lỗi → GoogleAuthException hoặc ApiException.
  Future<bool> signInWithGoogle() async {
    final token = await google.signIn();
    if (token == null) return false;
    await signIn(token);
    return true;
  }

  Future<void> skipWelcome() async {
    await _prefs.setBool(welcomeKey, true);
    notifyListeners();
  }

  // Plan trên máy giữ nguyên (plan cục bộ không gắn tài khoản).
  Future<void> signOut() async {
    _api.accessToken = null;
    _user = null;
    notifyListeners();
    await _prefs.remove(tokenKey);
    await _prefs.remove(userKey);
    await google.signOut();
  }

  // Xoá tài khoản và toàn bộ lịch sử trên server (FR-6). Plan đang mở trên máy giữ nguyên, dùng tiếp như khách.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await signOut();
  }

  void _restore() {
    final token = _prefs.getString(tokenKey);
    final userText = _prefs.getString(userKey);
    if (token != null && userText != null) {
      try {
        _user = AuthUser.fromJson(readMap(jsonDecode(userText), userKey));
        _api.accessToken = token;
        return;
      } on FormatException {
        // bản lưu hỏng → xoá bên dưới
      }
    }
    unawaited(_prefs.remove(tokenKey));
    unawaited(_prefs.remove(userKey));
  }
}
