import 'package:flutter/material.dart';

import '../../widgets/swap_action.dart';

class MealSwapSheet extends StatelessWidget {
  const MealSwapSheet({super.key, required this.mealId});
  final String mealId;
  @override
  Widget build(BuildContext context) => SwapAction(id: mealId, meal: true);
}
