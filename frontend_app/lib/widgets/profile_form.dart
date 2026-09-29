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

  // Mọi thứ đang nhập dở (kể cả ô chưa hợp lệ) — lưu tạm qua state restoration của Flutter: hệ thống tắt app ở nền
  // thì mở lại còn nguyên, người dùng force-quit thì mất (PLAN D8). Không ghi xuống shared_preferences.
  Map<String, Object?> toSnapshot() => {
    'age': age.text,
    'height': height.text,
    'weight': weight.text,
    'gender': gender?.name,
    'pregnant': pregnantOrBreastfeeding,
    'activity': activityLevel?.name,
    'goal': goal?.name,
    for (final kind in RestrictionKind.values)
      kind.name: {
        'enabled': restrictions[kind]!.enabled,
        'chosen': restrictions[kind]!.chosen.toList(),
        'other': restrictions[kind]!.other,
      },
  };

  void restoreSnapshot(Map<String, Object?> snapshot) {
    age.text = snapshot['age'] as String? ?? '';
    height.text = snapshot['height'] as String? ?? '';
    weight.text = snapshot['weight'] as String? ?? '';
    gender = Gender.values.asNameMap()[snapshot['gender']];
    pregnantOrBreastfeeding = snapshot['pregnant'] == true;
    activityLevel = ActivityLevel.values.asNameMap()[snapshot['activity']];
    goal = Goal.values.asNameMap()[snapshot['goal']];
    for (final kind in RestrictionKind.values) {
      if (snapshot[kind.name] case {
        'enabled': final bool enabled,
        'chosen': final List<Object?> chosen,
        'other': final String other,
      }) {
        restrictions[kind] = RestrictionSelection(
          enabled: enabled,
          chosen: chosen.whereType<String>().toSet(),
          other: other,
        );
      }
    }
    notifyListeners();
  }

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
