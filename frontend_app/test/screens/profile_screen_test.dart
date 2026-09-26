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
    await tester.pumpWidget(harness.screen(ProfileScreen(onCreatePlan: created.add)));

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
}
