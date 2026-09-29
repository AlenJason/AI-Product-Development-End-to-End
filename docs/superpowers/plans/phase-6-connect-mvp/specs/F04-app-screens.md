# F04 — App: màn hình nối dữ liệu thật, khung app, đổi món / đổi bài (PLAN 6.1–6.7, 7.1, 7.2)

## Feature

Mọi màn hình đọc/ghi qua provider; xoá view-model cũ (`lib/models/meal_plan.dart`) và bảng feedback cũ (`lib/widgets/feedback_bottom_sheet.dart` — giai đoạn 7 làm lại theo D2).

| Màn | Nội dung |
|---|---|
| Onboarding (6.1, D6-B2) | 3 bước: cơ thể (giới tính; nữ thêm "Đang mang thai hoặc cho con bú"; tuổi, chiều cao, cân nặng) → mức vận động (FR-1.2) + mục tiêu → hạn chế (D5 + khuyến cáo y tế). Thanh tiến trình; nút ở đáy; nút tiếp tục khoá tới khi bước hợp lệ; lỗi hiện dưới ô (ô trống chưa báo); "Giảm mỡ" bị khoá kèm lý do (#30); nút Back hệ thống quay lại bước trước. `onSubmit(Profile)` |
| Màn chờ (6.3) | Vòng xoay + câu chờ thật; sau 15 s đổi câu "có thể mất tới 40 giây"; lỗi → `ApiException.message` + "Thử lại" / "Sửa hồ sơ" / "Về kế hoạch đang có" (nếu có plan); không cho Back |
| Kế hoạch (6.4, 6.11) | Ngày theo lịch + "Hôm nay là Ngày N"; 3 tab ngày mở sẵn hôm nay; tổng ngày so với mục tiêu bằng `MacroRing` (phần trăm thật, có thể > 100%); 3 bữa (calo, đạm, tinh bột, béo, nguyên liệu với đơn vị BRD 6.2); buổi tập; `warnings` (thu gọn được); nhãn "Thực đơn mẫu"; dải nhắc: hồ sơ đã sửa / kế hoạch đã hết / chưa bắt đầu |
| Đổi món, đổi bài (7.1, 7.2 — Q3) | Gọi `PlanProvider.swapMeal/swapExercise`; khoá mọi nút khi `busy`, vòng xoay đúng nút đang chờ; xong → "Đã đổi … sang: <tên mới>"; 409 → câu của server + nút "Tạo mới"; lỗi khác → câu của server |
| Đi chợ (6.5) | Từ `grocery_list`, tên nhóm BRD FR-3.1; đã mua; "đã có sẵn" (FR-3.2) + "Hiện lại" / "Cần mua"; tìm kiếm, lọc nhóm; bỏ "Thêm nguyên liệu" (Q4) |
| Cá nhân (6.2) | Tóm tắt hồ sơ (BMI, calo mục tiêu — ẩn khi có nháp vì không còn đúng); "Sửa hồ sơ" mở cùng form (controller chỉ tạo khi bắt đầu sửa); lưu → bản nháp; dải "Tạo kế hoạch mới" dùng bản nháp |
| Lịch sử | Chỗ giữ không còn số liệu viết cứng (giai đoạn 8) |
| `MainShell` | Onboarding → màn chờ (`_generate(profile)`) → màn chính 4 tab; có plan → vào thẳng màn chính; hồ sơ lưu từ trước bị chặn → Onboarding điền sẵn; app quay lại foreground → tính lại ngày |

Số thập phân hiển thị kiểu Việt ("24,8"). Thẻ có màu nền bọc `ListTile`/`SwitchListTile`/`ExpansionTile` dùng `Material` + `shape`, không dùng `Container` (Flutter báo lỗi ở bản debug — test bắt được). `main()` bật `SystemUiMode.edgeToEdge` + `AnnotatedRegion` thanh hệ thống trong suốt (phần theme Android ở F05).

## Scope

UI-only:

- `frontend_app/lib/theme/app_colors.dart`, `lib/widgets/profile_form.dart`, `lib/screens/profile_screen.dart` (mới)
- `frontend_app/lib/screens/onboarding_screen.dart`, `loading_screen.dart`, `dashboard_screen.dart`, `grocery_screen.dart`, `lib/main.dart` (viết lại)
- xoá `frontend_app/lib/models/meal_plan.dart`, `lib/widgets/feedback_bottom_sheet.dart`
- `frontend_app/test/app_harness.dart`, `test/screens/*_test.dart` (mới); `test/widget_test.dart` (viết lại); `integration_test/backend_smoke_test.dart` (sửa)

## Implementation

### API Routes

Không thêm; gọi `generate-plan`, `meals/swap`, `exercises/swap` qua provider. Độ trễ do backend quyết định (giả lập vài ms; Gemini 8–13 s, tối đa ~40 s; app hết giờ ở 60 s).

### UI Components

Bảng ở mục Feature. Form hồ sơ: `ProfileFormController` (ChangeNotifier) + `BodySection`, `GoalSection`, `RestrictionsSection` — dùng chung cho Onboarding (từng bước) và tab Cá nhân (một trang).

### DB / KV Changes

Không thêm khoá (dùng khoá của F03).

### Ràng buộc áp dụng

- **#7** danh sách đi chợ lấy từ server, app chỉ lưu trạng thái hiển thị.
- **#24** đổi món gửi hồ sơ của plan; 409 → gợi ý tạo mới.
- **#28** không log; lỗi hiện `ApiException.message`.
- **#30, #32** khoá lựa chọn theo ngưỡng backend; chip nằm trong nhãn backend.
- NFR-1, NFR-2, NFR-9: màn chờ thật, lỗi không crash, khuyến cáo y tế.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`; `flutter test` → `+89: All tests passed!`
- [ ] `flutter test integration_test -d emulator-5554` (backend giả lập đang chạy) → `+3: All tests passed!`
- [ ] Không còn `meal_plan.dart`, `feedback_bottom_sheet.dart`; không còn chữ "15/9/2026", "1.850", "168 cm • 62 kg" viết cứng

## Test Checklist

1. **@onboarding**: tiếp tục khoá tới khi hợp lệ; 17 tuổi báo lỗi; ô mang thai chỉ với nữ; thiếu cân → thẻ Giảm mỡ có biểu tượng khoá, bấm không chọn được; mang thai → khoá Giảm mỡ, gửi kèm cờ; bước 3 ghép đúng chuỗi; Back quay lại bước, giữ dữ liệu; điền sẵn hồ sơ cũ
2. **@dashboard**: mở đúng ngày hôm nay, bữa sáng, tổng calo, lưu ý (2), nhãn thực đơn mẫu; đổi ngày; 2 ngày sau → Ngày 3; 4 ngày sau → dải "đã hết" + tạo mới; đổi món gọi API và hiện món mới; 409 → câu server + "Tạo mới", plan giữ nguyên; hồ sơ nháp → dải nhắc
3. **@grocery**: nhóm BRD, không có "Thêm nguyên liệu"; tích tăng bộ đếm, mở lại còn; đã có sẵn → ẩn, "Cần mua" trả lại; tìm kiếm, lọc
4. **@profile**: sửa mục tiêu → nháp (hồ sơ của plan giữ nguyên), ẩn calo cũ, tạo mới dùng nháp
5. **@app**: chưa có plan → Onboarding, không gọi mạng; có plan → Dashboard, không gọi mạng; plan hỏng → Onboarding; hồ sơ 17 tuổi → Onboarding báo lỗi; Onboarding → màn chờ → Dashboard, body đúng hạn chế và cờ; lỗi → "Chưa tạo được kế hoạch" → Thử lại → Dashboard; 4 tab
6. **@device** (integration_test, tay): điền Onboarding → backend thật → Dashboard → đổi món
7. **@auth**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Bảng màu và form hồ sơ dùng chung

`frontend_app/lib/theme/app_colors.dart`:

```dart
import 'package:flutter/material.dart';

// Bảng màu dùng chung (lấy từ thiết kế Figma của các màn hình có sẵn).
class AppColors {
  static const primary = Color(0xFF059669);
  static const primaryBright = Color(0xFF10B981);
  static const primaryDark = Color(0xFF047857);
  static const primarySoft = Color(0xFFECFDF5);
  static const ink = Color(0xFF0F172A);
  static const heading = Color(0xFF1E293B);
  static const muted = Color(0xFF64748B);
  static const faint = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const page = Color(0xFFFDFBF7);
  static const panel = Color(0xFFF8FAFC);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFFFBEB);
  static const warningBorder = Color(0xFFFDE68A);
  static const danger = Color(0xFFB91C1C);
  static const accent = Color(0xFFEA580C);
  static const accentSoft = Color(0xFFFFF7ED);
}
```

`frontend_app/lib/widgets/profile_form.dart`:

```dart
import 'package:flutter/material.dart';

import '../models/api/codes.dart';
import '../models/api/profile.dart';
import '../models/profile_rules.dart';
import '../models/restriction_options.dart';
import '../theme/app_colors.dart';

// Form hồ sơ dùng chung cho Onboarding (chia 3 bước) và tab "Cá nhân" (một trang). Giới hạn và luật an toàn giống
// backend (`profile_rules.dart`); báo lỗi ngay khi nhập.
class ProfileFormController extends ChangeNotifier {
  ProfileFormController([Profile? initial])
    : age = TextEditingController(text: initial == null ? '' : '${initial.age}'),
      height = TextEditingController(text: initial == null ? '' : _number(initial.heightCm)),
      weight = TextEditingController(text: initial == null ? '' : _number(initial.weightKg)),
      gender = initial?.gender,
      pregnantOrBreastfeeding = initial?.pregnantOrBreastfeeding ?? false,
      activityLevel = initial?.activityLevel,
      goal = initial?.goal,
      restrictions = {
        RestrictionKind.allergies: RestrictionSelection.parse(
          initial?.restrictions.allergies ?? '',
          RestrictionKind.allergies,
        ),
        RestrictionKind.injuries: RestrictionSelection.parse(
          initial?.restrictions.injuries ?? '',
          RestrictionKind.injuries,
        ),
        RestrictionKind.healthConditions: RestrictionSelection.parse(
          initial?.restrictions.healthConditions ?? '',
          RestrictionKind.healthConditions,
        ),
      } {
    for (final field in [age, height, weight]) {
      field.addListener(notifyListeners);
    }
  }

  final TextEditingController age;
  final TextEditingController height;
  final TextEditingController weight;
  Gender? gender;
  bool pregnantOrBreastfeeding;
  ActivityLevel? activityLevel;
  Goal? goal;
  final Map<RestrictionKind, RestrictionSelection> restrictions;

  String? get ageProblem => ageError(age.text);
  String? get heightProblem => heightError(height.text);
  String? get weightProblem => weightError(weight.text);

  bool get bodyValid => ageProblem == null && heightProblem == null && weightProblem == null && gender != null;

  // Lý do khoá "Giảm mỡ"; null khi chưa nhập đủ chiều cao/cân nặng.
  String? get cutBlock {
    final heightCm = parseNumber(height.text);
    final weightKg = parseNumber(weight.text);
    if (heightProblem != null || weightProblem != null || heightCm == null || weightKg == null) return null;
    return cutBlockReason(
      heightCm: heightCm,
      weightKg: weightKg,
      pregnantOrBreastfeeding: gender == Gender.female && pregnantOrBreastfeeding,
    );
  }

  bool get goalValid => activityLevel != null && goal != null && !(goal == Goal.cut && cutBlock != null);

  bool get restrictionsValid => RestrictionKind.values.every((kind) => restrictions[kind]!.lengthError(kind) == null);

  bool get valid => bodyValid && goalValid && restrictionsValid;

  // Chỉ gọi khi `valid`.
  Profile toProfile() => Profile(
    age: int.parse(age.text.trim()),
    gender: gender!,
    heightCm: parseNumber(height.text)!,
    weightKg: parseNumber(weight.text)!,
    activityLevel: activityLevel!,
    goal: goal!,
    pregnantOrBreastfeeding: gender == Gender.female && pregnantOrBreastfeeding,
    restrictions: Restrictions(
      allergies: restrictions[RestrictionKind.allergies]!.compose(RestrictionKind.allergies),
      injuries: restrictions[RestrictionKind.injuries]!.compose(RestrictionKind.injuries),
      healthConditions: restrictions[RestrictionKind.healthConditions]!.compose(RestrictionKind.healthConditions),
    ),
  );

  void update(void Function(ProfileFormController form) change) {
    change(this);
    notifyListeners();
  }

  @override
  void dispose() {
    age.dispose();
    height.dispose();
    weight.dispose();
    super.dispose();
  }

  static String _number(num value) => value == value.roundToDouble() ? '${value.round()}' : '$value';
}

const _goalLabels = {
  Goal.cut: ('Giảm mỡ & giữ cơ', 'Thâm hụt 300 kcal/ngày, thực đơn nhiều đạm và chất xơ.'),
  Goal.maintain: ('Duy trì vóc dáng', 'Cân bằng calo, ưu tiên món ăn gia đình quen thuộc.'),
  Goal.bulk: ('Tăng cơ nạc', 'Dư 250 kcal/ngày kết hợp bài tập tại nhà.'),
};

// Mô tả theo BRD FR-1.2.
const _activityLabels = {
  ActivityLevel.sedentary: ('Ít vận động', 'Ngồi nhiều, ví dụ dân văn phòng.'),
  ActivityLevel.light: ('Vận động nhẹ', 'Tập 1–3 buổi mỗi tuần.'),
  ActivityLevel.active: ('Vận động nhiều', 'Tập 4–5 buổi mỗi tuần.'),
};

String goalLabel(Goal goal) => _goalLabels[goal]!.$1;
String activityLabel(ActivityLevel level) => _activityLabels[level]!.$1;

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.heading),
    ),
  );
}

// Bước 1: tuổi, giới tính, mang thai / cho con bú, chiều cao, cân nặng.
class BodySection extends StatelessWidget {
  const BodySection({super.key, required this.form});

  final ProfileFormController form;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: form,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Giới tính'),
        SegmentedButton<Gender>(
          segments: const [
            ButtonSegment(value: Gender.female, label: Text('Nữ'), icon: Icon(Icons.female)),
            ButtonSegment(value: Gender.male, label: Text('Nam'), icon: Icon(Icons.male)),
          ],
          emptySelectionAllowed: true,
          selected: {?form.gender},
          onSelectionChanged: (value) => form.update((f) => f.gender = value.isEmpty ? null : value.first),
        ),
        if (form.gender == Gender.female)
          CheckboxListTile(
            value: form.pregnantOrBreastfeeding,
            onChanged: (value) => form.update((f) => f.pregnantOrBreastfeeding = value ?? false),
            title: const Text('Đang mang thai hoặc cho con bú', style: TextStyle(fontSize: 13)),
            subtitle: const Text(
              'Kế hoạch sẽ không thâm hụt calo và chỉ gồm bài tập nhẹ.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primaryBright,
          ),
        const SectionTitle('Chỉ số cơ thể'),
        _NumberField(label: 'Tuổi', controller: form.age, error: form.ageProblem, integer: true),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _NumberField(label: 'Chiều cao (cm)', controller: form.height, error: form.heightProblem),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(label: 'Cân nặng (kg)', controller: form.weight, error: form.weightProblem),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller, required this.error, this.integer = false});

  final String label;
  final TextEditingController controller;
  final String? error;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    // Ô còn trống thì chưa báo lỗi — chỉ nút tiếp tục bị khoá.
    final shownError = controller.text.isEmpty ? null : error;
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        errorText: shownError,
        errorMaxLines: 2,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

// Bước 2: mức vận động (FR-1.2) và mục tiêu (FR-1.3). "Giảm mỡ" bị khoá kèm lý do (D6-A1, A3).
class GoalSection extends StatelessWidget {
  const GoalSection({super.key, required this.form});

  final ProfileFormController form;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: form,
    builder: (context, _) {
      final block = form.cutBlock;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Mức vận động hằng ngày'),
          for (final level in ActivityLevel.values)
            _ChoiceCard(
              title: _activityLabels[level]!.$1,
              description: _activityLabels[level]!.$2,
              selected: form.activityLevel == level,
              onTap: () => form.update((f) => f.activityLevel = level),
            ),
          const SectionTitle('Mục tiêu chính'),
          for (final goal in [Goal.cut, Goal.maintain, Goal.bulk])
            _ChoiceCard(
              title: _goalLabels[goal]!.$1,
              description: goal == Goal.cut && block != null ? block : _goalLabels[goal]!.$2,
              selected: form.goal == goal,
              disabled: goal == Goal.cut && block != null,
              onTap: () => form.update((f) => f.goal = goal),
            ),
        ],
      );
    },
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final String title;
  final String description;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected && !disabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: active,
        enabled: !disabled,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: disabled ? AppColors.panel : (active ? AppColors.primarySoft : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? AppColors.primaryBright : AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  disabled ? Icons.block : (active ? Icons.check_circle : Icons.radio_button_unchecked),
                  size: 18,
                  color: disabled ? AppColors.faint : (active ? AppColors.primary : Colors.grey.shade400),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: disabled ? AppColors.faint : (active ? AppColors.primaryDark : AppColors.ink),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(fontSize: 11, color: disabled ? AppColors.warning : AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Bước 3: dị ứng, chấn thương, bệnh nền theo D5 + khuyến cáo y tế (NFR-9).
class RestrictionsSection extends StatelessWidget {
  const RestrictionsSection({super.key, required this.form});

  final ProfileFormController form;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: form,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final kind in RestrictionKind.values) _RestrictionGroup(form: form, kind: kind),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warningBorder),
          ),
          child: const Text(
            'Gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế. Người có bệnh nền nên hỏi ý kiến bác sĩ. '
            'Bệnh nền chỉ được xét khi máy chủ dùng Gemini; nếu không, kế hoạch sẽ kèm cảnh báo.',
            style: TextStyle(fontSize: 12, color: AppColors.warning),
          ),
        ),
      ],
    ),
  );
}

class _RestrictionGroup extends StatefulWidget {
  const _RestrictionGroup({required this.form, required this.kind});

  final ProfileFormController form;
  final RestrictionKind kind;

  @override
  State<_RestrictionGroup> createState() => _RestrictionGroupState();
}

class _RestrictionGroupState extends State<_RestrictionGroup> {
  late final TextEditingController _other = TextEditingController(text: _selection.other);
  late bool _otherOpen = _selection.other.isNotEmpty;

  RestrictionSelection get _selection => widget.form.restrictions[widget.kind]!;

  void _set(RestrictionSelection selection) => widget.form.update((f) => f.restrictions[widget.kind] = selection);

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    final error = selection.lengthError(widget.kind);
    // Material (không phải Container có màu nền) để SwitchListTile vẽ được hiệu ứng bấm.
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selection.enabled ? AppColors.primaryBright : AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                value: selection.enabled,
                onChanged: (value) => _set(selection.copyWith(enabled: value)),
                title: Text(widget.kind.toggleLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.primaryBright,
              ),
              if (selection.enabled) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in widget.kind.options)
                      Tooltip(
                        message: option.hint ?? option.label,
                        child: FilterChip(
                          label: Text(option.label),
                          selected: selection.chosen.contains(option.label),
                          onSelected: (on) => _set(
                            selection.copyWith(
                              chosen: on
                                  ? {...selection.chosen, option.label}
                                  : ({...selection.chosen}..remove(option.label)),
                            ),
                          ),
                          selectedColor: AppColors.primarySoft,
                          checkmarkColor: AppColors.primary,
                        ),
                      ),
                    FilterChip(
                      label: const Text('Khác'),
                      selected: _otherOpen,
                      onSelected: (on) {
                        setState(() => _otherOpen = on);
                        if (!on) {
                          _other.clear();
                          _set(selection.copyWith(other: ''));
                        }
                      },
                      selectedColor: AppColors.primarySoft,
                      checkmarkColor: AppColors.primary,
                    ),
                  ],
                ),
                if (_otherOpen)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: TextField(
                      controller: _other,
                      onChanged: (text) => _set(_selection.copyWith(other: text)),
                      decoration: InputDecoration(
                        labelText: widget.kind.title,
                        hintText: widget.kind.otherHint,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(error, style: const TextStyle(fontSize: 11, color: AppColors.danger)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

### Task 2 — Onboarding 3 bước và màn chờ

`frontend_app/lib/screens/onboarding_screen.dart` (viết lại):

```dart
import 'package:flutter/material.dart';

import '../models/api/profile.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_form.dart';

// Onboarding 3 bước (D6-B2): cơ thể → mục tiêu & vận động → hạn chế. Nút luôn ở đáy (màn hình nhỏ không đẩy nút
// xuống dưới mép), nút Back của hệ thống quay lại bước trước. [initial] điền sẵn khi quay lại sửa hồ sơ.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initial, required this.onSubmit});

  final Profile? initial;
  final ValueChanged<Profile> onSubmit;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _titles = ['Thông tin cơ thể', 'Mục tiêu & vận động', 'Hạn chế & sức khoẻ'];

  late final ProfileFormController _form = ProfileFormController(widget.initial);
  int _step = 0;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
    0 => _form.bodyValid,
    1 => _form.goalValid,
    _ => _form.restrictionsValid,
  };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < 2) {
      setState(() => _step++);
    } else {
      widget.onSubmit(_form.toProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SmartFit AI',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Thiết lập mục tiêu 3 ngày',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Bước ${_step + 1}/3 · ${_titles[_step]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_step + 1) / 3,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: AppColors.primaryBright,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: switch (_step) {
                    0 => BodySection(form: _form),
                    1 => GoalSection(form: _form),
                    _ => RestrictionsSection(form: _form),
                  },
                ),
              ),
              ListenableBuilder(
                listenable: _form,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (_step > 0) ...[
                        OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Quay lại'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _stepValid ? _next : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBright,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text(
                            _step < 2 ? 'Tiếp tục' : 'Tạo kế hoạch 3 ngày',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`frontend_app/lib/screens/loading_screen.dart` (viết lại):

```dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../theme/app_colors.dart';

// Chờ backend tạo plan (NFR-1): chế độ giả lập trả ngay, có Gemini thường 8–15 s, tối đa khoảng 40 s. Câu chờ
// không bịa số liệu. [error] khác null → báo lỗi và cho thử lại (NFR-2).
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key, this.error, required this.onRetry, required this.onEditProfile, this.onBack});

  final ApiException? error;
  final VoidCallback onRetry;
  final VoidCallback onEditProfile;
  // Có plan cũ thì cho quay về plan đó thay vì kẹt ở màn lỗi.
  final VoidCallback? onBack;

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const slowAfter = Duration(seconds: 15);

  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(slowAfter, () => setState(() => _slow = true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.page,
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: error == null ? _waiting() : _failed(error)),
          ),
        ),
      ),
    );
  }

  Widget _waiting() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(color: AppColors.primaryBright)),
      const SizedBox(height: 24),
      const Text(
        'Đang lập kế hoạch 3 ngày cho bạn',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      const SizedBox(height: 8),
      Text(
        _slow
            ? 'AI đang chọn món và bài tập, có thể mất tới 40 giây. Vui lòng không tắt ứng dụng.'
            : 'Tính mục tiêu calo, chọn món Việt và bài tập tại nhà phù hợp với bạn…',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ],
  );

  Widget _failed(ApiException error) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.warning),
      const SizedBox(height: 16),
      const Text(
        'Chưa tạo được kế hoạch',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      const SizedBox(height: 8),
      Text(
        error.message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: widget.onRetry,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBright,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: widget.onEditProfile, child: const Text('Sửa hồ sơ')),
      if (widget.onBack != null) TextButton(onPressed: widget.onBack, child: const Text('Về kế hoạch đang có')),
    ],
  );
}
```

### Task 3 — Kế hoạch (Dashboard) với đổi món / đổi bài

`frontend_app/lib/screens/dashboard_screen.dart` (viết lại):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/meal_plan.dart';
import '../models/plan_schedule.dart';
import '../providers/plan_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/macro_ring.dart';

// Kế hoạch 3 ngày (BRD FR-2): mở đúng ngày hôm nay (D6-B1), đủ 3 bữa, tổng calo + macro mỗi ngày (FR-2.3),
// buổi tập, `warnings` (NFR-9). Đổi món / đổi bài gọi API (FR-4.1, FR-4.2 — chuyển lên giai đoạn 6).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onCreatePlan});

  // Tạo plan mới từ hồ sơ hiện tại (bản nháp nếu có) — plan hết hạn, hồ sơ đã đổi, hoặc server báo 409.
  final VoidCallback onCreatePlan;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

const mealTypeLabels = {MealType.breakfast: 'Bữa sáng', MealType.lunch: 'Bữa trưa', MealType.dinner: 'Bữa tối'};

const muscleGroupLabels = {
  MuscleGroup.legs: 'Chân',
  MuscleGroup.chest: 'Ngực',
  MuscleGroup.back: 'Lưng',
  MuscleGroup.core: 'Cơ lõi',
  MuscleGroup.shoulders: 'Vai',
  MuscleGroup.arms: 'Tay',
  MuscleGroup.fullBody: 'Toàn thân',
  MuscleGroup.cardio: 'Tim mạch',
};

// Đơn vị theo BRD 6.2: piece hiển thị ×n, tbsp muỗng canh, tsp muỗng cà phê.
String ingredientAmount(Ingredient ingredient) {
  final amount = formatNumber(ingredient.amount);
  return switch (ingredient.unit) {
    IngredientUnit.g => '${amount}g',
    IngredientUnit.ml => '${amount}ml',
    IngredientUnit.piece => '×$amount',
    IngredientUnit.tbsp => '$amount muỗng canh',
    IngredientUnit.tsp => '$amount muỗng cà phê',
  };
}

// Số thập phân kiểu Việt: 24,8 — giống câu thông báo "BMI dưới 18,5".
String formatNumber(num value) =>
    value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1).replaceAll('.', ',');

class _DashboardScreenState extends State<DashboardScreen> {
  int? _selectedDay;
  // Món / động tác đang chờ server đổi — hiện vòng xoay đúng nút đó.
  String? _pendingId;

  Future<void> _swap(String id, Future<void> Function() action, String Function() done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pendingId = id);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done()), behavior: SnackBarBehavior.floating));
    } on PlanOutdatedException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'Tạo mới', onPressed: widget.onCreatePlan),
        ),
      );
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _pendingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final plan = plans.plan;
    final schedule = plans.schedule;
    if (plan == null || schedule == null) return const SizedBox.shrink();

    final today = plans.todayNumber ?? 1;
    final dayNumber = _selectedDay ?? today.clamp(1, 3);
    final day = plan.days[dayNumber - 1];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _header(plan, schedule, dayNumber, today),
          if (plans.hasPendingProfile)
            _Banner(
              icon: Icons.person_outline,
              text: 'Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.',
              action: 'Tạo kế hoạch mới',
              onAction: plans.busy ? null : widget.onCreatePlan,
            )
          else if (today > 3)
            _Banner(
              icon: Icons.event_available,
              text: 'Kế hoạch 3 ngày đã hết. Tạo kế hoạch mới cho 3 ngày tới.',
              action: 'Tạo kế hoạch mới',
              onAction: plans.busy ? null : widget.onCreatePlan,
            )
          else if (today < 1)
            _Banner(icon: Icons.schedule, text: 'Kế hoạch bắt đầu từ ${vietnameseDate(schedule.startDate)}.'),
          if (plan.warnings.isNotEmpty) _Warnings(warnings: plan.warnings),
          const SizedBox(height: 12),
          _daySelector(schedule, dayNumber, today),
          const SizedBox(height: 12),
          _NutritionSummary(day: day, target: plan.dailyTarget),
          for (final meal in day.meals) _mealCard(plans, meal),
          _workoutCard(plans, day.workout),
        ],
      ),
    );
  }

  Widget _header(MealPlan plan, PlanSchedule schedule, int dayNumber, int today) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vietnameseDate(schedule.dateOfDay(dayNumber)),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              dayNumber == today ? 'Hôm nay là Ngày $dayNumber' : 'Ngày $dayNumber của kế hoạch',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ],
        ),
      ),
      if (plan.source == PlanSource.sample)
        const Tooltip(
          message: 'Máy chủ chưa dùng Gemini: thực đơn mẫu, lọc theo hạn chế phổ biến',
          child: Chip(
            label: Text('Thực đơn mẫu', style: TextStyle(fontSize: 11)),
            visualDensity: VisualDensity.compact,
          ),
        ),
    ],
  );

  Widget _daySelector(PlanSchedule schedule, int dayNumber, int today) => SegmentedButton<int>(
    showSelectedIcon: false,
    segments: [
      for (var number = 1; number <= 3; number++)
        ButtonSegment(
          value: number,
          label: Text(
            number == today ? 'Ngày $number · hôm nay' : 'Ngày $number',
            style: const TextStyle(fontSize: 12),
          ),
        ),
    ],
    selected: {dayNumber},
    onSelectionChanged: (value) => setState(() => _selectedDay = value.first),
  );

  Widget _mealCard(PlanProvider plans, Meal meal) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                mealTypeLabels[meal.mealType]!.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _SwapButton(
              label: 'Đổi món',
              pending: _pendingId == meal.mealId,
              onPressed: plans.busy
                  ? null
                  : () => _swap(meal.mealId, () => plans.swapMeal(meal.mealId), () {
                      final swapped = _findMeal(plans.plan, meal.mealId);
                      return 'Đã đổi ${mealTypeLabels[meal.mealType]!.toLowerCase()} sang: ${swapped?.name ?? ''}';
                    }),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          meal.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 2),
        Text(meal.portion, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill('${formatNumber(meal.calories)} kcal', AppColors.accent, AppColors.accentSoft),
            _Pill('Đạm ${formatNumber(meal.proteinG)}g', AppColors.primary, AppColors.primarySoft),
            _Pill('Tinh bột ${formatNumber(meal.carbsG)}g', AppColors.muted, AppColors.panel),
            _Pill('Béo ${formatNumber(meal.fatG)}g', AppColors.muted, AppColors.panel),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final ingredient in meal.ingredients)
              _Pill(
                '${ingredient.name} ${ingredientAmount(ingredient)}',
                AppColors.heading,
                Colors.white,
                bordered: true,
              ),
          ],
        ),
      ],
    ),
  );

  Widget _workoutCard(PlanProvider plans, Workout workout) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BÀI TẬP TẠI NHÀ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Text(
          workout.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            _Pill('${workout.durationMinutes} phút', AppColors.primary, AppColors.primarySoft),
            const _Pill('Không dụng cụ', AppColors.muted, AppColors.panel),
          ],
        ),
        const Divider(height: 20),
        for (final exercise in workout.exercises)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      Text(
                        '${exercise.sets} hiệp × ${exercise.repsOrDuration} · ${muscleGroupLabels[exercise.muscleGroup]}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                _SwapButton(
                  label: 'Đổi bài',
                  pending: _pendingId == exercise.exerciseId,
                  onPressed: plans.busy
                      ? null
                      : () => _swap(exercise.exerciseId, () => plans.swapExercise(exercise.exerciseId), () {
                          final swapped = _findExercise(plans.plan, exercise.exerciseId);
                          return 'Đã đổi bài sang: ${swapped?.name ?? ''}';
                        }),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  static Meal? _findMeal(MealPlan? plan, String id) =>
      plan?.days.expand((day) => day.meals).where((meal) => meal.mealId == id).firstOrNull;

  static Exercise? _findExercise(MealPlan? plan, String id) =>
      plan?.days.expand((day) => day.workout.exercises).where((exercise) => exercise.exerciseId == id).firstOrNull;
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.day, required this.target});

  final PlanDay day;
  final DailyTarget target;

  @override
  Widget build(BuildContext context) {
    num total(num Function(Meal meal) pick) => day.meals.fold<num>(0, (sum, meal) => sum + pick(meal));
    final calories = total((meal) => meal.calories);
    // Tỉ lệ thật (có thể > 100%): MacroRing tự giới hạn cung vẽ, chữ phần trăm cho thấy phần vượt.
    double progress(num value, num goal) => goal <= 0 ? 0 : (value / goal).toDouble();
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TỔNG TRONG NGÀY',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatNumber(calories),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                TextSpan(
                  text: ' / ${formatNumber(target.targetCalories)} kcal mục tiêu',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroRing(
                label: 'Đạm',
                value: '${formatNumber(total((meal) => meal.proteinG))}/${formatNumber(target.proteinG)}g',
                progress: progress(total((meal) => meal.proteinG), target.proteinG),
                ringColor: AppColors.primaryBright,
              ),
              MacroRing(
                label: 'Tinh bột',
                value: '${formatNumber(total((meal) => meal.carbsG))}/${formatNumber(target.carbsG)}g',
                progress: progress(total((meal) => meal.carbsG), target.carbsG),
                ringColor: const Color(0xFF3B82F6),
              ),
              MacroRing(
                label: 'Chất béo',
                value: '${formatNumber(total((meal) => meal.fatG))}/${formatNumber(target.fatG)}g',
                progress: progress(total((meal) => meal.fatG), target.fatG),
                ringColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});

  final List<String> warnings;

  @override
  // Material (không phải Container có màu nền) để ExpansionTile vẽ được hiệu ứng bấm.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: AppColors.warningSoft,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.warningBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline, color: AppColors.warning),
          title: Text(
            'Lưu ý cho kế hoạch này (${warnings.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warning),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $warning', style: const TextStyle(fontSize: 12, color: AppColors.heading)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.action, this.onAction});

  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.primaryBright),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.primaryDark)),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({required this.label, required this.pending, required this.onPressed});

  final String label;
  final bool pending;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: pending
        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.refresh, size: 16),
    label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accent,
      side: const BorderSide(color: AppColors.accent),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.color, this.background, {this.bordered = false});

  final String text;
  final Color color;
  final Color background;
  final bool bordered;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(10),
      border: bordered ? Border.all(color: AppColors.border) : null,
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
    ),
  );
}
```

### Task 4 — Đi chợ

`frontend_app/lib/screens/grocery_screen.dart` (viết lại):

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/meal_plan.dart';
import '../providers/grocery_provider.dart';
import '../providers/plan_provider.dart';
import '../theme/app_colors.dart';

// Danh sách đi chợ 3 ngày (BRD FR-3): dựng từ `grocery_list` server tính (#7); đánh dấu đã mua, ẩn món đã có sẵn
// trong tủ lạnh (FR-3.2). Trạng thái lưu trên máy theo từng plan (`GroceryProvider`).
class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

// Tên nhóm theo BRD FR-3.1.
const groceryCategoryLabels = {
  IngredientCategory.protein: 'Đạm',
  IngredientCategory.produce: 'Rau củ quả',
  IngredientCategory.pantry: 'Gạo, bún & gia vị',
};

const _categoryIcons = {
  IngredientCategory.protein: Icons.set_meal_outlined,
  IngredientCategory.produce: Icons.eco_outlined,
  IngredientCategory.pantry: Icons.rice_bowl_outlined,
};

class _Row {
  const _Row(this.category, this.entry, this.key);

  final IngredientCategory category;
  final GroceryEntry entry;
  final String key;
}

class _GroceryScreenState extends State<GroceryScreen> {
  IngredientCategory? _filter;
  String _query = '';
  bool _showHave = false;

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>().plan;
    final grocery = context.watch<GroceryProvider>();
    if (plan == null) return const SizedBox.shrink();

    final rows = [
      for (final group in plan.groceryList)
        for (final entry in group.items) _Row(group.category, entry, GroceryProvider.keyOf(group.category, entry)),
    ];
    final toBuy = rows.where((row) => !grocery.isHave(row.key)).toList();
    final have = rows.where((row) => grocery.isHave(row.key)).toList();
    final bought = toBuy.where((row) => grocery.isBought(row.key)).length;
    final query = _query.trim().toLowerCase();
    final visible = toBuy
        .where((row) => _filter == null || row.category == _filter)
        .where((row) => query.isEmpty || row.entry.name.toLowerCase().contains(query))
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Danh sách đi chợ 3 ngày',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$bought/${toBuy.length} đã mua',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: toBuy.isEmpty ? 1 : bought / toBuy.length,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.primaryBright,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (text) => setState(() => _query = text),
            decoration: InputDecoration(
              hintText: 'Tìm nguyên liệu…',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Tất cả', null),
                for (final category in IngredientCategory.values)
                  _filterChip(groceryCategoryLabels[category]!, category),
              ],
            ),
          ),
          for (final category in IngredientCategory.values)
            if (visible.any((row) => row.category == category))
              _group(category, visible.where((row) => row.category == category).toList(), grocery),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Không có nguyên liệu nào khớp.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          if (have.isNotEmpty) _haveSection(have, grocery),
        ],
      ),
    );
  }

  Widget _filterChip(String label, IngredientCategory? category) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == category,
      onSelected: (_) => setState(() => _filter = category),
      selectedColor: AppColors.primarySoft,
    ),
  );

  Widget _group(IngredientCategory category, List<_Row> rows, GroceryProvider grocery) {
    final bought = rows.where((row) => grocery.isBought(row.key)).length;
    // Material (không phải Container có màu nền) để các ListTile vẽ được hiệu ứng bấm.
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Column(
          children: [
            ListTile(
              leading: Icon(_categoryIcons[category], color: AppColors.primary),
              title: Text(
                groceryCategoryLabels[category]!.toUpperCase(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.heading),
              ),
              trailing: Text('$bought/${rows.length}', style: const TextStyle(color: AppColors.muted)),
            ),
            const Divider(height: 1),
            for (final row in rows)
              CheckboxListTile(
                value: grocery.isBought(row.key),
                onChanged: (_) => grocery.toggleBought(row.key),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primaryBright,
                title: Text(
                  row.entry.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: grocery.isBought(row.key) ? AppColors.faint : AppColors.ink,
                    decoration: grocery.isBought(row.key) ? TextDecoration.lineThrough : null,
                  ),
                ),
                secondary: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      row.entry.quantity,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted),
                    ),
                    IconButton(
                      tooltip: 'Đã có sẵn trong tủ lạnh',
                      icon: const Icon(Icons.kitchen_outlined, size: 20),
                      onPressed: () => grocery.markHave(row.key),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _haveSection(List<_Row> have, GroceryProvider grocery) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Material(
      color: AppColors.panel,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.kitchen_outlined, color: AppColors.muted),
            title: Text(
              '${have.length} món đã có sẵn',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            trailing: TextButton(
              onPressed: () => setState(() => _showHave = !_showHave),
              child: Text(_showHave ? 'Ẩn' : 'Hiện lại'),
            ),
          ),
          if (_showHave)
            for (final row in have)
              ListTile(
                dense: true,
                title: Text('${row.entry.name} · ${row.entry.quantity}'),
                trailing: TextButton(onPressed: () => grocery.restoreHave(row.key), child: const Text('Cần mua')),
              ),
        ],
      ),
    ),
  );
}
```

### Task 5 — Cá nhân

`frontend_app/lib/screens/profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api/codes.dart';
import '../models/api/profile.dart';
import '../providers/plan_provider.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart' show formatNumber;
import '../widgets/profile_form.dart';

// Tab "Cá nhân" (BRD FR-1.6): xem và sửa hồ sơ bất cứ lúc nào. Sửa xong lưu thành bản nháp — plan đang có vẫn dùng
// hồ sơ cũ (đổi món/feedback không bị 409) — và gợi ý tạo lại plan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onCreatePlan});

  final ValueChanged<Profile> onCreatePlan;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Chỉ có khi đang sửa — tạo lúc bấm "Sửa hồ sơ" để luôn điền đúng hồ sơ mới nhất.
  ProfileFormController? _form;

  bool get _editing => _form != null;

  @override
  void dispose() {
    _form?.dispose();
    super.dispose();
  }

  void _startEditing() => setState(() => _form = ProfileFormController(context.read<PlanProvider>().editableProfile));

  // Widget của form còn dùng controller tới hết frame này — huỷ sau frame.
  void _stopEditing() {
    final form = _form;
    setState(() => _form = null);
    WidgetsBinding.instance.addPostFrameCallback((_) => form?.dispose());
  }

  Future<void> _save(ProfileFormController form) async {
    FocusScope.of(context).unfocus();
    await context.read<PlanProvider>().saveDraft(form.toProfile());
    if (mounted) _stopEditing();
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final profile = plans.editableProfile;
    if (profile == null) return const SizedBox.shrink();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'Hồ sơ của bạn',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chỉ lưu trên máy này, không gửi lưu ở máy chủ.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (plans.hasPendingProfile && !_editing)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryBright),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.',
                      style: TextStyle(fontSize: 13, color: AppColors.primaryDark),
                    ),
                  ),
                  TextButton(
                    onPressed: plans.busy ? null : () => widget.onCreatePlan(plans.draft!),
                    child: const Text('Tạo kế hoạch mới'),
                  ),
                ],
              ),
            ),
          if (_form case final form?) ..._editor(form) else ..._summary(plans, profile),
        ],
      ),
    );
  }

  List<Widget> _summary(PlanProvider plans, Profile profile) {
    final target = plans.plan?.dailyTarget;
    final restrictions = profile.restrictions;
    String orNone(String text) => text.isEmpty ? 'Không có' : text;
    return [
      const SizedBox(height: 12),
      _SummaryCard(
        rows: [
          ('Tuổi', '${profile.age}'),
          ('Giới tính', profile.gender == Gender.female ? 'Nữ' : 'Nam'),
          if (profile.pregnantOrBreastfeeding) ('Mang thai / cho con bú', 'Có'),
          ('Chiều cao', '${formatNumber(profile.heightCm)} cm'),
          ('Cân nặng', '${formatNumber(profile.weightKg)} kg'),
          ('Vận động', activityLabel(profile.activityLevel)),
          ('Mục tiêu', goalLabel(profile.goal)),
          if (target != null && !plans.hasPendingProfile) ...[
            ('BMI', formatNumber(target.bmi)),
            ('Calo mục tiêu', '${target.targetCalories} kcal/ngày'),
          ],
          ('Dị ứng', orNone(restrictions.allergies)),
          ('Chấn thương', orNone(restrictions.injuries)),
          ('Bệnh nền', orNone(restrictions.healthConditions)),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _startEditing,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Sửa hồ sơ'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ];
  }

  List<Widget> _editor(ProfileFormController form) => [
    BodySection(form: form),
    GoalSection(form: form),
    const SectionTitle('Hạn chế & sức khoẻ'),
    RestrictionsSection(form: form),
    const SizedBox(height: 16),
    ListenableBuilder(
      listenable: form,
      builder: (context, _) => Row(
        children: [
          TextButton(onPressed: _stopEditing, child: const Text('Huỷ')),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: form.valid ? () => _save(form) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBright,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Lưu hồ sơ', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ),
  ];
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
```

### Task 6 — Khung app

`frontend_app/lib/main.dart` (viết lại):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'models/api/profile.dart';
import 'providers/auth_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/plan_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/grocery_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_client.dart';
import 'services/api_exception.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vẽ dưới thanh trạng thái (màn hình dùng SafeArea) — không còn dải đen trên nền sáng.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Đọc hết dữ liệu đã lưu một lần trước khi vẽ màn đầu — MainShell biết ngay có plan hay chưa, không cần màn chờ.
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: resolveApiBaseUrl());
  final plans = PlanProvider(api: api, prefs: prefs);
  runApp(
    SmartFitApp(
      auth: AuthProvider(api: api, prefs: prefs),
      plans: plans,
      grocery: GroceryProvider(prefs: prefs, plans: plans),
    ),
  );
}

class SmartFitApp extends StatelessWidget {
  const SmartFitApp({super.key, required this.auth, required this.plans, required this.grocery});

  final AuthProvider auth;
  final PlanProvider plans;
  final GroceryProvider grocery;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: plans),
        ChangeNotifierProvider.value(value: grocery),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: MaterialApp(
          title: 'SmartFit AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00875A),
              primary: const Color(0xFF00875A),
              surface: const Color(0xFFF8F9FA),
            ),
          ),
          home: const MainShell(),
        ),
      ),
    );
  }
}

enum AppScreen { onboarding, loading, home }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // Chưa có plan → bắt đầu từ Onboarding; đã có plan đã lưu → vào thẳng màn chính, không cần mạng (NFR-2).
  late AppScreen _screen = context.read<PlanProvider>().hasPlan ? AppScreen.home : AppScreen.onboarding;
  int _tab = 0; // 0: Kế hoạch, 1: Đi chợ, 2: Lịch sử, 3: Cá nhân
  // Hồ sơ của lần tạo plan gần nhất — để thử lại hoặc sửa khi lỗi.
  Profile? _requested;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Mở lại app sau nửa đêm → Dashboard tính lại ngày hôm nay của plan (D6-B1).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _generate(Profile profile) async {
    final plans = context.read<PlanProvider>();
    setState(() {
      _screen = AppScreen.loading;
      _requested = profile;
      _error = null;
    });
    try {
      await plans.generate(profile);
      if (mounted) {
        setState(() {
          _screen = AppScreen.home;
          _tab = 0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final screen = _screen == AppScreen.home && !plans.hasPlan ? AppScreen.onboarding : _screen;
    return switch (screen) {
      AppScreen.onboarding => OnboardingScreen(initial: _requested ?? plans.editableProfile, onSubmit: _generate),
      AppScreen.loading => LoadingScreen(
        error: _error,
        onRetry: () => _generate(_requested!),
        onEditProfile: () => setState(() => _screen = AppScreen.onboarding),
        onBack: plans.hasPlan ? () => setState(() => _screen = AppScreen.home) : null,
      ),
      AppScreen.home => _home(plans),
    };
  }

  Widget _home(PlanProvider plans) => Scaffold(
    body: switch (_tab) {
      // Khoá theo plan_id: plan mới thì Dashboard mở lại đúng ngày hôm nay.
      0 => DashboardScreen(key: ValueKey(plans.plan?.planId), onCreatePlan: () => _generate(plans.editableProfile!)),
      1 => const GroceryScreen(),
      2 => _placeholder(
        icon: Icons.history_rounded,
        title: 'Lịch sử kế hoạch',
        subtitle: 'Đăng nhập để xem lại các kế hoạch đã tạo — tính năng sắp có.',
      ),
      _ => ProfileScreen(onCreatePlan: _generate),
    },
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00875A),
        unselectedItemColor: AppColors.faint,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Kế hoạch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Đi chợ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    ),
  );

  Widget _placeholder({required IconData icon, required String title, required String subtitle}) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 36, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
```

```bash
cd frontend_app
git rm lib/models/meal_plan.dart lib/widgets/feedback_bottom_sheet.dart
```

### Task 7 — Test

`frontend_app/test/app_harness.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/models/plan_schedule.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/grocery_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fixture_loader.dart';

// Dựng app hoặc một màn hình với backend giả (fixture hợp đồng), dữ liệu đã lưu và đồng hồ giả, trên màn hình cỡ
// điện thoại (411×914 dp — Pixel 8). Không gọi mạng thật.
class Harness {
  Harness._(this.backend, this.prefs, this.auth, this.plans, this.grocery);

  final FakeBackend backend;
  final SharedPreferences prefs;
  final AuthProvider auth;
  final PlanProvider plans;
  final GroceryProvider grocery;

  static Future<Harness> create(WidgetTester tester, {Map<String, Object> saved = const {}, DateTime? now}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    final clock = now ?? planStart;
    final plans = PlanProvider(api: backend.api, prefs: prefs, now: () => clock);
    return Harness._(
      backend,
      prefs,
      AuthProvider(api: backend.api, prefs: prefs),
      plans,
      GroceryProvider(prefs: prefs, plans: plans),
    );
  }

  Widget app() => SmartFitApp(auth: auth, plans: plans, grocery: grocery);

  // Một màn hình đứng riêng, có Scaffold để hiện SnackBar.
  Widget screen(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: plans),
      ChangeNotifierProvider.value(value: grocery),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// Plan fixture bắt đầu ngày 26/9/2026.
final planStart = DateTime(2026, 9, 26, 9);

Map<String, Object> savedPlan({Map<String, dynamic>? profile}) {
  final plan = loadFixture('generate_plan');
  return {
    PlanProvider.profileKey: jsonEncode(profile ?? loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(plan),
    PlanProvider.scheduleKey: jsonEncode(PlanSchedule.startingOn(plan['plan_id'] as String, planStart).toJson()),
  };
}

Finder field(String label) => find.widgetWithText(TextField, label);

// Danh sách chỉ dựng phần đang hiện: cuộn danh sách chính (không phải vùng cuộn của ô nhập) tới [finder].
// scrollUntilVisible dừng khi widget đã được dựng dù còn sát ngoài mép — ensureVisible kéo hẳn vào màn hình.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

bool enabled(WidgetTester tester, String buttonText) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(of: find.text(buttonText), matching: find.bySubtype<ButtonStyleButton>()).first,
    )
    .enabled;

// Điền đủ 3 bước Onboarding: nữ 22 tuổi, 168 cm, 62 kg, vận động nhẹ, Giảm mỡ, dị ứng hải sản, đau gối.
Future<void> fillOnboarding(WidgetTester tester) async {
  await tester.tap(find.text('Nữ'));
  await tester.enterText(field('Tuổi'), '22');
  await tester.enterText(field('Chiều cao (cm)'), '168');
  await tester.enterText(field('Cân nặng (kg)'), '62');
  await tester.pump();
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Vận động nhẹ'));
  await tester.tap(find.text('Giảm mỡ & giữ cơ'));
  await tester.pump();
  await tester.tap(find.text('Tiếp tục'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tôi có dị ứng thực phẩm'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hải sản'));
  await tester.tap(find.text('Tôi có chấn thương'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Đầu gối'));
  await tester.pump();
}
```

`frontend_app/test/screens/onboarding_screen_test.dart`:

```dart
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
```

`frontend_app/test/screens/dashboard_screen_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';

import '../app_harness.dart';
import '../fixture_loader.dart';

void main() {
  Future<(Harness, List<String>)> pumpDashboard(WidgetTester tester, {DateTime? now}) async {
    final harness = await Harness.create(tester, saved: savedPlan(), now: now);
    final created = <String>[];
    await tester.pumpWidget(harness.screen(DashboardScreen(onCreatePlan: () => created.add('tạo mới'))));
    return (harness, created);
  }

  testWidgets('mở đúng ngày hôm nay: đủ 3 bữa (có bữa sáng), tổng calo so với mục tiêu, lưu ý của plan', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(find.text('Thứ Bảy, 26/9'), findsOneWidget);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(find.text('BỮA SÁNG'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsOneWidget);
    expect(find.textContaining('kcal mục tiêu'), findsOneWidget);
    expect(find.text('Lưu ý cho kế hoạch này (2)'), findsOneWidget);
    expect(find.text('Thực đơn mẫu'), findsOneWidget);
  });

  testWidgets('đổi sang ngày khác bằng bộ chọn 3 ngày', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Ngày 2'));
    await tester.pumpAndSettle();
    expect(find.text('Ngày 2 của kế hoạch'), findsOneWidget);
    expect(find.text('Bánh mì trứng ốp la'), findsOneWidget);
    expect(find.text('Bún thịt bò nạc'), findsNothing);
  });

  testWidgets('hai ngày sau khi bắt đầu → mở sẵn ngày 3; quá 3 ngày → nhắc tạo kế hoạch mới', (tester) async {
    await pumpDashboard(tester, now: planStart.add(const Duration(days: 2)));
    expect(find.text('Hôm nay là Ngày 3'), findsOneWidget);

    final (_, created) = await pumpDashboard(tester, now: planStart.add(const Duration(days: 4)));
    expect(find.textContaining('Kế hoạch 3 ngày đã hết'), findsOneWidget);
    await tester.tap(find.text('Tạo kế hoạch mới'));
    expect(created, ['tạo mới']);
  });

  testWidgets('đổi món gọi API và hiện món mới (FR-4.1)', (tester) async {
    final (harness, _) = await pumpDashboard(tester);
    await tester.tap(find.text('Đổi món').at(1));
    await tester.pumpAndSettle();

    expect(harness.backend.paths, ['/api/v1/meals/swap']);
    expect(find.text('Đã đổi bữa trưa sang: Cơm đậu phụ nhồi thịt sốt cà'), findsOneWidget);
    expect(find.text('Cơm đậu phụ nhồi thịt sốt cà'), findsOneWidget);
  });

  testWidgets('409 → câu của server + nút tạo kế hoạch mới; món cũ giữ nguyên', (tester) async {
    final (harness, created) = await pumpDashboard(tester);
    harness.backend.failWith = 409;
    final firstExercise = loadFixture('generate_plan')['days'][0]['workout']['exercises'][0]['name'] as String;
    await scrollTo(tester, find.text(firstExercise));
    await tester.tap(find.text('Đổi bài').first);
    await tester.pumpAndSettle();

    expect(find.text(loadFixture('error_409')['message'] as String), findsOneWidget);
    await tester.tap(find.text('Tạo mới'));
    expect(created, ['tạo mới']);
    expect(harness.plans.plan!.toJson(), loadFixture('generate_plan'));
  });

  testWidgets('hồ sơ đã sửa ở tab Cá nhân → dải nhắc tạo kế hoạch mới', (tester) async {
    final (harness, created) = await pumpDashboard(tester);
    await harness.plans.saveDraft(Profile.fromJson({...loadFixture('profile'), 'goal': 'bulk'}));
    await tester.pump();
    expect(find.text('Hồ sơ đã thay đổi. Tạo kế hoạch mới để áp dụng.'), findsOneWidget);
    await tester.tap(find.text('Tạo kế hoạch mới'));
    expect(created, ['tạo mới']);
  });
}
```

`frontend_app/test/screens/grocery_screen_test.dart`:

```dart
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
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Rau củ quả').first);
    await tester.pump();
    expect(find.text('ĐẠM'), findsNothing);
    expect(find.text('RAU CỦ QUẢ'), findsOneWidget);
  });
}
```

`frontend_app/test/screens/profile_screen_test.dart`:

```dart
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
```

`frontend_app/test/widget_test.dart` (viết lại):

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';

import 'app_harness.dart';
import 'fixture_loader.dart';

// Luồng của app (PLAN 5.6, 6.1–6.3, 6.7). Không gọi mạng thật: backend giả trả fixture hợp đồng.
void main() {
  testWidgets('chưa có plan → Onboarding, không gọi mạng', (tester) async {
    final harness = await Harness.create(tester);
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
  });

  testWidgets('đã có plan đã lưu → mở thẳng Dashboard, không cần mạng', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(harness.backend.requests, isEmpty);
  });

  testWidgets('plan đã lưu bị hỏng → Onboarding, không crash', (tester) async {
    final harness = await Harness.create(tester, saved: {...savedPlan(), PlanProvider.planKey: '{"days": "hỏng"}'});
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('hồ sơ lưu từ trước nay bị luật v2.6.0 chặn (17 tuổi) → Onboarding điền sẵn, báo lỗi tuổi', (
    tester,
  ) async {
    final harness = await Harness.create(tester, saved: savedPlan(profile: {...loadFixture('profile'), 'age': 17}));
    await tester.pumpWidget(harness.app());
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('SmartFit dành cho người từ 18 tuổi'), findsOneWidget);
  });

  testWidgets('Onboarding → màn chờ → Dashboard với plan server trả; gửi đúng hồ sơ đã chọn', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.hold = Completer<void>();
    await tester.pumpWidget(harness.app());
    await fillOnboarding(tester);
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    await tester.pump();
    expect(find.text('Đang lập kế hoạch 3 ngày cho bạn'), findsOneWidget);

    harness.backend.hold!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
    expect(harness.backend.paths, ['/api/v1/generate-plan']);
    final body = jsonDecode(utf8.decode(harness.backend.requests.single.bodyBytes)) as Map<String, dynamic>;
    expect(body['restrictions'], {'allergies': 'Hải sản', 'injuries': 'Đầu gối', 'health_conditions': ''});
    expect(body['pregnant_or_breastfeeding'], isFalse);
  });

  testWidgets('tạo plan lỗi → báo lỗi, không crash; "Thử lại" tạo được plan', (tester) async {
    final harness = await Harness.create(tester);
    harness.backend.failWith = 400;
    await tester.pumpWidget(harness.app());
    await fillOnboarding(tester);
    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa tạo được kế hoạch'), findsOneWidget);
    expect(find.text('Về kế hoạch đang có'), findsNothing);

    harness.backend.failWith = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay là Ngày 1'), findsOneWidget);
  });

  testWidgets('thanh điều hướng: Đi chợ, Lịch sử (sắp có), Cá nhân', (tester) async {
    final harness = await Harness.create(tester, saved: savedPlan());
    await tester.pumpWidget(harness.app());
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ 3 ngày'), findsOneWidget);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử kế hoạch'), findsOneWidget);
    expect(find.textContaining('1.850'), findsNothing, reason: 'không còn số liệu viết cứng');
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ của bạn'), findsOneWidget);
  });
}
```

```diff
--- a/frontend_app/integration_test/backend_smoke_test.dart
+++ b/frontend_app/integration_test/backend_smoke_test.dart
@@ -7,12 +7,15 @@
 import 'package:my_ai_app/models/api/codes.dart';
 import 'package:my_ai_app/models/api/profile.dart';
 import 'package:my_ai_app/providers/auth_provider.dart';
+import 'package:my_ai_app/providers/grocery_provider.dart';
 import 'package:my_ai_app/providers/plan_provider.dart';
 import 'package:my_ai_app/screens/dashboard_screen.dart';
 import 'package:my_ai_app/services/api_client.dart';
 import 'package:my_ai_app/services/api_exception.dart';
 import 'package:shared_preferences/shared_preferences.dart';
 
+import '../test/app_harness.dart' show fillOnboarding;
+
 // Chạy TAY trên máy ảo hoặc điện thoại thật, khi backend_api đang chạy ở chế độ giả lập — không chạy trong CI
 // (`flutter test` chỉ chạy thư mục test/):
 //
@@ -89,7 +92,7 @@
     );
 
     // Có plan đã lưu → app mở thẳng Dashboard.
-    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans));
+    await tester.pumpWidget(SmartFitApp(auth: auth, plans: plans, grocery: GroceryProvider(prefs: prefs, plans: plans)));
     await tester.pump(const Duration(seconds: 1));
     expect(find.byType(DashboardScreen), findsOneWidget);
     await tester.pumpWidget(const SizedBox());
@@ -105,4 +108,35 @@
     final closedPort = ApiClient(baseUrl: base.replace(port: 1).toString());
     await expectLater(closedPort.health(), throwsA(isA<NetworkException>()));
   });
+
+  // Thao tác giao diện thật trên thiết bị (giai đoạn 6): Onboarding → backend thật tạo plan → Dashboard → đổi món.
+  testWidgets('giao diện trên thiết bị: điền Onboarding → plan thật → Dashboard → đổi món', (tester) async {
+    final prefs = await SharedPreferences.getInstance();
+    await prefs.clear();
+    final api = ApiClient(baseUrl: resolveApiBaseUrl());
+    final plans = PlanProvider(api: api, prefs: prefs);
+    await tester.pumpWidget(SmartFitApp(
+      auth: AuthProvider(api: api, prefs: prefs),
+      plans: plans,
+      grocery: GroceryProvider(prefs: prefs, plans: plans),
+    ));
+    await fillOnboarding(tester);
+    await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
+    await pumpUntil(tester, find.text('Hôm nay là Ngày 1'));
+    expect(find.text('BỮA SÁNG'), findsOneWidget);
+
+    await tester.tap(find.text('Đổi món').first);
+    await pumpUntil(tester, find.textContaining('Đã đổi bữa sáng sang'));
+    await tester.pumpWidget(const SizedBox());
+    await prefs.clear();
+  });
 }
+
+// Mạng thật: vòng xoay chờ không bao giờ "settle", nên pump tới khi thấy [finder] (tối đa 60 s như timeout của app).
+Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
+  for (var waited = 0; waited < 600; waited++) {
+    await tester.pump(const Duration(milliseconds: 100));
+    if (finder.evaluate().isNotEmpty) return;
+  }
+  fail('Không thấy $finder sau 60 s');
+}
```

### Task 8 — Cổng kiểm tra F04

```bash
cd frontend_app
flutter analyze   # No issues found!
flutter test      # +89: All tests passed!
# Tay, có máy ảo và backend giả lập (không GEMINI_API_KEY) đang chạy:
flutter test integration_test -d emulator-5554   # +3: All tests passed!
```
