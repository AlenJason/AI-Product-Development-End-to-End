// Ô tìm kiếm tiếng Việt, không phân biệt hoa thường. Gõ không dấu ("ga") thì bỏ dấu cả hai bên, ra "Thịt gà",
// "Gạo tẻ"; gõ có dấu ("cá") thì so đúng dấu, không lẫn "Cà chua" — cùng cách bộ khớp từ khoá của backend đối xử
// với chữ người dùng nhập.
bool matchesSearch(String text, String query) {
  final wanted = query.trim().toLowerCase();
  if (wanted.isEmpty) return true;
  final candidate = text.toLowerCase();
  final plain = removeVietnameseMarks(wanted);
  return plain == wanted ? removeVietnameseMarks(candidate).contains(plain) : candidate.contains(wanted);
}

// "Thịt gà Đậu" → "Thit ga Dau". Bỏ cả dấu rời (U+0300–U+036F) nếu bàn phím gửi chữ ở dạng tách dấu.
String removeVietnameseMarks(String text) {
  final buffer = StringBuffer();
  for (final char in text.split('')) {
    buffer.write(_plainLetter[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp('[̀-ͯ]'), '');
}

const _marked = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _plainLetter = {
  for (final MapEntry(key: plain, value: letters) in _marked.entries)
    for (final letter in letters.split('')) ...{letter: plain, letter.toUpperCase(): plain.toUpperCase()},
};
