# F06 — `MainShell` mở đúng màn đầu, widget test, CI Flutter (PLAN 5.6, 5.9)

## Feature

- **`main()`** đọc `SharedPreferences.getInstance()` **trước** `runApp` (đọc hết một lần, sau đó đọc đồng bộ), tạo một `ApiClient` dùng chung (`resolveApiBaseUrl()`), rồi `AuthProvider`, `PlanProvider`. Không cần màn chờ như brainstorm dự tính.
- **`SmartFitApp`** nhận hai provider qua constructor (test truyền provider dùng backend giả) và bọc `MaterialApp` bằng `MultiProvider` (`ChangeNotifierProvider.value`).
- **`MainShell`** (5.6): màn đầu = Dashboard nếu `PlanProvider.hasPlan`, ngược lại Onboarding. Mở app không gọi mạng — có plan đã lưu thì vào Dashboard cả khi không có mạng (NFR-2). Trước đây app luôn mở Dashboard với dữ liệu viết cứng.
- Màn hình **vẫn dùng dữ liệu mẫu**: Onboarding → Loading (đếm giờ giả) → Dashboard như cũ. Nối API là giai đoạn 6.
- **`widget_test.dart`** viết lại (test cũ đỏ từ trước — phát hiện F2).
- **CI Flutter (5.9, mới — quyết định Q4):** `.github/workflows/frontend.yml` chạy `flutter pub get`, `flutter analyze`, `flutter test` với Flutter 3.47.5 (ghim đúng bản trên máy dev) khi có thay đổi trong `frontend_app/**`. Không kiểm `dart format`: code hiện có chưa theo định dạng chuẩn ở khổ dòng nào (`dart format` đổi 7–8 file), format lại toàn bộ là việc riêng.

`main.dart` chỉ sửa đúng các chỗ dưới đây — **không** chạy `dart format` trên file này (sẽ gộp dòng ở các widget không liên quan).

## Scope

UI + CI:

- `frontend_app/lib/main.dart` (sửa), `frontend_app/test/widget_test.dart` (viết lại)
- `.github/workflows/frontend.yml` (mới)

## Implementation

### API Routes

Không có.

### UI Components

`SmartFitApp(auth:, plans:)`, `MainShell` (màn đầu theo `PlanProvider`). Không đổi giao diện màn hình nào.

### DB / KV Changes

Không có (đọc các khoá của F05).

### Ràng buộc áp dụng

- **#17** widget test không gọi mạng: `FakeBackend` ghi lại request và test kiểm danh sách rỗng.
- NFR-2: mở app không cần mạng.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test` → `+44: All tests passed!` (2 config + 12 model + 13 ApiClient + 14 provider + 3 widget)
- [ ] `flutter build web` thành công
- [ ] Workflow `Frontend CI` xanh trên GitHub sau khi push

## Test Checklist

1. **@happy**: máy chưa có gì → Onboarding ("Thiết lập mục tiêu 3 ngày"), không request nào
2. **@offline**: có plan + hồ sơ đã lưu → Dashboard, không request nào
3. **@partial-fail**: plan đã lưu hỏng → Onboarding, không crash
4. **@auth**, **@timeout**, **@token**, **@db**: không áp dụng (đã test ở F04, F05)

## Tasks

### Task 1 — `main.dart`

Import — thêm sau `package:flutter/material.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'providers/auth_provider.dart';
import 'providers/plan_provider.dart';
import 'screens/onboarding_screen.dart';
```

và sau `screens/grocery_screen.dart`:

```dart
import 'screens/grocery_screen.dart';
import 'services/api_client.dart';
import 'widgets/feedback_bottom_sheet.dart';
```

`main()` — thay `void main() { runApp(const SmartFitApp()); }` bằng:

```dart
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
```

`SmartFitApp` — constructor nhận provider, `MaterialApp` (giữ nguyên nội dung, thụt vào 2 dấu cách) thành `child` của `MultiProvider`:

```dart
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
```

`_MainShellState` — thay `AppScreen _currentScreen = AppScreen.dashboard;` bằng:

```dart
  // Chưa có plan → bắt đầu từ Onboarding; đã có plan đã lưu → vào thẳng Dashboard, không cần mạng (NFR-2).
  late AppScreen _currentScreen =
      context.read<PlanProvider>().hasPlan ? AppScreen.dashboard : AppScreen.onboarding;
```

(`late` để khởi tạo lúc dùng lần đầu, khi `context` đã có; `context.read` trong khởi tạo `State` là cách `provider` cho phép.)

Kiểm diff chỉ gồm các chỗ trên:

```bash
git diff --stat lib/main.dart    # 1 file changed, 39 insertions(+), 15 deletions(-) — phần lớn do thụt MaterialApp
git diff -w lib/main.dart        # bỏ khoảng trắng: chỉ còn import, main(), SmartFitApp, _currentScreen
```

### Task 2 — Widget test

`frontend_app/test/widget_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/main.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/screens/dashboard_screen.dart';
import 'package:my_ai_app/screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_backend.dart';
import 'fixture_loader.dart';

// Màn đầu tiên theo dữ liệu đã lưu (PLAN 5.6). Không gọi mạng: mở app chỉ đọc shared_preferences.
void main() {
  Future<FakeBackend> pumpApp(WidgetTester tester, Map<String, Object> saved) async {
    SharedPreferences.setMockInitialValues(saved);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    await tester.pumpWidget(SmartFitApp(
      auth: AuthProvider(api: backend.api, prefs: prefs),
      plans: PlanProvider(api: backend.api, prefs: prefs),
    ));
    return backend;
  }

  testWidgets('chưa có plan → mở Onboarding', (tester) async {
    final backend = await pumpApp(tester, {});
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Thiết lập mục tiêu 3 ngày'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('đã có plan đã lưu → mở thẳng Dashboard, không cần mạng', (tester) async {
    final backend = await pumpApp(tester, {
      PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
      PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
    });
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(backend.requests, isEmpty);
  });

  testWidgets('plan đã lưu bị hỏng → Onboarding, không crash', (tester) async {
    await pumpApp(tester, {
      PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
      PlanProvider.planKey: '{"days": "hỏng"}',
    });
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
```

### Task 3 — CI Flutter

`.github/workflows/frontend.yml`:

```yaml
name: Frontend CI

on:
  push:
    paths:
      - 'frontend_app/**'
      - '.github/workflows/frontend.yml'
  pull_request:
    paths:
      - 'frontend_app/**'
      - '.github/workflows/frontend.yml'

permissions:
  contents: read

jobs:
  flutter:
    name: frontend_app (Flutter 3.47.5)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    defaults:
      run:
        working-directory: frontend_app
    steps:
      - uses: actions/checkout@v7
      # Ghim đúng bản Flutter trên máy dev; đổi cả hai nơi cùng lúc.
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.47.5
          cache: true
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
```

### Task 4 — Cổng kiểm tra F06

```bash
cd frontend_app
flutter analyze   # No issues found!
flutter test      # +44: All tests passed!
flutter build web --dart-define=API_BASE_URL=http://localhost:3000   # ✓ Built build/web
```

Sau khi push: tab Actions có hai workflow `Backend CI` (vì fixture và `backend_api/` đổi) và `Frontend CI`, cả hai xanh.
