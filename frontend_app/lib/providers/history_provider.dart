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
