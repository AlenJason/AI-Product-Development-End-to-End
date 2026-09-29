# F03 — App: luật hồ sơ, danh sách hạn chế (D5), lịch ngày (D6-B1), provider

## Feature

Phần logic thuần của app, chưa đụng giao diện (giao diện cũ vẫn chạy nguyên ở mốc này):

| File | Việc |
|---|---|
| `lib/models/profile_rules.dart` | Giới hạn giống backend (tuổi 18–100, chiều cao 100–250, cân nặng 30–250, 300 ký tự) và luật an toàn (#30): `cutBlockReason()` so BMI **chưa làm tròn** < 18,5, mang thai → không Giảm mỡ; `profileProblems()` kiểm hồ sơ đã lưu; nhận dấu phẩy thập phân ("62,5") |
| `lib/models/restriction_options.dart` | Chip dị ứng (12), chấn thương (5), bệnh nền (5); `RestrictionSelection.compose()` ghép theo thứ tự danh sách rồi phần "Khác", nối ", " (bộ khớp backend tách theo dấu phẩy); tắt công tắc → chuỗi rỗng nhưng giữ lựa chọn; `parse()` tách chuỗi đã lưu (kể cả chuỗi gõ tay trước D5) |
| `lib/models/plan_schedule.dart` | `PlanSchedule(planId, startDate)` chỉ giữ ngày (UTC để phép trừ ngày không lệch); `dayNumberOn(now)`: < 1 chưa bắt đầu, > 3 đã hết; `vietnameseDate()` |
| `lib/providers/plan_provider.dart` | Thêm lịch (`smartfit.plan_schedule.v1`: tạo mới → hôm nay, feedback ngày 3 trả plan mới → ngày mai, đổi món/bài giữ nguyên), bản nháp hồ sơ (`smartfit.profile_draft.v1`: `saveDraft()` giống hồ sơ của plan thì xoá; `generate()` bỏ nháp), `todayNumber`, đồng hồ tiêm được (`now:`). Hồ sơ đã lưu mà nay bị luật v2.6.0 chặn → bỏ plan, giữ hồ sơ |
| `lib/providers/grocery_provider.dart` | Đã mua / đã có sẵn theo từng plan (`smartfit.grocery.v1`); khoá dòng = nhóm + tên + lượng (đổi món làm lượng đổi → dòng đó bỏ tích); nghe `PlanProvider`, plan mới → xoá trạng thái; bản lưu hỏng hoặc của plan khác → bỏ |

`Profile.sameAs()` (F01) so hai hồ sơ theo JSON gửi đi — dùng để biết bản nháp có khác hồ sơ của plan không.

**Vì sao tách "hồ sơ của plan" và "hồ sơ đang sửa":** đổi món/feedback gửi `profile` + `plan`; backend tính lại mục tiêu từ `profile`, khác `daily_target` của plan → 409 (#24). Nếu sửa hồ sơ ghi thẳng vào hồ sơ của plan thì mọi lần đổi món sau đó đều hỏng.

## Scope

UI-only (logic + test):

- `frontend_app/lib/models/profile_rules.dart`, `restriction_options.dart`, `plan_schedule.dart`, `lib/providers/grocery_provider.dart` (mới)
- `frontend_app/lib/providers/plan_provider.dart` (viết lại)
- `frontend_app/test/fake_backend.dart` (sửa: `responses` thay JSON cho một đường dẫn)
- `frontend_app/test/models/profile_rules_test.dart`, `restriction_options_test.dart`, `plan_schedule_test.dart`, `test/providers/grocery_provider_test.dart` (mới); `test/providers/plan_provider_test.dart` (sửa)

## Implementation

### API Routes

Không có.

### UI Components

Không có (F04 dùng).

### DB / KV Changes

Khoá `shared_preferences` mới: `smartfit.plan_schedule.v1`, `smartfit.profile_draft.v1`, `smartfit.grocery.v1`. Không migration: bản lưu hỏng hoặc thiếu → bỏ / coi như bắt đầu hôm nay.

### Ràng buộc áp dụng

- **#12, #28** hồ sơ, bản nháp chỉ lưu trên máy; không log.
- **#24** đổi món/feedback luôn gửi hồ sơ của plan.
- **#30** ngưỡng giống backend; **#32** mọi chip dị ứng/chấn thương nằm trong `restriction_labels.json` (test kiểm, tách theo cùng dấu phân cách như backend).

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+67: All tests passed!` (giao diện cũ vẫn chạy)

## Test Checklist

1. **@rules**: giới hạn tuổi/chiều cao/cân nặng, dấu phẩy thập phân; BMI 18,46 bị chặn, 18,51 qua; mang thai → chặn; hồ sơ 17 tuổi / thiếu cân + Giảm mỡ / nam + mang thai có lỗi
2. **@chips**: mọi chip dị ứng/chấn thương ⊆ nhãn backend; tắt công tắc → rỗng; ghép/tách vòng tròn; chuỗi gõ tay cũ tách được; > 300 ký tự báo lỗi
3. **@schedule**: 23:30 tạo plan → 0:01 hôm sau là ngày 2; < 1, > 3; qua tháng; lưu/đọc lại
4. **@provider**: tạo plan → lịch hôm nay; mở hôm sau → ngày 2; đổi món giữ lịch; feedback ngày 3 → plan mới bắt đầu ngày mai; plan giai đoạn 5 chưa có lịch → hôm nay; nháp khác hồ sơ → chờ, đổi món vẫn gửi hồ sơ cũ; nháp giống → xoá; `generate()` bỏ nháp; hồ sơ 17 tuổi → bỏ plan giữ hồ sơ
5. **@grocery**: đã mua, đã có sẵn, mở lại còn; khoá gồm lượng; plan mới → xoá; bản lưu của plan khác / hỏng → bỏ
6. **@auth**, **@timeout**, **@token**: không đổi

## Tasks

### Task 1 — Luật hồ sơ

`frontend_app/lib/models/profile_rules.dart`:

```dart
import 'api/codes.dart';
import 'api/profile.dart';

// Giới hạn và luật an toàn giống hệt backend (`backend_api/src/plan/dto/create-plan.dto.ts`,
// `profile-safety.ts`, BRD 6.1 và FR-1.3 v2.6.0). App dùng để báo lỗi ngay khi nhập và khoá lựa chọn;
// backend vẫn kiểm lại và trả 400.
const minAge = 18;
const maxAge = 100;
const minHeightCm = 100;
const maxHeightCm = 250;
const minWeightKg = 30;
const maxWeightKg = 250;
const restrictionMaxLength = 300;
const underweightBmi = 18.5;

const underweightCutMessage =
    'Chỉ số BMI dưới 18,5 (thiếu cân) nên không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng hoặc Tăng cơ.';
const pregnantCutMessage =
    'Đang mang thai hoặc cho con bú thì không chọn được Giảm mỡ. Hãy chọn Duy trì vóc dáng và hỏi ý kiến bác sĩ.';

// Số nhập vào ô: chấp nhận cả dấu phẩy thập phân kiểu Việt ("62,5").
num? parseNumber(String text) => num.tryParse(text.trim().replaceAll(',', '.'));

String? ageError(String text) {
  final value = int.tryParse(text.trim());
  if (text.trim().isEmpty) return 'Nhập tuổi';
  if (value == null) return 'Tuổi phải là số nguyên';
  if (value < minAge) return 'SmartFit dành cho người từ $minAge tuổi';
  if (value > maxAge) return 'Tuổi tối đa là $maxAge';
  return null;
}

String? heightError(String text) => _rangeError(text, 'chiều cao', minHeightCm, maxHeightCm, 'cm');

String? weightError(String text) => _rangeError(text, 'cân nặng', minWeightKg, maxWeightKg, 'kg');

String? _rangeError(String text, String label, num min, num max, String unit) {
  if (text.trim().isEmpty) return 'Nhập $label';
  final value = parseNumber(text);
  if (value == null) return '${label[0].toUpperCase()}${label.substring(1)} phải là số';
  if (value < min || value > max) return 'Trong khoảng $min–$max $unit';
  return null;
}

// BMI chưa làm tròn — so với ngưỡng giống backend (làm tròn trước sẽ cho 18,46 lọt thành 18,5).
double bodyMassIndex(num heightCm, num weightKg) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

// Lý do không được chọn Giảm mỡ, hoặc null.
String? cutBlockReason({required num heightCm, required num weightKg, required bool pregnantOrBreastfeeding}) {
  if (pregnantOrBreastfeeding) return pregnantCutMessage;
  if (bodyMassIndex(heightCm, weightKg) < underweightBmi) return underweightCutMessage;
  return null;
}

// Hồ sơ đã lưu trên máy có còn hợp lệ theo luật hiện tại không (hồ sơ lưu trước v2.6.0 có thể dưới 18 tuổi).
List<String> profileProblems(Profile profile) => [
  ?ageError('${profile.age}'),
  ?heightError('${profile.heightCm}'),
  ?weightError('${profile.weightKg}'),
  if (profile.pregnantOrBreastfeeding && profile.gender != Gender.female) 'Chỉ nữ mới khai báo mang thai / cho con bú',
  if (profile.goal == Goal.cut)
    ?cutBlockReason(
      heightCm: profile.heightCm,
      weightKg: profile.weightKg,
      pregnantOrBreastfeeding: profile.pregnantOrBreastfeeding,
    ),
  for (final text in [
    profile.restrictions.allergies,
    profile.restrictions.injuries,
    profile.restrictions.healthConditions,
  ])
    if (text.length > restrictionMaxLength) 'Mỗi mục hạn chế tối đa $restrictionMaxLength ký tự',
];
```

`frontend_app/test/models/profile_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/models/profile_rules.dart';

import '../fixture_loader.dart';

// Giới hạn và luật an toàn phải giống backend (BRD 6.1, FR-1.3 v2.6.0) — lệch thì app khoá sai hoặc backend trả 400.
void main() {
  test('tuổi 18–100, số nguyên; chiều cao 100–250 cm; cân nặng 30–250 kg; nhận dấu phẩy thập phân', () {
    expect(ageError('17'), isNotNull);
    expect(ageError('18'), isNull);
    expect(ageError('100'), isNull);
    expect(ageError('101'), isNotNull);
    expect(ageError('22.5'), isNotNull);
    expect(ageError(''), isNotNull);
    expect(heightError('99'), isNotNull);
    expect(heightError('168'), isNull);
    expect(weightError('62,5'), isNull);
    expect(parseNumber('62,5'), 62.5);
    expect(weightError('251'), isNotNull);
  });

  test('khoá Giảm mỡ khi thiếu cân — so BMI chưa làm tròn như backend', () {
    expect(bodyMassIndex(160, 42), closeTo(16.4, 0.05));
    expect(cutBlockReason(heightCm: 160, weightKg: 42, pregnantOrBreastfeeding: false), underweightCutMessage);
    expect(cutBlockReason(heightCm: 170, weightKg: 53.35, pregnantOrBreastfeeding: false), underweightCutMessage);
    expect(cutBlockReason(heightCm: 170, weightKg: 53.5, pregnantOrBreastfeeding: false), isNull);
  });

  test('khoá Giảm mỡ khi mang thai / cho con bú', () {
    expect(cutBlockReason(heightCm: 160, weightKg: 70, pregnantOrBreastfeeding: true), pregnantCutMessage);
  });

  test('hồ sơ đã lưu: hồ sơ fixture hợp lệ; hồ sơ trước v2.6.0 dưới 18 tuổi hoặc thiếu cân + Giảm mỡ thì không', () {
    final valid = Profile.fromJson(loadFixture('profile'));
    expect(profileProblems(valid), isEmpty);

    Profile variant({int age = 22, num weight = 62, Gender gender = Gender.female, bool pregnant = false}) => Profile(
      age: age,
      gender: gender,
      heightCm: 168,
      weightKg: weight,
      activityLevel: ActivityLevel.light,
      goal: Goal.cut,
      pregnantOrBreastfeeding: pregnant,
    );
    expect(profileProblems(variant(age: 17)), isNotEmpty);
    expect(profileProblems(variant(weight: 45)), [underweightCutMessage]);
    expect(profileProblems(variant(pregnant: true)), [pregnantCutMessage]);
    expect(profileProblems(variant(gender: Gender.male, pregnant: true)), hasLength(2));
  });
}
```

### Task 2 — Danh sách hạn chế (D5)

`frontend_app/lib/models/restriction_options.dart`:

```dart
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
```

`frontend_app/test/models/restriction_options_test.dart`:

```dart
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
```

### Task 3 — Lịch ngày

`frontend_app/lib/models/plan_schedule.dart`:

```dart
import 'api/json_read.dart';

// Ngày bắt đầu của plan đang mở (quyết định D6-B1). Plan (BRD 6.2) chỉ có ngày 1–3, không có ngày theo lịch —
// app tự lưu để mở đúng ngày hôm nay. Ngày tính theo giờ trên máy, không có giờ phút.
class PlanSchedule {
  const PlanSchedule({required this.planId, required this.startDate});

  final String planId;
  final DateTime startDate;

  factory PlanSchedule.startingOn(String planId, DateTime day) =>
      PlanSchedule(planId: planId, startDate: dateOnly(day));

  factory PlanSchedule.fromJson(Json json) {
    final start = DateTime.tryParse(readString(json, 'start_date'));
    if (start == null) throw const FormatException('"start_date" phải là ngày yyyy-mm-dd');
    return PlanSchedule(planId: readString(json, 'plan_id'), startDate: dateOnly(start));
  }

  Json toJson() => {
    'plan_id': planId,
    'start_date': '${startDate.year.toString().padLeft(4, '0')}-${_two(startDate.month)}-${_two(startDate.day)}',
  };

  // Ngày thứ mấy của plan vào [now]: < 1 là chưa tới ngày bắt đầu, > 3 là plan đã hết.
  int dayNumberOn(DateTime now) => dateOnly(now).difference(startDate).inDays + 1;

  // Ngày theo lịch của ngày thứ [dayNumber].
  DateTime dateOfDay(int dayNumber) => startDate.add(Duration(days: dayNumber - 1));

  // UTC để phép trừ ngày không lệch vì giờ mùa hè.
  static DateTime dateOnly(DateTime time) => DateTime.utc(time.year, time.month, time.day);

  static String _two(int value) => value.toString().padLeft(2, '0');
}

// "Thứ Bảy, 26/9" — không dùng package intl cho một chuỗi ngắn.
String vietnameseDate(DateTime date) {
  const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
  return '${weekdays[date.weekday - 1]}, ${date.day}/${date.month}';
}
```

`frontend_app/test/models/plan_schedule_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/plan_schedule.dart';

void main() {
  final schedule = PlanSchedule.startingOn('p1', DateTime(2026, 9, 26, 23, 30));

  test('bỏ giờ phút: tạo plan lúc 23:30 thì ngày mai là ngày 2', () {
    expect(schedule.dayNumberOn(DateTime(2026, 9, 26, 23, 59)), 1);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 27, 0, 1)), 2);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 28, 12)), 3);
  });

  test('chưa tới ngày bắt đầu < 1, quá 3 ngày > 3', () {
    expect(schedule.dayNumberOn(DateTime(2026, 9, 25)), 0);
    expect(schedule.dayNumberOn(DateTime(2026, 9, 29)), 4);
  });

  test('qua tháng, lưu và đọc lại đúng ngày', () {
    final json = PlanSchedule.startingOn('p2', DateTime(2026, 9, 30)).toJson();
    expect(json, {'plan_id': 'p2', 'start_date': '2026-09-30'});
    final restored = PlanSchedule.fromJson(json);
    expect(restored.dateOfDay(3), DateTime.utc(2026, 10, 2));
    expect(vietnameseDate(restored.dateOfDay(1)), 'Thứ Tư, 30/9');
    expect(() => PlanSchedule.fromJson({'plan_id': 'x', 'start_date': 'hôm qua'}), throwsFormatException);
  });
}
```

### Task 4 — `PlanProvider`

`frontend_app/lib/providers/plan_provider.dart` (viết lại):

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../models/api/profile.dart';
import '../models/plan_schedule.dart';
import '../models/profile_rules.dart';
import '../services/api_client.dart';

// Plan hiện tại, hồ sơ đã tạo ra nó và ngày bắt đầu của plan. Lưu trên máy (shared_preferences; web: localStorage)
// để mở lại app vẫn xem được plan khi không có mạng (NFR-2). Hồ sơ gồm cả `restrictions` và
// `pregnantOrBreastfeeding` — dữ liệu sức khoẻ chỉ nằm trên máy người dùng (NFR-7, D4). Đổi món/bài/feedback gửi
// đúng hồ sơ của plan lên server (BRD 6.4) — hồ sơ đang sửa ở tab "Cá nhân" là bản nháp riêng, nên sửa hồ sơ
// không làm các thao tác trên plan cũ bị 409.
class PlanProvider extends ChangeNotifier {
  PlanProvider({required this._api, required this._prefs, DateTime Function()? now}) : _now = now ?? DateTime.now {
    _restore();
  }

  // Đổi hợp đồng theo cách bản cũ không đọc được → tăng số phiên bản của khoá.
  static const planKey = 'smartfit.plan.v1';
  static const profileKey = 'smartfit.profile.v1';
  static const scheduleKey = 'smartfit.plan_schedule.v1';
  static const draftKey = 'smartfit.profile_draft.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;
  final DateTime Function() _now;

  Profile? _profile;
  MealPlan? _plan;
  PlanSchedule? _schedule;
  Profile? _draft;
  bool _busy = false;

  // Hồ sơ đã tạo plan hiện tại.
  Profile? get profile => _profile;
  MealPlan? get plan => _plan;
  PlanSchedule? get schedule => _schedule;
  bool get hasPlan => _plan != null;
  // Đang chờ server — UI khoá các nút tạo/đổi.
  bool get busy => _busy;

  // Hồ sơ đã sửa ở tab "Cá nhân" mà chưa tạo plan mới.
  Profile? get draft => _draft;
  bool get hasPendingProfile => _draft != null;
  // Hồ sơ để điền sẵn form: bản nháp nếu có, không thì hồ sơ của plan.
  Profile? get editableProfile => _draft ?? _profile;

  // Ngày thứ mấy của plan hôm nay (< 1: chưa bắt đầu, > 3: đã hết). null khi chưa có plan.
  int? get todayNumber => _schedule?.dayNumberOn(_now());

  // Mọi hàm gọi server: lỗi → ApiException (plan đang có giữ nguyên); đang bận → bỏ qua, không gọi server.
  // Tạo plan mới: bắt đầu từ hôm nay, bỏ bản nháp (hồ sơ đã được dùng).
  Future<void> generate(Profile profile) => _run(() async {
    final plan = await _api.generatePlan(profile);
    _draft = null;
    await _prefs.remove(draftKey);
    await _save(profile, plan, PlanSchedule.startingOn(plan.planId, _now()));
  });

  Future<void> swapMeal(String mealId) => _run(() async {
    final (profile, plan) = _current();
    await _save(profile, await _api.swapMeal(profile, plan, mealId), _schedule);
  });

  Future<void> swapExercise(String exerciseId) => _run(() async {
    final (profile, plan) = _current();
    await _save(profile, await _api.swapExercise(profile, plan, exerciseId), _schedule);
  });

  // null khi đang bận. `safetyWarning` khác null → UI hiện cảnh báo nổi bật (BRD 6.4, dấu hiệu nguy hiểm).
  // Feedback ngày 3 trả plan mới (`plan_id` khác) — plan đó bắt đầu từ ngày mai.
  Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(() async {
    final (profile, plan) = _current();
    final result = await _api.submitFeedback(profile, plan, answers);
    final schedule = result.plan.planId == plan.planId
        ? _schedule
        : PlanSchedule.startingOn(result.plan.planId, _now().add(const Duration(days: 1)));
    await _save(profile, result.plan, schedule);
    return result;
  });

  // Lưu hồ sơ sửa ở tab "Cá nhân". Giống hồ sơ của plan → không còn gì chờ áp dụng.
  Future<void> saveDraft(Profile edited) async {
    final current = _profile;
    _draft = current != null && edited.sameAs(current) ? null : edited;
    notifyListeners();
    if (_draft == null) {
      await _prefs.remove(draftKey);
    } else {
      await _prefs.setString(draftKey, jsonEncode(edited.toJson()));
    }
  }

  // Bỏ plan đang có (giữ hồ sơ để điền sẵn form).
  Future<void> clearPlan() async {
    _plan = null;
    _schedule = null;
    notifyListeners();
    await _prefs.remove(planKey);
    await _prefs.remove(scheduleKey);
  }

  Future<T?> _run<T>(Future<T> Function() task) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  (Profile, MealPlan) _current() {
    final profile = _profile;
    final plan = _plan;
    if (profile == null || plan == null) throw StateError('Chưa có plan — gọi generate() trước');
    return (profile, plan);
  }

  Future<void> _save(Profile profile, MealPlan plan, PlanSchedule? schedule) async {
    _profile = profile;
    _plan = plan;
    _schedule = schedule ?? PlanSchedule.startingOn(plan.planId, _now());
    await _prefs.setString(profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString(planKey, jsonEncode(plan.toJson()));
    await _prefs.setString(scheduleKey, jsonEncode(_schedule!.toJson()));
  }

  // Bản lưu hỏng hoặc của hợp đồng cũ → xoá, không crash. Plan không có hồ sơ đi kèm thì không đổi món/feedback
  // được, nên hồ sơ hỏng kéo theo xoá plan; plan hỏng thì hồ sơ vẫn giữ.
  // Hồ sơ lưu trước v2.6.0 mà nay bị luật mới chặn (dưới 18 tuổi, thiếu cân + Giảm mỡ…): mọi request sẽ trả 400,
  // nên bỏ plan và giữ hồ sơ để người dùng sửa ở Onboarding.
  void _restore() {
    _profile = _read(profileKey, Profile.fromJson);
    _draft = _read(draftKey, Profile.fromJson);
    final profile = _profile;
    _plan = profile == null || profileProblems(profile).isNotEmpty ? null : _read(planKey, MealPlan.fromJson);
    if (_plan == null && _prefs.containsKey(planKey)) unawaited(_prefs.remove(planKey));

    final plan = _plan;
    final schedule = plan == null ? null : _read(scheduleKey, PlanSchedule.fromJson);
    // Plan lưu trước khi có lịch (giai đoạn 5) hoặc lịch của plan khác → coi như bắt đầu hôm nay.
    _schedule = plan == null
        ? null
        : schedule != null && schedule.planId == plan.planId
        ? schedule
        : PlanSchedule.startingOn(plan.planId, _now());
  }

  T? _read<T>(String key, T Function(Json json) parse) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      return parse(readMap(jsonDecode(text), key));
    } on FormatException {
      unawaited(_prefs.remove(key));
      return null;
    }
  }
}
```

```diff
--- a/frontend_app/test/fake_backend.dart
+++ b/frontend_app/test/fake_backend.dart
@@ -8,11 +8,13 @@
 import 'fixture_loader.dart';
 
 // Backend giả cho test provider/widget: trả fixture hợp đồng theo đường dẫn, ghi lại request đã nhận.
-// `failWith` đặt mã lỗi (và fixture error_<mã>) cho mọi request tiếp theo; `hold` giữ response tới khi complete.
+// `failWith` đặt mã lỗi (và fixture error_<mã>) cho mọi request tiếp theo; `hold` giữ response tới khi complete;
+// `responses` thay JSON trả về cho một đường dẫn (ví dụ plan mới sau feedback ngày 3).
 class FakeBackend {
   final requests = <http.Request>[];
   int? failWith;
   Completer<void>? hold;
+  final responses = <String, Object>{};
 
   static const _fixtureFor = {
     '/health': 'health',
@@ -32,6 +34,8 @@
       final status = failWith;
       if (status != null) return _json(loadFixture('error_$status'), status);
       if (request.method == 'DELETE') return http.Response('', 204);
+      final custom = responses[request.url.path];
+      if (custom != null) return _json(custom, 200);
       final name = _fixtureFor[request.url.path];
       if (name == null) return _json({'statusCode': 404, 'message': 'Cannot ${request.method} ${request.url.path}'}, 404);
       return _json(loadFixture(name), 200);
```

```diff
--- a/frontend_app/test/providers/plan_provider_test.dart
+++ b/frontend_app/test/providers/plan_provider_test.dart
@@ -19,13 +19,18 @@
     PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
   };
 
+  // Đồng hồ giả: test đổi `now` để sang ngày khác.
+  var now = DateTime(2026, 9, 26, 9);
+
   Future<(PlanProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
     SharedPreferences.setMockInitialValues(values);
     final prefs = await SharedPreferences.getInstance();
     final backend = FakeBackend();
-    return (PlanProvider(api: backend.api, prefs: prefs), backend, prefs);
+    return (PlanProvider(api: backend.api, prefs: prefs, now: () => now), backend, prefs);
   }
 
+  setUp(() => now = DateTime(2026, 9, 26, 9));
+
   test('máy chưa có gì → chưa có plan', () async {
     final (provider, _, _) = await create();
     expect(provider.hasPlan, isFalse);
@@ -117,4 +122,83 @@
     expect(provider.profile, isNotNull);
     expect(prefs.getKeys(), {PlanProvider.profileKey});
   });
+
+  group('ngày trong plan (D6-B1)', () {
+    test('tạo plan → bắt đầu hôm nay, lưu lại; mở app hôm sau là ngày 2, quá 3 ngày là > 3', () async {
+      final (provider, _, prefs) = await create();
+      await provider.generate(profile);
+      expect(provider.todayNumber, 1);
+      expect(jsonDecode(prefs.getString(PlanProvider.scheduleKey)!),
+          {'plan_id': provider.plan!.planId, 'start_date': '2026-09-26'});
+
+      now = DateTime(2026, 9, 27, 7);
+      expect(PlanProvider(api: FakeBackend().api, prefs: prefs, now: () => now).todayNumber, 2);
+      now = DateTime(2026, 9, 29, 7);
+      expect(provider.todayNumber, 4);
+    });
+
+    test('đổi món giữ ngày bắt đầu; feedback ngày 3 trả plan mới → plan mới bắt đầu từ ngày mai', () async {
+      final (provider, backend, _) = await create();
+      await provider.generate(profile);
+      now = DateTime(2026, 9, 28, 21);
+      await provider.swapMeal('m3_2');
+      expect(provider.todayNumber, 3);
+
+      final next = loadFixture('generate_plan')..['plan_id'] = '00000000-0000-4000-8000-0000000000ff';
+      backend.responses['/api/v1/feedback'] = {'plan': next, 'safety_warning': null};
+      await provider.submitFeedback(const FeedbackAnswers(
+          dayNumber: 3, intensity: Intensity.moderate, bodyStates: {BodyState.normal}, eating: Eating.onPlan));
+      expect(provider.plan!.planId, next['plan_id']);
+      expect(provider.todayNumber, 0);
+      now = DateTime(2026, 9, 29, 7);
+      expect(provider.todayNumber, 1);
+    });
+
+    test('plan lưu từ giai đoạn 5 (chưa có lịch) → coi như bắt đầu hôm nay', () async {
+      final (provider, _, _) = await create(saved);
+      expect(provider.schedule!.planId, provider.plan!.planId);
+      expect(provider.todayNumber, 1);
+    });
+  });
+
+  group('hồ sơ đang sửa ở tab Cá nhân (bản nháp)', () {
+    test('lưu nháp khác hồ sơ của plan → chờ áp dụng; đổi món vẫn gửi hồ sơ cũ (không bị 409)', () async {
+      final (provider, backend, prefs) = await create(saved);
+      final edited = Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'});
+      await provider.saveDraft(edited);
+
+      expect(provider.hasPendingProfile, isTrue);
+      expect(provider.editableProfile!.goal, Goal.bulk);
+      expect(prefs.containsKey(PlanProvider.draftKey), isTrue);
+
+      await provider.swapMeal('m1_2');
+      final body = jsonDecode(utf8.decode(backend.requests.last.bodyBytes)) as Map<String, dynamic>;
+      expect(body['profile'], loadFixture('profile'));
+    });
+
+    test('lưu nháp giống hồ sơ của plan → không còn gì chờ; tạo plan mới → bỏ nháp', () async {
+      final (provider, _, prefs) = await create(saved);
+      await provider.saveDraft(Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'}));
+      await provider.saveDraft(profile);
+      expect(provider.hasPendingProfile, isFalse);
+      expect(prefs.containsKey(PlanProvider.draftKey), isFalse);
+
+      final edited = Profile.fromJson({...loadFixture('profile'), 'goal': 'maintain'});
+      await provider.saveDraft(edited);
+      await provider.generate(edited);
+      expect(provider.hasPendingProfile, isFalse);
+      expect(provider.profile!.goal, Goal.maintain);
+      expect(prefs.containsKey(PlanProvider.draftKey), isFalse);
+    });
+  });
+
+  test('hồ sơ đã lưu nay bị luật v2.6.0 chặn (17 tuổi) → bỏ plan, giữ hồ sơ để sửa ở Onboarding', () async {
+    final (provider, _, prefs) = await create({
+      ...saved,
+      PlanProvider.profileKey: jsonEncode({...loadFixture('profile'), 'age': 17}),
+    });
+    expect(provider.hasPlan, isFalse);
+    expect(provider.editableProfile!.age, 17);
+    expect(prefs.containsKey(PlanProvider.planKey), isFalse);
+  });
 }
```

### Task 5 — `GroceryProvider`

`frontend_app/lib/providers/grocery_provider.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/codes.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import 'plan_provider.dart';

// Trạng thái danh sách đi chợ (BRD FR-3.2): món đã mua, món đã có sẵn trong tủ lạnh (ẩn khỏi danh sách).
// Danh sách do server tính (#7); app chỉ lưu trạng thái hiển thị, theo từng plan — plan mới thì bắt đầu lại.
class GroceryProvider extends ChangeNotifier {
  GroceryProvider({required this._prefs, required this._plans}) {
    _restore();
    _plans.addListener(_onPlanChanged);
  }

  static const stateKey = 'smartfit.grocery.v1';

  final SharedPreferences _prefs;
  final PlanProvider _plans;

  String? _planId;
  final Set<String> _bought = {};
  final Set<String> _have = {};

  // Khoá gồm cả lượng: đổi món làm lượng thay đổi thì dòng đó bỏ tích — cần mua thêm.
  static String keyOf(IngredientCategory category, GroceryEntry entry) =>
      '${category.code}|${entry.name}|${entry.quantity}';

  bool isBought(String key) => _bought.contains(key);
  bool isHave(String key) => _have.contains(key);

  Future<void> toggleBought(String key) =>
      _update(() => _bought.contains(key) ? _bought.remove(key) : _bought.add(key));

  Future<void> markHave(String key) => _update(() {
    _have.add(key);
    _bought.remove(key);
  });

  Future<void> restoreHave(String key) => _update(() => _have.remove(key));

  @override
  void dispose() {
    _plans.removeListener(_onPlanChanged);
    super.dispose();
  }

  Future<void> _update(void Function() change) async {
    change();
    notifyListeners();
    await _prefs.setString(
      stateKey,
      jsonEncode({'plan_id': _planId, 'bought': _bought.toList(), 'have': _have.toList()}),
    );
  }

  void _onPlanChanged() {
    final planId = _plans.plan?.planId;
    if (planId == _planId) return;
    _planId = planId;
    _bought.clear();
    _have.clear();
    notifyListeners();
    unawaited(_prefs.remove(stateKey));
  }

  void _restore() {
    _planId = _plans.plan?.planId;
    final text = _prefs.getString(stateKey);
    if (text == null) return;
    try {
      final json = readMap(jsonDecode(text), stateKey);
      if (json['plan_id'] != _planId) {
        unawaited(_prefs.remove(stateKey));
        return;
      }
      _bought.addAll(readList(json, 'bought', (item) => item is String ? item : throw const FormatException('bought')));
      _have.addAll(readList(json, 'have', (item) => item is String ? item : throw const FormatException('have')));
    } on FormatException {
      _bought.clear();
      _have.clear();
      unawaited(_prefs.remove(stateKey));
    }
  }
}
```

`frontend_app/test/providers/grocery_provider_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final saved = {
    PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
  };
  final plan = MealPlan.fromJson(loadFixture('generate_plan'));
  final firstGroup = plan.groceryList.first;
  final key = GroceryProvider.keyOf(firstGroup.category, firstGroup.items.first);

  Future<(GroceryProvider, PlanProvider, FakeBackend, SharedPreferences)> create(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final plans = PlanProvider(api: backend.api, prefs: prefs);
    return (GroceryProvider(prefs: prefs, plans: plans), plans, backend, prefs);
  }

  test('đánh dấu đã mua, đã có sẵn; mở lại app vẫn còn', () async {
    final (grocery, plans, _, prefs) = await create(saved);
    await grocery.toggleBought(key);
    expect(grocery.isBought(key), isTrue);
    await grocery.markHave(key);
    expect(grocery.isHave(key), isTrue);
    expect(grocery.isBought(key), isFalse, reason: 'đã có sẵn thì không tính là đã mua');

    final reopened = GroceryProvider(prefs: prefs, plans: plans);
    expect(reopened.isHave(key), isTrue);
    await reopened.restoreHave(key);
    expect(reopened.isHave(key), isFalse);
  });

  test('khoá gồm cả lượng: đổi món làm lượng thay đổi thì dòng đó hết tích', () {
    final entry = firstGroup.items.first;
    final more = GroceryEntry(name: entry.name, quantity: '9999g', sourceMealIds: entry.sourceMealIds);
    expect(GroceryProvider.keyOf(firstGroup.category, more), isNot(key));
  });

  test('plan mới (plan_id khác) → bắt đầu lại từ đầu', () async {
    final (grocery, plans, backend, prefs) = await create(saved);
    await grocery.toggleBought(key);
    backend.responses['/api/v1/generate-plan'] = loadFixture('generate_plan')..['plan_id'] = 'khac';
    await plans.generate(Profile.fromJson(loadFixture('profile')));
    expect(grocery.isBought(key), isFalse);
    expect(prefs.containsKey(GroceryProvider.stateKey), isFalse);
  });

  test('trạng thái lưu của plan khác hoặc bị hỏng → bỏ qua', () async {
    final (other, _, _, _) = await create({
      ...saved,
      GroceryProvider.stateKey: jsonEncode({
        'plan_id': 'khac',
        'bought': [key],
        'have': [],
      }),
    });
    expect(other.isBought(key), isFalse);
    final (broken, _, _, _) = await create({...saved, GroceryProvider.stateKey: '{"plan_id": 1'});
    expect(broken.isBought(key), isFalse);
  });
}
```

### Task 6 — Cổng kiểm tra F03

```bash
cd frontend_app
flutter analyze   # No issues found!
flutter test      # +67: All tests passed!
```
