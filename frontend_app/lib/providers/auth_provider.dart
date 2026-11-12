import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';

// Đăng nhập (BRD FR-6, 6.3). Không đăng nhập vẫn dùng đủ tính năng như khách; đăng nhập để lưu lịch sử plan trên DB localhost.
// JWT (7 ngày) lưu trong shared_preferences như BRD mục 4 — trên web là localStorage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._prefs}) {
    _restore();
    // Token hết hạn hoặc tài khoản đã xoá → server trả 401 → về chế độ khách và nhắc đăng nhập lại.
    _api.onUnauthorized = () => unawaited(signOut(expired: true));
  }

  static const tokenKey = 'smartfit.access_token';
  static const userKey = 'smartfit.user.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;
  bool _busy = false;
  String? _error;
  bool _sessionExpired = false;

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;
  bool get busy => _busy;
  String? get error => _error;
  bool get sessionExpired => _sessionExpired;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void dismissSessionExpired() {
    if (!_sessionExpired) return;
    _sessionExpired = false;
    notifyListeners();
  }

  // `idToken`: giữ tương thích với test cũ.
  Future<void> signIn(String idToken) async {
    await _runAuth(() => _api.loginWithGoogle(idToken));
  }

  Future<bool> register({
    required String email,
    required String name,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      _error = 'Vui lòng nhập họ tên.';
      notifyListeners();
      return false;
    }
    if (trimmedEmail.isEmpty ||
        !trimmedEmail.contains('@') ||
        !trimmedEmail.contains('.')) {
      _error = 'Vui lòng nhập email hợp lệ.';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _error = 'Mật khẩu tối thiểu 6 ký tự.';
      notifyListeners();
      return false;
    }
    try {
      await _runAuth(
        () => _api.register(
          email: trimmedEmail,
          name: trimmedName,
          password: password,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty ||
        !trimmedEmail.contains('@') ||
        !trimmedEmail.contains('.')) {
      _error = 'Vui lòng nhập email hợp lệ.';
      notifyListeners();
      return false;
    }
    if (password.isEmpty) {
      _error = 'Vui lòng nhập mật khẩu.';
      notifyListeners();
      return false;
    }
    try {
      await _runAuth(
        () => _api.login(email: trimmedEmail, password: password),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      _error = 'Vui lòng nhập mật khẩu hiện tại.';
      notifyListeners();
      return false;
    }
    if (newPassword.length < 6) {
      _error = 'Mật khẩu mới tối thiểu 6 ký tự.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Không thể đổi mật khẩu. Vui lòng thử lại.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<List<PlanSummary>> fetchHistory() => _api.history();

  Future<MealPlan> fetchHistoryPlan(String id) => _api.historyPlan(id);

  Future<void> _runAuth(Future<AuthResult> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await action();
      _api.accessToken = result.accessToken;
      _user = result.user;
      _sessionExpired = false;
      await _prefs.setString(tokenKey, result.accessToken);
      await _prefs.setString(userKey, jsonEncode(result.user.toJson()));
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Không thể kết nối máy chủ. Hãy kiểm tra backend localhost đang chạy.';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut({bool expired = false}) async {
    _api.accessToken = null;
    _user = null;
    _error = null;
    _sessionExpired = expired;
    notifyListeners();
    await _prefs.remove(tokenKey);
    await _prefs.remove(userKey);
  }

  // Xoá tài khoản và toàn bộ lịch sử trên server (FR-6). Plan đang mở trên máy giữ nguyên, dùng tiếp như khách.
  Future<void> deleteAccount() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _api.deleteAccount();
      _busy = false;
      await signOut();
    } catch (error) {
      _error = error is ApiException
          ? error.message
          : 'Không thể xoá tài khoản lúc này. Vui lòng thử lại.';
      _busy = false;
      notifyListeners();
      rethrow;
    }
  }

  void _restore() {
    try {
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
    } on TypeError {
      // Ignore incompatible local auth data without blocking offline plans.
    }
  }
}
