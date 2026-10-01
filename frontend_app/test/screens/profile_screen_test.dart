import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/screens/profile_screen.dart';

import '../app_harness.dart';

void main() {
  testWidgets('xem hồ sơ; sửa mục tiêu → lưu nháp, plan vẫn giữ hồ sơ cũ; tạo kế hoạch mới bằng hồ sơ đã sửa', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    final created = <Profile>[];
    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: created.add, onSignIn: () {})));

    expect(find.text('Nữ'), findsOneWidget);
    expect(find.text('Hải sản'), findsOneWidget);
    expect(find.textContaining('kcal/ngày'), findsOneWidget);

    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Tăng cơ nạc'));
    await tester.tap(find.text('Tăng cơ nạc'));
    await scrollTo(tester, find.text('Lưu hồ sơ'));
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();

    expect(harness.plans.hasPendingProfile, isTrue);
    expect(harness.plans.profile!.goal, Goal.cut);
    await scrollTo(tester, find.text('Tăng cơ nạc'));
    expect(find.textContaining('kcal/ngày'), findsNothing, reason: 'mục tiêu calo cũ không còn đúng với hồ sơ mới');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo kế hoạch mới'));
    expect(created.single.goal, Goal.bulk);
    expect(created.single.restrictions.allergies, 'Hải sản');
  });

  // Giai đoạn 8 (FR-6, quyết định Q6): mục Tài khoản khi đã đăng nhập, dải nhắc khi dùng như khách.
  testWidgets('khách → dải nhắc "chỉ lưu trên máy này" + nút đăng nhập; không có mục Tài khoản', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    final signIns = <String>[];
    await tester.pumpWidget(
      harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () => signIns.add('đăng nhập'))),
    );
    expect(find.text('Bạn đang dùng không đăng nhập — kế hoạch chỉ lưu trên máy này.'), findsOneWidget);
    expect(find.text('TÀI KHOẢN'), findsNothing);
    await tester.tap(find.text('Đăng nhập'));
    expect(signIns, ['đăng nhập']);
  });

  testWidgets('đã đăng nhập → tên, email; "Đăng xuất" về khách, plan trên máy giữ nguyên', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
    expect(find.textContaining('Bạn đang dùng không đăng nhập'), findsNothing);
    await scrollTo(tester, find.text('TÀI KHOẢN'));
    expect(find.text('sv@vku.edu.vn'), findsOneWidget);

    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(harness.auth.isSignedIn, isFalse);
    expect(harness.plans.hasPlan, isTrue);
    expect(find.text('Đã đăng xuất. Kế hoạch trên máy này vẫn giữ.'), findsOneWidget);
    expect(find.text('TÀI KHOẢN'), findsNothing);
    expect(harness.google.signOutCalls, 1);
  });

  testWidgets('xoá tài khoản: hỏi lại; Huỷ → không gọi server; xác nhận → DELETE /me, về khách, plan giữ', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
    await scrollTo(tester, find.text('Xoá tài khoản'));
    await tester.tap(find.text('Xoá tài khoản'));
    await tester.pumpAndSettle();
    expect(find.textContaining('toàn bộ lịch sử kế hoạch trên máy chủ sẽ bị xoá vĩnh viễn'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(harness.backend.requests, isEmpty);
    expect(harness.auth.isSignedIn, isTrue);

    await tester.tap(find.text('Xoá tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá vĩnh viễn'));
    await tester.pumpAndSettle();
    expect(harness.backend.requests.single.method, 'DELETE');
    expect(harness.backend.paths, ['/api/v1/me']);
    expect(harness.auth.isSignedIn, isFalse);
    expect(harness.plans.hasPlan, isTrue);
    expect(find.text('Đã xoá tài khoản và lịch sử kế hoạch.'), findsOneWidget);
  });

  testWidgets('xoá tài khoản lỗi → câu lỗi, vẫn đăng nhập', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), ...signedIn()});
    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: (_) {}, onSignIn: () {})));
    harness.backend.failWith = 503;
    await scrollTo(tester, find.text('Xoá tài khoản'));
    await tester.tap(find.text('Xoá tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá vĩnh viễn'));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'), findsOneWidget);
    expect(harness.auth.isSignedIn, isTrue);
  });
}
