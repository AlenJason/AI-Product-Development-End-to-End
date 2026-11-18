import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/plan_provider.dart';

import '../../core/constants/routes.dart';
import '../../widgets/ui_kit.dart';
import 'plan_screen.dart';

// No separate result frame exists in the export: reuse the designed Plan view.
class GeneratedPlanScreen extends StatelessWidget {
  const GeneratedPlanScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('generated-plan'),
    body: const PlanScreen(),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GradientButton(
              label: 'Mở Dashboard',
              icon: Icons.arrow_forward,
              onPressed: () => Navigator.pushNamed(context, AppRoutes.home),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(
                context,
                AppRoutes.onboardingBasicInfo,
                arguments: context.read<PlanProvider>().editableProfile,
              ),
              child: const Text('Tạo kế hoạch khác'),
            ),
          ],
        ),
      ),
    ),
  );
}
