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
