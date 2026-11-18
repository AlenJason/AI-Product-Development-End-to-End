import 'package:flutter/material.dart';

import '../../widgets/swap_action.dart';

class WorkoutSwapSheet extends StatelessWidget {
  const WorkoutSwapSheet({super.key, required this.exerciseId});
  final String exerciseId;
  @override
  Widget build(BuildContext context) => SwapAction(id: exerciseId, meal: false);
}
