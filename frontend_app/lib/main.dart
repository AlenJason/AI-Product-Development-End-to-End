import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/api_config.dart';
import 'models/api/profile.dart';
import 'providers/auth_provider.dart';
import 'providers/grocery_provider.dart';
import 'providers/history_provider.dart';
import 'providers/plan_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/grocery_screen.dart';
import 'screens/history_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/api_client.dart';
import 'services/api_exception.dart';
import 'services/google_auth.dart';
import 'theme/app_colors.dart';
import 'widgets/app_frame.dart';
import 'widgets/feedback_sheet.dart';
import 'widgets/login_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Vẽ dưới thanh trạng thái (màn hình dùng SafeArea) — không còn dải đen trên nền sáng.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Đọc hết dữ liệu đã lưu một lần trước khi vẽ màn đầu — MainShell biết ngay có plan hay chưa, không cần màn chờ.
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: resolveApiBaseUrl());
  final auth = AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth());
  final plans = PlanProvider(api: api, prefs: prefs);
  runApp(
    SmartFitApp(
      auth: auth,
      plans: plans,
      grocery: GroceryProvider(prefs: prefs, plans: plans),
      history: HistoryProvider(api: api, auth: auth),
    ),
  );
}

class SmartFitApp extends StatelessWidget {
  const SmartFitApp({super.key, required this.auth, required this.plans, required this.grocery, required this.history});

  final AuthProvider auth;
  final PlanProvider plans;
  final GroceryProvider grocery;
  final HistoryProvider history;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: plans),
        ChangeNotifierProvider.value(value: grocery),
        ChangeNotifierProvider.value(value: history),
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
          // Lưu tạm bước Onboarding, dữ liệu đang nhập, tab đang mở khi hệ thống tắt app ở nền (PLAN D8).
          restorationScopeId: 'smartfit',
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00875A),
              primary: const Color(0xFF00875A),
              surface: const Color(0xFFF8F9FA),
            ),
          ),
          builder: (context, child) => AppFrame(child: child ?? const SizedBox.shrink()),
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver, RestorationMixin {
  // Chưa có plan → bắt đầu từ Onboarding; đã có plan đã lưu → vào thẳng màn chính, không cần mạng (NFR-2).
  late AppScreen _screen = context.read<PlanProvider>().hasPlan ? AppScreen.home : AppScreen.onboarding;
  final _tab = RestorableInt(0); // 0: Kế hoạch, 1: Đi chợ, 2: Lịch sử, 3: Cá nhân — lưu tạm như form (PLAN D8)
  // Hồ sơ của lần tạo plan gần nhất — để thử lại hoặc sửa khi lỗi.
  Profile? _requested;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  String get restorationId => 'shell';

  // Bảng feedback cuối ngày (giai đoạn 7) mở từ đây, không từ Dashboard: feedback ngày 3 trả plan mới làm Dashboard
  // dựng lại (khoá theo plan_id). Route khôi phục được (#35). Bảng trả true → plan đã cũ (409), tạo plan mới.
  late final _feedbackRoute = RestorableRouteFuture<bool?>(
    onPresent: (navigator, arguments) => navigator.restorablePush(feedbackSheetRoute, arguments: arguments),
    onComplete: (createPlan) {
      final profile = context.read<PlanProvider>().editableProfile;
      if (createPlan == true && profile != null) _createPlan(profile);
    },
  );

  // Bảng đăng nhập (giai đoạn 8) từ tab Cá nhân, Lịch sử, lỗi 401. Tạo plan bị 401 (phiên hết hạn) → đăng nhập
  // xong thì tạo tiếp, để plan vào lịch sử.
  late final _loginRoute = RestorableRouteFuture<bool?>(
    onPresent: (navigator, arguments) => navigator.restorablePush(loginSheetRoute),
    onComplete: (signedIn) {
      final requested = _requested;
      if (signedIn == true && _screen == AppScreen.loading && _error is UnauthorizedException && requested != null) {
        _generate(requested);
      }
    },
  );

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_tab, 'tab');
    registerForRestoration(_feedbackRoute, 'feedback_sheet');
    registerForRestoration(_loginRoute, 'login_sheet');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tab.dispose();
    _feedbackRoute.dispose();
    _loginRoute.dispose();
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
          _tab.value = 0;
        });
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  // Tạo plan mới thay plan đang có. Khách không có lịch sử nên plan cũ mất hẳn → hỏi trước (quyết định Q5 giai đoạn 8).
  Future<void> _createPlan(Profile profile) async {
    if (!context.read<AuthProvider>().isSignedIn && context.read<PlanProvider>().hasPlan) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thay kế hoạch hiện tại?'),
          content: const Text(
            'Bạn đang dùng không đăng nhập nên kế hoạch hiện tại sẽ bị thay và không xem lại được. '
            'Đăng nhập để kế hoạch mới được lưu vào lịch sử.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Thay kế hoạch')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    await _generate(profile);
  }

  @override
  Widget build(BuildContext context) {
    final plans = context.watch<PlanProvider>();
    final auth = context.watch<AuthProvider>();
    final screen = _screen == AppScreen.home && !plans.hasPlan ? AppScreen.onboarding : _screen;
    // Màn chào chỉ trước Onboarding của lần đầu (FR-6.1); đăng nhập hoặc "Dùng ngay" → Onboarding.
    if (screen == AppScreen.onboarding && auth.showWelcome) return WelcomeScreen(onSkip: auth.skipWelcome);
    return switch (screen) {
      AppScreen.onboarding => OnboardingScreen(initial: _requested ?? plans.editableProfile, onSubmit: _generate),
      AppScreen.loading => LoadingScreen(
        error: _error,
        onRetry: () => _generate(_requested!),
        onEditProfile: () => setState(() => _screen = AppScreen.onboarding),
        onBack: plans.hasPlan ? () => setState(() => _screen = AppScreen.home) : null,
        onSignIn: _loginRoute.present,
      ),
      AppScreen.home => _home(plans),
    };
  }

  Widget _home(PlanProvider plans) => Scaffold(
    body: switch (_tab.value) {
      // Khoá theo plan_id: plan mới thì Dashboard mở lại đúng ngày hôm nay.
      0 => DashboardScreen(
        key: ValueKey(plans.plan?.planId),
        onCreatePlan: () => _createPlan(plans.editableProfile!),
        onFeedback: (day) => _feedbackRoute.present(day),
        onSignIn: _loginRoute.present,
      ),
      1 => const GroceryScreen(),
      2 => HistoryScreen(onSignIn: _loginRoute.present),
      _ => ProfileScreen(onCreatePlan: _createPlan, onSignIn: _loginRoute.present),
    },
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 0.8)),
      ),
      child: BottomNavigationBar(
        currentIndex: _tab.value,
        onTap: (index) => setState(() => _tab.value = index),
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
}
