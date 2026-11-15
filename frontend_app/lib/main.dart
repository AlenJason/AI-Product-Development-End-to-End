import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/plan_provider.dart';
import 'providers/onboarding_provider.dart';
import 'services/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/routes.dart';
import 'routes.dart';
import 'widgets/plan_lifecycle.dart';
import 'widgets/ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vẽ dưới thanh trạng thái (màn hình dùng SafeArea) — không còn dải đen trên nền sáng.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const SmartFitBootstrap());
}

class SmartFitApp extends StatelessWidget {
  const SmartFitApp({
    super.key,
    required this.auth,
    required this.plans,
    required this.grocery,
  });

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
        ChangeNotifierProvider(
          create: (_) {
            final form = OnboardingProvider();
            final profile = plans.editableProfile;
            if (profile != null) form.loadProfile(profile);
            return form;
          },
        ),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PlanLifecycle(
          plans: plans,
          child: MaterialApp(
            title: 'SmartFit AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            builder: (context, child) => ColoredBox(
              color: const Color(0xFFE8EFEB),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: child!,
                ),
              ),
            ),
            initialRoute: plans.hasPlan ? AppRoutes.home : AppRoutes.welcome,
            onGenerateRoute: appGenerateRoute,
          ),
        ),
      ),
    );
  }
}

class SmartFitBootstrap extends StatefulWidget {
  const SmartFitBootstrap({
    super.key,
    this.loadPreferences,
    this.createApi,
    this.now,
  });
  final Future<SharedPreferences> Function()? loadPreferences;
  final ApiClient Function()? createApi;
  final DateTime Function()? now;
  @override
  State<SmartFitBootstrap> createState() => _SmartFitBootstrapState();
}

class _SmartFitBootstrapState extends State<SmartFitBootstrap> {
  bool _loading = true, _inFlight = false;
  ApiClient? _api;
  PlanProvider? _plans;
  AuthProvider? _auth;
  GroceryProvider? _grocery;
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (_inFlight) return;
    _inFlight = true;
    setState(() => _loading = true);
    try {
      final prefs =
          await (widget.loadPreferences ?? SharedPreferences.getInstance)();
      if (!mounted) return;
      _api =
          (widget.createApi ?? () => ApiClient(baseUrl: resolveApiBaseUrl()))();
      _plans = PlanProvider(api: _api!, prefs: prefs, now: widget.now);
      await _plans!.finishRestore();
      if (!mounted) return;
      _auth = AuthProvider(api: _api!, prefs: prefs);
      _grocery = GroceryProvider(prefs: prefs, plans: _plans!);
    } catch (_) {
      _grocery?.dispose();
      _grocery = null;
      _auth?.dispose();
      _auth = null;
      _plans?.dispose();
      _plans = null;
      _api?.close();
      _api = null;
    } finally {
      _inFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _grocery?.dispose();
    _auth?.dispose();
    _plans?.dispose();
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _plans != null && _auth != null && _grocery != null) {
      return SmartFitApp(auth: _auth!, plans: _plans!, grocery: _grocery!);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(),
                  const SizedBox(height: 28),
                  if (_loading) ...[
                    const CircularProgressIndicator(
                      key: Key('startup-loading'),
                    ),
                    const SizedBox(height: 18),
                    const Text('Đang khôi phục kế hoạch đã lưu…'),
                  ] else ...[
                    const NoticePanel(
                      message: 'Không đọc được dữ liệu trên máy. Dữ liệu đã lưu chưa bị thay đổi. Vui lòng thử lại.',
                      error: true,
                    ),
                    const SizedBox(height: 18),
                    GradientButton(label: 'Thử lại', onPressed: _start),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
