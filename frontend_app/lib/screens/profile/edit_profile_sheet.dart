import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/profile_rules.dart';
import '../../models/restriction_options.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/plan_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/restriction_fields.dart';
import '../../widgets/ui_kit.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final OnboardingProvider _form;
  late final TextEditingController _age, _height, _weight;
  final _other = <RestrictionKind, TextEditingController>{};
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _form = OnboardingProvider();
    final saved = context.read<PlanProvider>().editableProfile;
    if (saved != null) _form.loadProfile(saved);
    _age = TextEditingController(text: _form.ageText);
    _height = TextEditingController(text: _form.heightText);
    _weight = TextEditingController(text: _form.weightText);
    for (final kind in RestrictionKind.values) {
      _other[kind] = TextEditingController(text: _form.selection(kind).other);
    }
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    for (final c in _other.values) {
      c.dispose();
    }
    _form.dispose();
    super.dispose();
  }

  void _change() => _form.updateBodyText(
    newAge: _age.text,
    newHeight: _height.text,
    newWeight: _weight.text,
  );
  Future<void> _save(bool regenerate) async {
    final plans = context.read<PlanProvider>();
    if (_saving || plans.busy) return;
    try {
      final edited = _form.toProfile();
      setState(() {
        _saving = true;
        _error = null;
      });
      await plans.saveDraft(edited);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.pop();
      if (regenerate) {
        navigator.pushNamed(AppRoutes.generatingPlan, arguments: edited);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Đã lưu hồ sơ trên máy. Kế hoạch hiện tại chưa thay đổi.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không thể lưu hồ sơ. Vui lòng kiểm tra thông tin và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<PlanProvider>().busy || _saving;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          12,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _form,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Chỉnh sửa hồ sơ', style: AppTextStyles.h2),
                const SizedBox(height: 6),
                Text(
                  'Thay đổi được lưu riêng; chỉ áp dụng vào kế hoạch sau khi tạo lại thành công.',
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  label: 'Tuổi',
                  fieldKey: const Key('edit-age'),
                  controller: _age,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _change(),
                  errorText: ageError(_form.ageText),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Chiều cao (cm)',
                  fieldKey: const Key('edit-height'),
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _change(),
                  errorText: heightError(_form.heightText),
                ),
                const SizedBox(height: 14),
                CustomTextField(
                  label: 'Cân nặng (kg)',
                  fieldKey: const Key('edit-weight'),
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _change(),
                  errorText: weightError(_form.weightText),
                ),
                const SectionTitle(title: 'Giới tính'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final gender in ['Nam', 'Nữ'])
                      ChoiceChip(
                        label: Text(gender),
                        selected: _form.gender == gender,
                        onSelected: busy
                            ? null
                            : (_) => _form.updateGender(gender),
                      ),
                  ],
                ),
                if (_form.gender == 'Nữ' || _form.pregnantOrBreastfeeding)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Đang mang thai hoặc cho con bú'),
                    subtitle: _form.gender != 'Nữ'
                        ? const Text(
                            'Chỉ nữ mới khai báo mang thai / cho con bú',
                          )
                        : null,
                    value: _form.pregnantOrBreastfeeding,
                    onChanged: busy
                        ? null
                        : (v) => _form.updatePregnancy(v ?? false),
                  ),
                const SectionTitle(title: 'Mục tiêu'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final goal in ['Giảm mỡ', 'Tăng cơ', 'Duy trì'])
                      ChoiceChip(
                        key: Key('edit-goal-$goal'),
                        label: Text(goal),
                        selected: _form.goal == goal,
                        onSelected:
                            busy ||
                                (goal == 'Giảm mỡ' && _form.cutReason != null)
                            ? null
                            : (_) => _form.updateGoal(goal),
                      ),
                  ],
                ),
                if (_form.cutReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: NoticePanel(message: _form.cutReason!),
                  ),
                const SectionTitle(title: 'Mức độ vận động'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final activity in [
                      'Ít vận động',
                      'Vận động nhẹ',
                      'Vận động nhiều',
                    ])
                      ChoiceChip(
                        label: Text(activity),
                        selected: _form.activityLevel == activity,
                        onSelected: busy
                            ? null
                            : (_) => _form.updateActivity(activity),
                      ),
                  ],
                ),
                const SectionTitle(title: 'SmartFit cần lưu ý'),
                for (final kind in RestrictionKind.values)
                  RestrictionFields(
                    form: _form,
                    kind: kind,
                    controller: _other[kind]!,
                  ),
                const NoticePanel(
                  message: 'Gợi ý chỉ mang tính tham khảo, không thay thế tư vấn y tế.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: NoticePanel(message: _error!, error: true),
                  ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Lưu & tạo lại kế hoạch',
                  icon: Icons.auto_awesome,
                  onPressed: busy || !_form.canSubmit
                      ? null
                      : () => _save(true),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: busy || !_form.canSubmit
                        ? null
                        : () => _save(false),
                    child: const Text('Chỉ lưu thông tin'),
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
