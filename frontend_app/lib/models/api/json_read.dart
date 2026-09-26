// Đọc JSON từ backend một cách chặt chẽ: thiếu trường hoặc sai kiểu → FormatException nêu rõ trường nào,
// thay vì lỗi kiểu `Null is not a subtype of String` khó hiểu. Nơi gọi (ApiClient, provider) bắt FormatException.

typedef Json = Map<String, dynamic>;

Json readMap(Object? value, String field) {
  if (value is Map<String, dynamic>) return value;
  throw FormatException('"$field" phải là object JSON');
}

List<T> readList<T>(Json json, String field, T Function(Object? item) parse) {
  final value = json[field];
  if (value is! List) throw FormatException('"$field" phải là mảng');
  return List.unmodifiable(value.map(parse));
}

String readString(Json json, String field) {
  final value = json[field];
  if (value is String) return value;
  throw FormatException('"$field" phải là chuỗi');
}

// Giữ nguyên int hay double như server gửi, để gửi lại plan đúng từng con số (đổi món, feedback — BRD 6.4).
num readNum(Json json, String field) {
  final value = json[field];
  if (value is num) return value;
  throw FormatException('"$field" phải là số');
}

int readInt(Json json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  throw FormatException('"$field" phải là số nguyên');
}

// Mã cố định (meal_type, unit, muscle_group…): mã lạ → FormatException, không đoán.
T readCode<T extends Enum>(Json json, String field, List<T> values, String Function(T value) code) {
  final value = readString(json, field);
  for (final candidate in values) {
    if (code(candidate) == value) return candidate;
  }
  throw FormatException('"$field" có mã không hợp lệ: $value');
}
