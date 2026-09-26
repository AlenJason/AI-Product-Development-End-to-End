import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'models/api/profile.dart';
import 'providers/auth_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/plan_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/grocery_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'services/api_client.dart';
import 'services/api_exception.dart';
import 'theme/app_colors.dart';

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
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00875A),
              primary: const Color(0xFF00875A),
              surface: const Color(0xFFF8F9FA),
            ),
          ),
          home: const MainShell(),
        ),
      ),
    );
  }
}

enum AppScreen { onboarding, loading, home }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // Chưa có plan → bắt đầu từ Onboarding; đã có plan đã lưu → vào thẳng màn chính, không cần mạng (NFR-2).
  late AppScreen _screen = context.read<PlanProvider>().hasPlan ? AppScreen.home : AppScreen.onboarding;
  int _tab = 0; // 0: Kế hoạch, 1: Đi chợ, 2: Lịch sử, 3: Cá nhân
  // Hồ sơ của lần tạo plan gần nhất — để thử lại hoặc sửa khi lỗi.
  Profile? _requested;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Mở lại app sau nửa đêm → Dashboard tính lại ngày hôm nay của plan (D6-B1).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  Future<void> _generate(Profile profile) async {
    final plans = context.read<PlanProvider>();
    setState(() {
      _screen = AppScreen.loading;
      _requested = profile;
      _error = null;
    });
    try {
      await plans.generate(profile);
      if (mounted) {
        setState(() {
          _screen = AppScreen.home;
          _tab = 0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final screen = _screen == AppScreen.home && !plans.hasPlan ? AppScreen.onboarding : _screen;
    return switch (screen) {
      AppScreen.onboarding => OnboardingScreen(initial: _requested ?? plans.editableProfile, onSubmit: _generate),
      AppScreen.loading => LoadingScreen(
        error: _error,
        onRetry: () => _generate(_requested!),
        onEditProfile: () => setState(() => _screen = AppScreen.onboarding),
        onBack: plans.hasPlan ? () => setState(() => _screen = AppScreen.home) : null,
      ),
      AppScreen.home => _home(plans),
    };
  }

  Widget _home(PlanProvider plans) => Scaffold(
    body: switch (_tab) {
      // Khoá theo plan_id: plan mới thì Dashboard mở lại đúng ngày hôm nay.
      0 => DashboardScreen(key: ValueKey(plans.plan?.planId), onCreatePlan: () => _generate(plans.editableProfile!)),
      1 => const GroceryScreen(),
      2 => _placeholder(
        icon: Icons.history_rounded,
        title: 'Lịch sử kế hoạch',
        subtitle: 'Đăng nhập để xem lại các kế hoạch đã tạo — tính năng sắp có.',
      ),
      _ => ProfileScreen(onCreatePlan: _generate),
    },
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (index) => setState(() => _tab = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00875A),
        unselectedItemColor: AppColors.faint,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: 'Kế hoạch',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Đi chợ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Lịch sử',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
      ),
    ),
  );

  Widget _placeholder({required IconData icon, required String title, required String subtitle}) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 36, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
