import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final login = loadFixture('auth_login');
  final saved = {
    AuthProvider.tokenKey: login['access_token'] as String,
    AuthProvider.userKey: jsonEncode(login['user']),
  };

  Future<(AuthProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    return (AuthProvider(api: backend.api, prefs: prefs), backend, prefs);
  }

  test('đăng nhập → token gắn vào mọi request sau, lưu lại cho lần mở app sau', () async {
    final (auth, backend, prefs) = await create();
    await auth.signIn('mock:lan@example.com');

    expect(auth.isSignedIn, isTrue);
    expect(auth.user!.email, (login['user'] as Map)['email']);
    expect(backend.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(prefs.getString(AuthProvider.tokenKey), login['access_token']);

    await backend.api.history();
    expect(backend.requests.last.headers['Authorization'], 'Bearer ${login['access_token']}');
  });

  test('mở lại app → đọc token đã lưu', () async {
    final (auth, backend, _) = await create(saved);
    expect(auth.isSignedIn, isTrue);
    expect(backend.api.accessToken, login['access_token']);
  });

  test('server trả 401 (token hết hạn) → đăng xuất, xoá token, request sau đi như khách', () async {
    final (auth, backend, prefs) = await create(saved);
    backend.failWith = 401;
    await expectLater(backend.api.generatePlan(Profile.fromJson(loadFixture('profile'))),
        throwsA(isA<UnauthorizedException>()));

    expect(auth.isSignedIn, isFalse);
    expect(backend.api.accessToken, isNull);
    await pumpEventQueue();
    expect(prefs.getKeys(), isEmpty);
  });

  test('đăng nhập hỏng (id_token sai) khi đang đăng nhập → vẫn giữ phiên cũ', () async {
    final (auth, backend, _) = await create(saved);
    backend.failWith = 401;
    await expectLater(auth.signIn('mock:'), throwsA(isA<UnauthorizedException>()));
    expect(auth.isSignedIn, isTrue);
  });

  test('xoá tài khoản → DELETE /api/v1/me rồi đăng xuất', () async {
    final (auth, backend, prefs) = await create(saved);
    await auth.deleteAccount();

    expect(backend.requests.single.method, 'DELETE');
    expect(backend.paths, ['/api/v1/me']);
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getKeys(), isEmpty);
  });

  test('bản lưu hỏng hoặc thiếu một nửa → coi như chưa đăng nhập, xoá sạch', () async {
    final (broken, _, brokenPrefs) = await create({...saved, AuthProvider.userKey: '[]'});
    expect(broken.isSignedIn, isFalse);
    expect(brokenPrefs.getKeys(), isEmpty);

    final (half, halfBackend, halfPrefs) = await create({AuthProvider.tokenKey: 'abc'});
    expect(half.isSignedIn, isFalse);
    expect(halfBackend.api.accessToken, isNull);
    expect(halfPrefs.getKeys(), isEmpty);
  });
}
