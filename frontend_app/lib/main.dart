import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/grocery_screen.dart';
import 'services/api_client.dart';
import 'widgets/feedback_bottom_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Đọc hết dữ liệu đã lưu một lần trước khi vẽ màn đầu — MainShell biết ngay có plan hay chưa, không cần màn chờ.
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: resolveApiBaseUrl());
  runApp(SmartFitApp(
    auth: AuthProvider(api: api, prefs: prefs),
    plans: PlanProvider(api: api, prefs: prefs),
  ));
}

enum AppScreen { onboarding, loading, dashboard, grocery }

class SmartFitApp extends StatelessWidget {
  const SmartFitApp({super.key, required this.auth, required this.plans});

  final AuthProvider auth;
  final PlanProvider plans;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: plans),
      ],
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
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Chưa có plan → bắt đầu từ Onboarding; đã có plan đã lưu → vào thẳng Dashboard, không cần mạng (NFR-2).
  late AppScreen _currentScreen =
      context.read<PlanProvider>().hasPlan ? AppScreen.dashboard : AppScreen.onboarding;
  int _currentBottomNavIndex = 0; // 0: Kế hoạch, 1: Đi chợ, 2: Thống kê, 3: Cá nhân

  void _openFeedbackModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FeedbackBottomSheet(
        onClose: () => Navigator.pop(ctx),
        onSubmitted: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã ghi nhận phản hồi. AI đã cân đối lại thực đơn Ngày 2!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Color(0xFF059669),
            ),
          );
        },
      ),
    );
  }

  void _setScreen(AppScreen screen) {
    setState(() {
      _currentScreen = screen;
      if (screen == AppScreen.dashboard) {
        _currentBottomNavIndex = 0;
      } else if (screen == AppScreen.grocery) {
        _currentBottomNavIndex = 1;
      }
    });
  }

  Widget _buildBody() {
    switch (_currentScreen) {
      case AppScreen.onboarding:
        return OnboardingScreen(
          onNext: () => _setScreen(AppScreen.loading),
        );
      case AppScreen.loading:
        return LoadingScreen(
          onDone: () => _setScreen(AppScreen.dashboard),
        );
      case AppScreen.dashboard:
        if (_currentBottomNavIndex == 1) {
          return const GroceryScreen();
        }
        if (_currentBottomNavIndex == 2) {
          return _buildPlaceholderScreen(
            icon: Icons.bar_chart_rounded,
            title: 'Thống kê dinh dưỡng 3 ngày',
            subtitle: 'Theo dõi lượng Calo tiêu thụ thực tế và độ lệch so với mục tiêu 1.850 kcal.',
          );
        }
        if (_currentBottomNavIndex == 3) {
          return _buildPlaceholderScreen(
            icon: Icons.person_outline_rounded,
            title: 'Hồ sơ người dùng',
            subtitle: '168 cm • 62 kg • Mục tiêu: Giảm mỡ & Giữ cơ.',
          );
        }
        return DashboardScreen(
          onOpenFeedback: _openFeedbackModal,
        );
      case AppScreen.grocery:
        return const GroceryScreen();
    }
  }

  Widget _buildPlaceholderScreen({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBottomBar = _currentScreen == AppScreen.dashboard || _currentScreen == AppScreen.grocery;

    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: showBottomBar
          ? Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentBottomNavIndex,
                onTap: (index) {
                  setState(() {
                    _currentBottomNavIndex = index;
                    _currentScreen = AppScreen.dashboard;
                  });
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: const Color(0xFF00875A),
                unselectedItemColor: const Color(0xFF94A3B8),
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
                    icon: Icon(Icons.bar_chart_outlined),
                    activeIcon: Icon(Icons.bar_chart),
                    label: 'Thống kê',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Cá nhân',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
