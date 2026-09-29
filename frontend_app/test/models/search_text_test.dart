import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/search_text.dart';

void main() {
  test('gõ không dấu → bỏ dấu cả hai bên, kể cả đ và chữ hoa', () {
    expect(matchesSearch('Thịt gà bỏ da', 'ga'), isTrue);
    expect(matchesSearch('Gạo tẻ', 'ga'), isTrue);
    expect(matchesSearch('Đậu phụ', 'DAU'), isTrue);
    expect(matchesSearch('Cà chua', 'ca chua'), isTrue);
  });

  test('gõ có dấu → so đúng dấu: "cá" không ra "Cà chua"', () {
    expect(matchesSearch('Cá lóc', 'cá'), isTrue);
    expect(matchesSearch('Cà chua', 'cá'), isFalse);
    expect(matchesSearch('Bơ', 'bò'), isFalse);
  });

  test('ô trống hoặc chỉ có khoảng trắng → khớp mọi thứ; không có thì không khớp', () {
    expect(matchesSearch('Tỏi', ''), isTrue);
    expect(matchesSearch('Tỏi', '  '), isTrue);
    expect(matchesSearch('Tỏi', 'hanh'), isFalse);
  });

  test('bỏ dấu, kể cả dấu rời', () {
    expect(removeVietnameseMarks('Thịt gà Đậu phụ Ưu'), 'Thit ga Dau phu Uu');
    expect(removeVietnameseMarks('gà'), 'ga');
  });
}
