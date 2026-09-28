import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/mock_data_provider.dart';
import 'services/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/routes.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vẽ dưới thanh trạng thái (màn hình dùng SafeArea) — không còn dải đen trên nền sáng.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Đọc hết dữ liệu đã lưu một lần trước khi vẽ màn đầu — MainShell biết ngay có plan hay chưa, không cần màn chờ.
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: resolveApiBaseUrl());
  final plans = PlanProvider(api: api, prefs: prefs);
  runApp(
    SmartFitApp(
      auth: AuthProvider(api: api, prefs: prefs),
      plans: plans,
      grocery: GroceryProvider(prefs: prefs, plans: plans),
    ),
  );
}

class SmartFitApp extends StatelessWidget {
  const SmartFitApp({super.key, required this.auth, required this.plans, required this.grocery});

  final AuthProvider auth;
  final PlanProvider plans;
  final GroceryProvider grocery;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: plans),
        ChangeNotifierProvider.value(value: grocery),
        ChangeNotifierProvider(create: (_) => OnboardingProvider()),
        ChangeNotifierProvider(create: (_) => MockDataProvider()),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: MaterialApp(
          title: 'SmartFit AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: AppRoutes.welcome, onGenerateRoute: appGenerateRoute,
        ),
      ),
    );
  }
}




