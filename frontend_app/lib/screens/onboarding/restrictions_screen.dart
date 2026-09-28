import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/progress_header.dart';

class RestrictionsScreen extends StatefulWidget {
  const RestrictionsScreen({super.key});

  @override
  State<RestrictionsScreen> createState() => _RestrictionsScreenState();
}

class _RestrictionsScreenState extends State<RestrictionsScreen> {
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _injuriesController = TextEditingController();
  final TextEditingController _healthController = TextEditingController();

  final List<String> _suggestions = ['Hải sản', 'Trứng', 'Sữa', 'Đậu phộng', 'Đau gối', 'Đau lưng'];
  final Set<String> _selectedSuggestions = {'Đau gối'};

  @override
  void initState() {
    super.initState();
    _injuriesController.text = 'Đau gối';
  }

  @override
  void dispose() {
    _allergiesController.dispose();
    _injuriesController.dispose();
    _healthController.dispose();
    super.dispose();
  }

  void _onContinue() {
    context.read<OnboardingProvider>().updateRestrictions(
      newAllergies: _allergiesController.text,
      newInjuries: _injuriesController.text,
      conditions: _healthController.text,
    );
    Navigator.pushNamed(context, AppRoutes.generatingPlan);
  }

  void _toggleSuggestion(String suggestion) {
    setState(() {
      if (_selectedSuggestions.contains(suggestion)) {
        _selectedSuggestions.remove(suggestion);
        // Basic naive removal for mock
        _injuriesController.text = _injuriesController.text.replaceAll(suggestion, '').trim();
        _allergiesController.text = _allergiesController.text.replaceAll(suggestion, '').trim();
      } else {
        _selectedSuggestions.add(suggestion);
        if (suggestion.contains('Đau')) {
          _injuriesController.text = _injuriesController.text.isEmpty ? suggestion : '${_injuriesController.text}, $suggestion';
        } else {
          _allergiesController.text = _allergiesController.text.isEmpty ? suggestion : '${_allergiesController.text}, $suggestion';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressHeader(
              currentStep: 4,
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
                      child: const Icon(Icons.health_and_safety, color: AppColors.primary, size: 32),
                    ),
                    const SizedBox(height: 24),
                    Text('Có điều gì SmartFit cần lưu ý?', style: AppTextStyles.h1),
                    const SizedBox(height: 8),
                    Text('Thông tin này giúp gợi ý an toàn hơn cho bạn.', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 32),
                    
                    CustomTextField(
                      label: 'Dị ứng / thực phẩm cần tránh',
                      hintText: 'Ví dụ: hải sản, trứng, sữa...',
                      controller: _allergiesController,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Chấn thương / vùng cần tránh',
                      controller: _injuriesController,
                    ),
                    const SizedBox(height: 20),
                    CustomTextField(
                      label: 'Tình trạng sức khỏe',
                      hintText: 'Ví dụ: tiểu đường, cao huyết áp...',
                      controller: _healthController,
                    ),
                    const SizedBox(height: 20),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _suggestions.map((s) {
                        final isSelected = _selectedSuggestions.contains(s);
                        return GestureDetector(
                          onTap: () => _toggleSuggestion(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primarySoft : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.check, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  s,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isSelected ? AppColors.primary : AppColors.ink,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Thông tin này chỉ mang tính tham khảo và không thay thế tư vấn y tế.',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  PrimaryButton(
                    text: 'Tạo kế hoạch của tôi',
                    onPressed: _onContinue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn có thể để trống nếu không có hạn chế.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



