import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/services/google_auth.dart';
import 'package:my_ai_app/widgets/login_panel.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

// Bảng đăng nhập (PLAN 8.1, quyết định Q1–Q3): cách đăng nhập theo /health của backend; Google giả (#17).
void main() {
  Future<(Harness, List<String>)> pumpPanel(
    WidgetTester tester, {
    String authMode = 'mock',
    GoogleAuthSupport support = GoogleAuthSupport.interactive,
  }) async {
    final harness = await Harness.create(tester);
    harness.backend.responses['/health'] = {...loadFixture('health'), 'auth_mode': authMode};
    harness.google.support = support;
    final done = <String>[];
    await tester.pumpWidget(harness.screen(LoginPanel(onSignedIn: () => done.add('xong'))));
    await tester.pumpAndSettle();
    return (harness, done);
  }

  Map<String, dynamic> loginBody(Harness harness) =>
      jsonDecode(utf8.decode(harness.backend.requests.last.bodyBytes)) as Map<String, dynamic>;

  testWidgets('backend giả lập → ô email "Đăng nhập demo" (mọi nền tảng); email sai thì chưa bấm được', (tester) async {
    final (harness, done) = await pumpPanel(tester, support: GoogleAuthSupport.unsupported);
    expect(harness.backend.paths, ['/health']);
    expect(find.textContaining('Chế độ demo'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);

    await tester.enterText(field('Email'), 'lan@');
    await tester.pump();
    expect(enabled(tester, 'Đăng nhập demo'), isFalse);

    await tester.enterText(field('Email'), 'Lan@Example.com');
    await tester.pump();
    await tester.tap(find.text('Đăng nhập demo'));
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'mock:lan@example.com'});
    expect(harness.auth.isSignedIn, isTrue);
    expect(done, ['xong']);
  });

  testWidgets('backend Google, Android/macOS → nút Google; người dùng huỷ → không báo lỗi, không gọi backend', (
    tester,
  ) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google');
    expect(find.byType(TextField), findsNothing, reason: 'không có đăng nhập demo khi backend dùng Google (#21)');

    harness.google.token = null;
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(harness.backend.paths, ['/health']);
    expect(done, isEmpty);
    expect(find.textContaining('không thành công'), findsNothing);

    harness.google.token = 'google-id-token';
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'google-id-token'});
    expect(done, ['xong']);
  });

  testWidgets('lỗi Google → câu tiếng Việt; backend từ chối (401) → không nói "phiên hết hạn"', (tester) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google');
    harness.google.error = const GoogleAuthException('Đăng nhập Google không thành công. Vui lòng thử lại.');
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập Google không thành công. Vui lòng thử lại.'), findsOneWidget);

    harness.google.error = null;
    harness.backend.failWith = 401;
    await tester.tap(find.text('Đăng nhập với Google'));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ không chấp nhận lần đăng nhập này. Vui lòng thử lại.'), findsOneWidget);
    expect(find.textContaining('hết hạn'), findsNothing);
    expect(harness.auth.isSignedIn, isFalse);
    expect(done, isEmpty);
  });

  testWidgets('backend Google trên Windows → nói rõ chưa hỗ trợ, vẫn dùng được (quyết định Q3)', (tester) async {
    await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.unsupported);
    expect(find.textContaining('chưa hỗ trợ trên Windows'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);
  });

  testWidgets('bản build thiếu GOOGLE_WEB_CLIENT_ID → nói chưa cấu hình, không có nút', (tester) async {
    await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.notConfigured);
    expect(find.textContaining('chưa được cấu hình đăng nhập Google'), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);
  });

  testWidgets('web → nút do Google vẽ; token tới từ nút → đăng nhập backend; lỗi của nút → câu tiếng Việt', (
    tester,
  ) async {
    final (harness, done) = await pumpPanel(tester, authMode: 'google', support: GoogleAuthSupport.button);
    expect(find.byKey(const Key('google-web-button')), findsOneWidget);
    expect(find.text('Đăng nhập với Google'), findsNothing);

    harness.google.sendWebError(const GoogleAuthException('Không mở được cửa sổ đăng nhập Google trên thiết bị này.'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được cửa sổ đăng nhập Google trên thiết bị này.'), findsOneWidget);

    harness.google.sendWebToken('web-token');
    await tester.pumpAndSettle();
    expect(loginBody(harness), {'id_token': 'web-token'});
    expect(done, ['xong']);
  });

  testWidgets('không tới được máy chủ khi hỏi cách đăng nhập → câu lỗi + "Thử lại"', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.failWith = 503;
    await tester.pumpWidget(harness.screen(LoginPanel(onSignedIn: () {})));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập demo'), findsOneWidget);
    expect(harness.backend.paths, ['/health', '/health']);
  });

  testWidgets('dải nhắc khách: thường / vừa hết phiên', (tester) async {
    final harness = await Harness.create(tester);
    final taps = <String>[];
    await tester.pumpWidget(harness.screen(GuestBanner(onSignIn: () => taps.add('đăng nhập'))));
    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
    await tester.tap(find.text('Đăng nhập'));
    expect(taps, ['đăng nhập']);

    await tester.pumpWidget(harness.screen(GuestBanner(onSignIn: () {}, expired: true)));
    expect(find.textContaining('Phiên đăng nhập đã hết hạn'), findsOneWidget);
    expect(find.text('Đăng nhập lại'), findsOneWidget);
  });
}
