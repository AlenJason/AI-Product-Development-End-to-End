import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/restriction_options.dart';

import '../fixture_loader.dart';

void main() {
  // Bộ khớp từ khoá của backend tách chữ theo các dấu này (restriction-matcher.ts, FRAGMENT_SEPARATOR).
  List<String> fragments(String label) => label
      .toLowerCase()
      .split(RegExp(r'[,;./+&]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  test('mọi chip dị ứng và chấn thương đều là nhãn backend nhận ra (fixture restriction_labels, D5)', () {
    final labels = loadFixture('restriction_labels');
    final allergies = (labels['allergies'] as List).cast<String>().toSet();
    final injuries = (labels['injuries'] as List).cast<String>().toSet();
    for (final option in allergyOptions) {
      expect(fragments(option.label).every(allergies.contains), isTrue, reason: option.label);
    }
    for (final option in injuryOptions) {
      expect(fragments(option.label).every(injuries.contains), isTrue, reason: option.label);
    }
  });

  test('tắt công tắc → chuỗi rỗng (không có hạn chế), dù vẫn còn lựa chọn', () {
    const selection = RestrictionSelection(enabled: false, chosen: {'Trứng'}, other: 'thịt vịt');
    expect(selection.compose(RestrictionKind.allergies), '');
  });

  test('ghép theo thứ tự danh sách rồi phần "Khác", tách ngược lại được', () {
    const selection = RestrictionSelection(enabled: true, chosen: {'Trứng', 'Hải sản'}, other: ' thịt vịt ');
    final text = selection.compose(RestrictionKind.allergies);
    expect(text, 'Hải sản, Trứng, thịt vịt');

    final parsed = RestrictionSelection.parse(text, RestrictionKind.allergies);
    expect(parsed.enabled, isTrue);
    expect(parsed.chosen, {'Hải sản', 'Trứng'});
    expect(parsed.other, 'thịt vịt');
    expect(parsed.compose(RestrictionKind.allergies), text);
  });

  test('chuỗi cũ gõ tay (trước D5) vẫn tách được, không phân biệt hoa thường', () {
    final parsed = RestrictionSelection.parse('hải sản, đau bụng khi ăn cay', RestrictionKind.allergies);
    expect(parsed.chosen, {'Hải sản'});
    expect(parsed.other, 'đau bụng khi ăn cay');
    expect(RestrictionSelection.parse('  ', RestrictionKind.injuries).enabled, isFalse);
  });

  test('báo lỗi khi chuỗi ghép vượt 300 ký tự', () {
    final selection = RestrictionSelection(enabled: true, other: 'a' * 301);
    expect(selection.lengthError(RestrictionKind.healthConditions), isNotNull);
    expect(
      const RestrictionSelection(enabled: true, chosen: {'Gout'}).lengthError(RestrictionKind.healthConditions),
      isNull,
    );
  });
}
