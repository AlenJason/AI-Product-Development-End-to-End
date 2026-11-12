import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../ui_kit.dart';

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.onBack,
  });
  final int currentStep, totalSteps;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Quay lại',
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BrandLogo(compact: true),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$currentStep/$totalSteps',
              style: AppTextStyles.label.copyWith(
                fontSize: 13,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            minHeight: 4,
            color: AppColors.greenLight,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    ),
  );
}
