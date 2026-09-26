import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../services/api_client.dart';

// Đăng nhập (BRD FR-6, 6.3). Không đăng nhập vẫn dùng đủ tính năng như khách; đăng nhập để có lịch sử plan.
// JWT (7 ngày) lưu trong shared_preferences như BRD mục 4 — trên web là localStorage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._prefs}) {
    _restore();
    // Token hết hạn hoặc tài khoản đã xoá → server trả 401 → về chế độ khách.
    _api.onUnauthorized = () => unawaited(signOut());
  }

  static const tokenKey = 'smartfit.access_token';
  static const userKey = 'smartfit.user.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;

  // `idToken`: Google ID token (giai đoạn 8), hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
  Future<void> signIn(String idToken) async {
    final result = await _api.loginWithGoogle(idToken);
    _api.accessToken = result.accessToken;
    _user = result.user;
    notifyListeners();
    await _prefs.setString(tokenKey, result.accessToken);
    await _prefs.setString(userKey, jsonEncode(result.user.toJson()));
  }

  Future<void> signOut() async {
    _api.accessToken = null;
    _user = null;
    notifyListeners();
    await _prefs.remove(tokenKey);
    await _prefs.remove(userKey);
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
