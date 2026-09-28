import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/states/system_states.dart';

class SystemStatesScreen extends StatelessWidget {
  const SystemStatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('Trạng thái giao diện', style: AppTextStyles.h3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SystemStates.loadingState(),
            const SizedBox(height: 24),
            SystemStates.emptyState(onCreatePlan: () {}),
            const SizedBox(height: 24),
            SystemStates.errorState(onRetry: () {}),
            const SizedBox(height: 24),
            SystemStates.fallbackState(),
            const SizedBox(height: 24),
            SystemStates.warningState(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
