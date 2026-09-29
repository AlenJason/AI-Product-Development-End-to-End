import 'profile_rules.dart';

// Cách nhập hạn chế ở Onboarding và tab "Cá nhân" (quyết định D5): công tắc "Tôi có …" → danh sách phổ biến
// chọn nhiều + "Khác" tự ghi. App ghép lựa chọn thành một chuỗi — hợp đồng API (BRD 6.1) vẫn là văn bản tự do.

class RestrictionOption {
  const RestrictionOption(this.label, {this.hint});

  // Chữ gửi lên backend. Dị ứng và chấn thương phải nằm trong nhãn bộ khớp từ khoá nhận ra
  // (`backend_api/src/plan/data/restriction-keywords.json`) — test `restriction_options_test.dart` kiểm bằng
  // fixture `restriction_labels.json`.
  final String label;
  // Giải thích thêm hiện dưới chip, không gửi đi.
  final String? hint;
}

enum RestrictionKind {
  allergies('Tôi có dị ứng thực phẩm', 'Dị ứng / thực phẩm cần tránh', 'Ví dụ: thịt vịt, rau mùi'),
  injuries('Tôi có chấn thương', 'Chấn thương / vùng cơ thể cần tránh', 'Ví dụ: đau hông khi chạy'),
  healthConditions('Tôi có bệnh nền', 'Tình trạng sức khoẻ / bệnh nền', 'Ví dụ: suy thận, dị ứng thuốc');

  const RestrictionKind(this.toggleLabel, this.title, this.otherHint);

  final String toggleLabel;
  final String title;
  final String otherHint;

  List<RestrictionOption> get options => switch (this) {
    RestrictionKind.allergies => allergyOptions,
    RestrictionKind.injuries => injuryOptions,
    RestrictionKind.healthConditions => healthOptions,
  };
}

const allergyOptions = [
  RestrictionOption('Hải sản', hint: 'tôm, cua, mực, nghêu, sò'),
  RestrictionOption('Cá', hint: 'kể cả nước mắm'),
  RestrictionOption('Đậu phộng'),
  RestrictionOption('Trứng'),
  RestrictionOption('Sữa'),
  RestrictionOption('Đậu nành', hint: 'đậu phụ, nước tương'),
  RestrictionOption('Gluten', hint: 'bột mì, bánh mì'),
  RestrictionOption('Mè'),
  RestrictionOption('Nấm'),
  RestrictionOption('Thịt bò'),
  RestrictionOption('Thịt heo'),
  RestrictionOption('Thịt gà'),
];

const injuryOptions = [
  RestrictionOption('Đầu gối', hint: 'tránh bật nhảy, quỳ gối'),
  RestrictionOption('Cổ chân', hint: 'tránh bật nhảy'),
  RestrictionOption('Cổ tay / khuỷu tay', hint: 'tránh chống tay'),
  RestrictionOption('Lưng / cột sống', hint: 'tránh tải lên lưng'),
  RestrictionOption('Vai', hint: 'tránh đưa tay qua đầu'),
];

// Bệnh nền không lọc được bằng từ khoá: có khoá Gemini thì đưa vào prompt, chế độ giả lập chỉ hiện khuyến cáo.
const healthOptions = [
  RestrictionOption('Tiểu đường'),
  RestrictionOption('Cao huyết áp'),
  RestrictionOption('Gout'),
  RestrictionOption('Tim mạch'),
  RestrictionOption('Dạ dày'),
];

const _separator = ', ';

class RestrictionSelection {
  const RestrictionSelection({this.enabled = false, this.chosen = const {}, this.other = ''});

  // Tắt = không có hạn chế loại này; lựa chọn vẫn giữ để bật lại không phải chọn lại.
  final bool enabled;
  final Set<String> chosen;
  final String other;

  // Chuỗi gửi đi: mục đã chọn theo thứ tự danh sách, rồi phần "Khác". Bộ khớp từ khoá tách theo dấu phẩy.
  String compose(RestrictionKind kind) {
    if (!enabled) return '';
    return [
      for (final option in kind.options)
        if (chosen.contains(option.label)) option.label,
      if (other.trim().isNotEmpty) other.trim(),
    ].join(_separator);
  }

  String? lengthError(RestrictionKind kind) {
    final length = compose(kind).length;
    return length > restrictionMaxLength ? 'Dài $length ký tự, tối đa $restrictionMaxLength' : null;
  }

  // Tách chuỗi đã lưu thành lựa chọn (sửa hồ sơ ở tab "Cá nhân"). Đoạn không khớp mục nào → "Khác".
  static RestrictionSelection parse(String text, RestrictionKind kind) {
    if (text.trim().isEmpty) return const RestrictionSelection();
    final labels = {for (final option in kind.options) option.label.toLowerCase(): option.label};
    final chosen = <String>{};
    final other = <String>[];
    for (final fragment in text.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty)) {
      final label = labels[fragment.toLowerCase()];
      if (label != null) {
        chosen.add(label);
      } else {
        other.add(fragment);
      }
    }
    return RestrictionSelection(enabled: true, chosen: chosen, other: other.join(_separator));
  }

  RestrictionSelection copyWith({bool? enabled, Set<String>? chosen, String? other}) =>
      RestrictionSelection(enabled: enabled ?? this.enabled, chosen: chosen ?? this.chosen, other: other ?? this.other);
}

