import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/profile_rules.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';

import '../app_harness.dart';

void main() {
  Future<List<Profile>> pumpOnboarding(WidgetTester tester, {Profile? initial}) async {
    final submitted = <Profile>[];
    final harness = await Harness.create(tester);
    await tester.pumpWidget(harness.screen(OnboardingScreen(initial: initial, onSubmit: submitted.add)));
    return submitted;
  }

  testWidgets('bước 1: khoá "Tiếp tục" tới khi đủ và hợp lệ; dưới 18 tuổi báo lỗi', (tester) async {
    await pumpOnboarding(tester);
    expect(find.text('Bước 1/3 · Thông tin cơ thể'), findsOneWidget);
    expect(enabled(tester, 'Tiếp tục'), isFalse);

    await tester.tap(find.text('Nữ'));
    await tester.enterText(field('Tuổi'), '17');
    await tester.enterText(field('Chiều cao (cm)'), '168');
    await tester.enterText(field('Cân nặng (kg)'), '62,5');
    await tester.pump();
    expect(find.text('SmartFit dành cho người từ 18 tuổi'), findsOneWidget);
    expect(enabled(tester, 'Tiếp tục'), isFalse);

    await tester.enterText(field('Tuổi'), '22');
    await tester.pump();
    expect(enabled(tester, 'Tiếp tục'), isTrue);
  });

  testWidgets('chỉ nữ mới có ô mang thai / cho con bú', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Nam'));
    await tester.pump();
    expect(find.text('Đang mang thai hoặc cho con bú'), findsNothing);
    await tester.tap(find.text('Nữ'));
    await tester.pump();
    expect(find.text('Đang mang thai hoặc cho con bú'), findsOneWidget);
  });

  testWidgets('bước 2: thiếu cân → "Giảm mỡ" bị khoá kèm lý do (D6-A1)', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Nữ'));
    await tester.enterText(field('Tuổi'), '20');
    await tester.enterText(field('Chiều cao (cm)'), '160');
    await tester.enterText(field('Cân nặng (kg)'), '42');
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    expect(find.text(underweightCutMessage), findsOneWidget);
    expect(find.byIcon(Icons.block), findsOneWidget);
    await tester.tap(find.text('Vận động nhẹ'));
    await tester.tap(find.text('Giảm mỡ & giữ cơ'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: 'chỉ mức vận động được chọn, không phải Giảm mỡ');
    expect(enabled(tester, 'Tiếp tục'), isFalse, reason: 'bấm vào thẻ bị khoá không chọn được');
    await tester.tap(find.text('Duy trì vóc dáng'));
    await tester.pump();
    expect(enabled(tester, 'Tiếp tục'), isTrue);
  });

  testWidgets('mang thai → "Giảm mỡ" bị khoá (D6-A3); gửi đi kèm cờ', (tester) async {
    final submitted = await pumpOnboarding(tester);
    await tester.tap(find.text('Nữ'));
    await tester.pump();
    await tester.tap(find.text('Đang mang thai hoặc cho con bú'));
    await tester.enterText(field('Tuổi'), '28');
    await tester.enterText(field('Chiều cao (cm)'), '160');
    await tester.enterText(field('Cân nặng (kg)'), '60');
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text(pregnantCutMessage), findsOneWidget);
    await tester.tap(find.text('Ít vận động'));
    await tester.tap(find.text('Duy trì vóc dáng'));
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    expect(submitted.single.pregnantOrBreastfeeding, isTrue);
    expect(submitted.single.goal, Goal.maintain);
  });

  testWidgets('bước 3 (D5): công tắc tắt = không có; bật → chip + "Khác"; gửi đúng chuỗi ghép', (tester) async {
    final submitted = await pumpOnboarding(tester);
    await fillOnboarding(tester);
    await tester.tap(find.text('Trứng'));
    await tester.tap(find.text('Khác').first);
    await tester.pumpAndSettle();
    await tester.enterText(field('Dị ứng / thực phẩm cần tránh'), 'thịt vịt');
    await tester.pump();
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));

    final profile = submitted.single;
    expect(profile.toJson(), {
      'age': 22,
      'gender': 'female',
      'height_cm': 168,
      'weight_kg': 62,
      'activity_level': 'light',
      'goal': 'cut',
      'pregnant_or_breastfeeding': false,
      'restrictions': {'allergies': 'Hải sản, Trứng, thịt vịt', 'injuries': 'Đầu gối', 'health_conditions': ''},
    });
  });

  testWidgets('nút Back của hệ thống quay lại bước trước, giữ dữ liệu đã nhập', (tester) async {
    await pumpOnboarding(tester);
    await tester.tap(find.text('Nữ'));
    await tester.enterText(field('Tuổi'), '22');
    await tester.enterText(field('Chiều cao (cm)'), '168');
    await tester.enterText(field('Cân nặng (kg)'), '62');
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Bước 2/3 · Mục tiêu & vận động'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Bước 1/3 · Thông tin cơ thể'), findsOneWidget);
    expect(find.text('168'), findsOneWidget);
  });

  testWidgets('điền sẵn hồ sơ cũ (sửa sau lỗi 400 hoặc hồ sơ không còn hợp lệ)', (tester) async {
    await pumpOnboarding(
      tester,
      initial: const Profile(
        age: 17,
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
        activityLevel: ActivityLevel.active,
        goal: Goal.bulk,
        restrictions: Restrictions(allergies: 'Hải sản, thịt vịt'),
      ),
    );
    expect(find.text('SmartFit dành cho người từ 18 tuổi'), findsOneWidget);
    expect(find.text('175'), findsOneWidget);
  });
}
