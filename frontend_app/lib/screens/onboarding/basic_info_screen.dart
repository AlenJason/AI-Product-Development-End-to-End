import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/progress_header.dart';

class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  final TextEditingController _ageController = TextEditingController(text: '22');
  final TextEditingController _heightController = TextEditingController(text: '168');
  final TextEditingController _weightController = TextEditingController(text: '62');
  String _gender = 'Nam';

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onContinue() {
    final provider = context.read<OnboardingProvider>();
    provider.updateBasicInfo(
      newAge: int.tryParse(_ageController.text) ?? 22,
      newGender: _gender,
      newHeight: num.tryParse(_heightController.text) ?? 168,
      newWeight: num.tryParse(_weightController.text) ?? 62,
    );
    Navigator.pushNamed(context, AppRoutes.onboardingActivity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressHeader(
              currentStep: 1,
              totalSteps: 4,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 24),
                    Text('Cho SmartFit biết một chút về bạn', style: AppTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Thông tin giúp chúng tôi tính toán kế hoạch phù hợp.', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 32),
                    
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Tuổi',
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Giới tính', style: AppTextStyles.label),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.panel,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    _buildGenderToggle('Nam'),
                                    _buildGenderToggle('Nữ'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Chiều cao',
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Text('cm', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.faint, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomTextField(
                            label: 'Cân nặng',
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Text('kg', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.faint, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                text: 'Tiếp tục',
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderToggle(String text) {
    final isSelected = _gender == text;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = text),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}







