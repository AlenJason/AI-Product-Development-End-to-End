import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/custom_text_field.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  String _selectedGoal = '';

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingProvider>();
    _ageCtrl = TextEditingController(text: '${data.age}');
    _weightCtrl = TextEditingController(text: '${data.weightKg}');
    _selectedGoal = data.goal;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handling keyboard overlapping by using ViewInsets
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Chỉnh sửa hồ sơ', style: AppTextStyles.h1.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                'Cập nhật thông tin cơ thể và mục tiêu.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Tuổi',
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          label: 'Cân nặng (kg)',
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Mục tiêu', style: AppTextStyles.h3.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  // In a full app, this would open a selector. For this UI, we just mock toggle or leave as is.
                  setState(() {
                    _selectedGoal = _selectedGoal == 'Giảm mỡ' ? 'Tăng cơ' : 'Giảm mỡ';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedGoal, style: AppTextStyles.h3.copyWith(fontSize: 16)),
                      const Icon(Icons.arrow_forward, color: AppColors.ink, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Light blue
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Thông tin mới có thể thay đổi nhu cầu năng lượng của bạn.',
                        style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF1E3A8A)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                text: 'Lưu & tạo lại kế hoạch',
                onPressed: _saveAndClose,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saveAndClose,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Chỉ lưu thông tin',
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndClose() {
    final age = int.tryParse(_ageCtrl.text) ?? 22;
    final weight = num.tryParse(_weightCtrl.text) ?? 62.0;

    final provider = context.read<OnboardingProvider>();
    provider.updateBasicInfo(
      newAge: age,
      newGender: provider.gender,
      newHeight: provider.heightCm,
      newWeight: weight,
    );
    provider.updateGoal(_selectedGoal);

    Navigator.pop(context);
  }
}

