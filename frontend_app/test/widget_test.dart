import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';

void main() {
  testWidgets('SmartFitApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartFitApp());
    expect(find.text('MỤC TIÊU HÔM NAY'), findsOneWidget);
  });
}
