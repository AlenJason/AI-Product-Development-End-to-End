import 'screens/feedback/daily_feedback_screen.dart';
import 'screens/settings/system_states_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'core/constants/routes.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/onboarding/basic_info_screen.dart';
import 'screens/onboarding/activity_screen.dart';
import 'screens/onboarding/goal_screen.dart';
import 'screens/onboarding/restrictions_screen.dart';
import 'screens/onboarding/generating_plan_screen.dart';
import 'screens/main_screen.dart';
import 'screens/meal/meal_detail_screen.dart';
import 'screens/workout/workout_detail_screen.dart';

Route<dynamic> appGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.welcome:
    case AppRoutes.login:
      return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    case AppRoutes.onboardingBasicInfo:
      return MaterialPageRoute(builder: (_) => const BasicInfoScreen());
    case AppRoutes.onboardingActivity:
      return MaterialPageRoute(builder: (_) => const ActivityScreen());
    case AppRoutes.onboardingGoal:
      return MaterialPageRoute(builder: (_) => const GoalScreen());
    case AppRoutes.onboardingRestrictions:
      return MaterialPageRoute(builder: (_) => const RestrictionsScreen());
    case AppRoutes.generatingPlan:
      return MaterialPageRoute(builder: (_) => const GeneratingPlanScreen());
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const MainScreen());
    case '/meal_detail':
      return MaterialPageRoute(builder: (_) => const MealDetailScreen());
    case '/workout_detail':
      return MaterialPageRoute(builder: (_) => const WorkoutDetailScreen());
    case '/daily_feedback':
      return MaterialPageRoute(builder: (_) => const DailyFeedbackScreen());
    case '/system_states':
      return MaterialPageRoute(builder: (_) => const SystemStatesScreen());
    case '/settings':
      return MaterialPageRoute(builder: (_) => const SettingsScreen());
    default:
      return MaterialPageRoute(
        builder: (_) => Scaffold(
          body: Center(child: Text('Route ${settings.name} not found')),
        ),
      );
  }
}








