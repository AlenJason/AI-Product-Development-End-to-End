import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/screens/grocery_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

void main() {
  final plan = MealPlan.fromJson(loadFixture('generate_plan'));
  final total = plan.groceryList.fold<int>(0, (sum, group) => sum + group.items.length);
  final first = plan.groceryList.first.items.first;

  Future<Harness> pumpGrocery(WidgetTester tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.screen(const GroceryScreen()));
    return harness;
  }

  testWidgets('dựng từ grocery_list, tên nhóm theo BRD FR-3.1, không có nút "Thêm nguyên liệu"', (tester) async {
    await pumpGrocery(tester);
    expect(find.text('0/$total đã mua'), findsOneWidget);
    expect(find.text('ĐẠM'), findsOneWidget);
    expect(find.text(first.name), findsOneWidget);
    expect(find.text(first.quantity), findsWidgets);
    expect(find.text('Thêm nguyên liệu'), findsNothing);
  });

  testWidgets('tích "đã mua" tăng bộ đếm; mở lại màn vẫn còn', (tester) async {
    final harness = await pumpGrocery(tester);
    await tester.tap(find.text(first.name));
    await tester.pump();
    expect(find.text('1/$total đã mua'), findsOneWidget);

    await tester.pumpWidget(harness.screen(const GroceryScreen(key: ValueKey('mở lại'))));
    expect(find.text('1/$total đã mua'), findsOneWidget);
  });

  testWidgets('"đã có sẵn" ẩn món khỏi danh sách cần mua, "Cần mua" đưa lại (FR-3.2)', (tester) async {
    await pumpGrocery(tester);
    await tester.tap(find.byTooltip('Đã có sẵn trong tủ lạnh').first);
    await tester.pump();
    expect(find.text('0/${total - 1} đã mua'), findsOneWidget);
    await scrollTo(tester, find.text('1 món đã có sẵn'));

    await tester.tap(find.text('Hiện lại'));
    await tester.pump();
    await scrollTo(tester, find.text('Cần mua'));
    await tester.tap(find.text('Cần mua'));
    await tester.pump();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.text('0/$total đã mua'), findsOneWidget);
  });

  testWidgets('tìm kiếm và lọc theo nhóm', (tester) async {
    await pumpGrocery(tester);
    await tester.enterText(find.byType(TextField), first.name.substring(0, 3));
    await tester.pump();
    expect(find.text(first.name), findsOneWidget);
    // Gõ không dấu vẫn ra (trước đây "ga" không ra "Thịt gà").
    await tester.enterText(find.byType(TextField), 'ga');
    await tester.pump();
    expect(find.text('Thịt gà bỏ da'), findsOneWidget);
    expect(find.text('Gạo tẻ'), findsOneWidget);
    expect(find.text('Tỏi'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Rau củ quả').first);
    await tester.pump();
    expect(find.text('ĐẠM'), findsNothing);
    expect(find.text('RAU CỦ QUẢ'), findsOneWidget);
  });
}
