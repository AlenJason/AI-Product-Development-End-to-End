import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../models/profile_rules.dart';
import '../../models/api/profile.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/progress_header.dart';
import '../../widgets/ui_kit.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key, this.initialProfile});
  final Profile? initialProfile;
  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  final _edited = <String>{};

  @override
  void initState() {
    super.initState();
    final form = context.read<OnboardingProvider>();
    if (widget.initialProfile != null) {
      form.loadProfile(widget.initialProfile!, notify: false);
    }
    _age = TextEditingController(text: form.ageText);
    _height = TextEditingController(text: form.heightText);
    _weight = TextEditingController(text: form.weightText);
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _change(String field) {
    _edited.add(field);
    context.read<OnboardingProvider>().updateBodyText(
      newAge: _age.text,
      newHeight: _height.text,
      newWeight: _weight.text,
    );
  }

  String? _error(String field, String text, String? Function(String) check) =>
      text.isNotEmpty || _edited.contains(field) ? check(text) : null;

  @override
  Widget build(BuildContext context) {
    final form = context.watch<OnboardingProvider>();
    final age = CustomTextField(
      label: 'Tuổi',
      controller: _age,
      fieldKey: const Key('age-input'),
      keyboardType: TextInputType.number,
      onChanged: (_) => _change('age'),
      errorText: _error('age', form.ageText, ageError),
    );
    final height = CustomTextField(
      label: 'Chiều cao (cm)',
      controller: _height,
      fieldKey: const Key('height-input'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _change('height'),
      errorText: _error('height', form.heightText, heightError),
    );
    final weight = CustomTextField(
      label: 'Cân nặng (kg)',
      controller: _weight,
      fieldKey: const Key('weight-input'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _change('weight'),
      errorText: _error('weight', form.weightText, weightError),
    );
    final gender = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giới tính', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final value in ['Nam', 'Nữ'])
              ChoiceChip(
                showCheckmark: false,
                label: Text(value),
                selected: form.gender == value,
                onSelected: (_) => form.updateGender(value),
              ),
          ],
        ),
      ],
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            ProgressHeader(
              currentStep: 1,
              totalSteps: 3,
              onBack: () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ScreenHeading(
                      title: 'Chỉ số cơ thể',
                      subtitle: 'Cho SmartFit biết một chút về bạn để tính toán kế hoạch phù hợp.',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumns =
                            constraints.maxWidth >= 310 &&
                            MediaQuery.textScalerOf(context).scale(14) <= 18;
                        if (!twoColumns) {
                          return Column(
                            children: [
                              age,
                              const SizedBox(height: 16),
                              gender,
                              const SizedBox(height: 16),
                              height,
                              const SizedBox(height: 16),
                              weight,
                            ],
                          );
                        }
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: age),
                                const SizedBox(width: 12),
                                Expanded(child: gender),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: height),
                                const SizedBox(width: 12),
                                Expanded(child: weight),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    if (form.gender == 'Nữ' ||
                        form.pregnantOrBreastfeeding) ...[
                      const SizedBox(height: 18),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Đang mang thai hoặc cho con bú'),
                          value: form.pregnantOrBreastfeeding,
                          onChanged: (value) =>
                              form.updatePregnancy(value ?? false),
                          subtitle: form.gender != 'Nữ'
                              ? const Text(
                                  'Chỉ nữ mới khai báo mang thai / cho con bú',
                                )
                              : null,
                        ),
                      ),
                    ],
                    if (form.pregnantOrBreastfeeding)
                      const NoticePanel(
                        message: 'Hãy hỏi ý kiến bác sĩ trước khi áp dụng kế hoạch ăn uống hoặc tập luyện.',
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: PrimaryButton(
                text: 'Tiếp tục',
                onPressed: form.bodyValid
                    ? () => Navigator.pushNamed(
                        context,
                        AppRoutes.onboardingActivity,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
