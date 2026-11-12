import 'screens/feedback/daily_feedback_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/system_states_screen.dart';
import 'screens/settings/settings_screen.dart';

import 'package:flutter/material.dart';

import 'core/constants/routes.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/onboarding/basic_info_screen.dart';
import 'screens/onboarding/activity_screen.dart';
import 'screens/onboarding/restrictions_screen.dart';
import 'screens/onboarding/generating_plan_screen.dart';
import 'models/api/profile.dart';
import 'screens/plan/generated_plan_screen.dart';
import 'screens/main_screen.dart';
import 'screens/meal/meal_detail_screen.dart';
import 'screens/workout/workout_detail_screen.dart';

Route<dynamic> appGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.welcome:
    case AppRoutes.login:
      return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    case AppRoutes.onboardingBasicInfo:
      return MaterialPageRoute(
        builder: (_) => BasicInfoScreen(
          initialProfile: settings.arguments is Profile
              ? settings.arguments as Profile
              : null,
        ),
      );
    case AppRoutes.onboardingActivity:
      return MaterialPageRoute(builder: (_) => const ActivityScreen());
    case AppRoutes.onboardingGoal:
      // Giữ route cũ tương thích, nhưng mục tiêu và vận động cùng bước 2.
      return MaterialPageRoute(builder: (_) => const ActivityScreen());
    case AppRoutes.onboardingRestrictions:
      return MaterialPageRoute(builder: (_) => const RestrictionsScreen());
    case AppRoutes.generatingPlan:
      final profile = settings.arguments;
      if (profile is Profile) {
        return MaterialPageRoute(
          builder: (_) => GeneratingPlanScreen(profile: profile),
        );
      }
      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Chưa có hồ sơ để tạo kế hoạch.')),
        ),
      );
    case AppRoutes.threeDayPlan:
      return MaterialPageRoute(builder: (_) => const GeneratedPlanScreen());
    case AppRoutes.home:
      return MaterialPageRoute(builder: (_) => const MainScreen());
    case '/meal_detail':
      return MaterialPageRoute(
        builder: (_) => MealDetailScreen(
          mealId: settings.arguments is String
              ? settings.arguments as String
              : null,
        ),
      );
    case '/workout_detail':
      return MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          exerciseId: settings.arguments is String
              ? settings.arguments as String
              : null,
        ),
      );
    case AppRoutes.dailyFeedback:
    case '/daily_feedback':
      final args = settings.arguments;
      return MaterialPageRoute(
        builder: (_) => DailyFeedbackScreen(
          dayNumber: args is Map ? args['day'] as int? : null,
          planId: args is Map ? args['plan_id'] as String? : null,
        ),
      );
    case '/system_states':
      return MaterialPageRoute(builder: (_) => const SystemStatesScreen());
    case AppRoutes.history:
      return MaterialPageRoute(builder: (_) => const HistoryScreen());
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
