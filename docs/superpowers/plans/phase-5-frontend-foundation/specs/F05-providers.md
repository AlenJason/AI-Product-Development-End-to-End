# F05 — `PlanProvider` và `AuthProvider` (PLAN 5.5)

## Feature

Hai `ChangeNotifier` (package `provider`, đúng BRD mục 4), lưu trên máy bằng `shared_preferences` (quyết định Q3; trên web là `localStorage`).

**`PlanProvider`** — plan hiện tại và hồ sơ đã tạo ra nó. Cả hai lưu trên máy để mở lại app vẫn xem được plan khi không có mạng (NFR-2). Hồ sơ gồm cả `restrictions` — dữ liệu sức khoẻ chỉ nằm trên máy người dùng (NFR-7, D4).

| Khoá `shared_preferences` | Nội dung |
|---|---|
| `smartfit.profile.v1` | `Profile.toJson()` |
| `smartfit.plan.v1` | `MealPlan.toJson()` — đúng JSON server trả (vòng tròn, F03) |

Số `v1` trong khoá: đổi hợp đồng theo cách bản cũ không đọc được thì tăng số, bản cũ bị bỏ qua.

| Hàm | Làm gì |
|---|---|
| `generate(profile)` | gọi `generate-plan`, lưu hồ sơ + plan |
| `swapMeal(mealId)`, `swapExercise(exerciseId)` | gửi hồ sơ + plan đang có, thay bằng plan server trả |
| `submitFeedback(answers)` | như trên; trả `FeedbackResult` (có `safetyWarning`) để giao diện hiện cảnh báo nổi bật |
| `clearPlan()` | bỏ plan, giữ hồ sơ để điền sẵn form |

- Lỗi → ném `ApiException`, plan đang có giữ nguyên.
- `busy` = đang chờ server; giao diện khoá nút. Gọi thêm khi đang bận → **bỏ qua**, không gọi server, không ném lỗi (không crash khi bấm hai lần — NFR-2); `submitFeedback` trả `null` trong trường hợp này.
- **Bản lưu hỏng** (sửa tay, hợp đồng cũ): plan hỏng → xoá plan, giữ hồ sơ; hồ sơ hỏng → xoá cả plan, vì plan không có hồ sơ đi kèm thì không đổi món/feedback được (server cần `profile`).

**`AuthProvider`** — đăng nhập (FR-6). Không đăng nhập vẫn dùng đủ tính năng như khách.

| Khoá | Nội dung |
|---|---|
| `smartfit.access_token` | JWT của backend (7 ngày) |
| `smartfit.user.v1` | `AuthUser.toJson()` |

- `signIn(idToken)` — Google ID token (giai đoạn 8) hoặc `mock:<email>` khi backend ở chế độ giả lập; đặt `ApiClient.accessToken`.
- `signOut()`; `deleteAccount()` = `DELETE /api/v1/me` rồi đăng xuất. Plan đang mở trên máy giữ nguyên (dùng tiếp như khách).
- Đăng ký `ApiClient.onUnauthorized`: server trả 401 cho request có token (hết hạn, tài khoản đã xoá) → đăng xuất.
- Chỉ có token hoặc chỉ có user, hay user hỏng → coi như chưa đăng nhập, xoá cả hai.

## Scope

UI-only (state + test):

- `frontend_app/lib/providers/plan_provider.dart`, `auth_provider.dart` (mới)
- `frontend_app/test/fake_backend.dart` (mới — backend giả trả fixture theo đường dẫn, dùng lại ở F06 và giai đoạn 6.6)
- `frontend_app/test/providers/plan_provider_test.dart`, `auth_provider_test.dart` (mới)

## Implementation

### API Routes

Không thêm. Độ trễ và timeout như F04.

**Token:** JWT lưu ở `shared_preferences` như BRD mục 4 (Q3). Không lưu ID Token Google (#10). Hết hạn → 401 → đăng xuất tự động.

### UI Components

Không có — `MainShell` đọc `PlanProvider.hasPlan` ở F06; màn hình dùng provider từ giai đoạn 6.

### DB / KV Changes

Khoá `shared_preferences` ở bảng trên. Không có migration: đổi định dạng → tăng số phiên bản của khoá.

Constructor dùng tham số có tên riêng tư (`required this._api`, Dart 3.13) — nơi gọi vẫn viết `api:`, `prefs:`; `flutter_lints` gợi ý cách này (`prefer_initializing_formals`).

### Ràng buộc áp dụng

- **#10** chỉ lưu JWT của backend.
- **#12** hồ sơ/`restrictions` chỉ nằm trên máy; không in ra log.
- **#22** 401 → đăng xuất, dùng tiếp như khách.
- **#24** gửi lại plan đúng như đã lưu.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test test/providers` → `All tests passed!` (14 test)
- [ ] Tạo plan → khoá `smartfit.plan.v1` chứa đúng JSON fixture; provider mới tạo lại từ cùng `SharedPreferences` đọc được đúng plan
- [ ] Bản lưu hỏng không làm crash, bị xoá

## Test Checklist

1. **@happy**: tạo plan → lưu cả hai khoá → mở lại đọc đúng; đổi món, đổi bài, feedback thay plan và gửi đúng plan đang có
2. **@auth**: đăng nhập → token gắn vào request sau và được lưu; mở lại app đọc token; xoá tài khoản → `DELETE /api/v1/me` + đăng xuất
3. **@token**: server 401 khi có token → đăng xuất, xoá khoá, `accessToken` = null; đăng nhập lại thất bại khi đang đăng nhập → giữ phiên cũ
4. **@partial-fail**: 409 → ném `PlanOutdatedException`, plan cũ giữ nguyên, `busy` về `false`
5. **@busy**: đang chờ server → `busy`; gọi thêm bị bỏ qua (chỉ 1 request), trạng thái báo `[true, false]`
6. **@db**: plan hỏng → xoá plan giữ hồ sơ; hồ sơ hỏng → xoá hết; token không có user → xoá hết
7. **@timeout**: như F04

## Tasks

### Task 1 — `PlanProvider`

`frontend_app/lib/providers/plan_provider.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../models/api/profile.dart';
import '../services/api_client.dart';

// Plan hiện tại và hồ sơ đã tạo ra nó. Cả hai lưu trên máy (shared_preferences; web: localStorage) để mở lại app
// vẫn xem được plan khi không có mạng (NFR-2). Hồ sơ gồm cả `restrictions` — dữ liệu sức khoẻ chỉ nằm trên máy
// người dùng (NFR-7, D4). Đổi món/bài/feedback gửi đúng cặp này lên server (BRD 6.4).
class PlanProvider extends ChangeNotifier {
  PlanProvider({required this._api, required this._prefs}) {
    _restore();
  }

  // Đổi hợp đồng plan theo cách bản cũ không đọc được → tăng số phiên bản của khoá.
  static const planKey = 'smartfit.plan.v1';
  static const profileKey = 'smartfit.profile.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;

  Profile? _profile;
  MealPlan? _plan;
  bool _busy = false;

  Profile? get profile => _profile;
  MealPlan? get plan => _plan;
  bool get hasPlan => _plan != null;
  // Đang chờ server — UI khoá các nút tạo/đổi/feedback.
  bool get busy => _busy;

  // Mọi hàm gọi server: lỗi → ApiException (plan đang có giữ nguyên); đang bận → bỏ qua, không gọi server.
  Future<void> generate(Profile profile) => _run(() async => _save(profile, await _api.generatePlan(profile)));

  Future<void> swapMeal(String mealId) => _run(() async {
        final (profile, plan) = _current();
        await _save(profile, await _api.swapMeal(profile, plan, mealId));
      });

  Future<void> swapExercise(String exerciseId) => _run(() async {
        final (profile, plan) = _current();
        await _save(profile, await _api.swapExercise(profile, plan, exerciseId));
      });

  // null khi đang bận. `safetyWarning` khác null → UI hiện cảnh báo nổi bật (BRD 6.4, dấu hiệu nguy hiểm).
  Future<FeedbackResult?> submitFeedback(FeedbackAnswers answers) => _run(() async {
        final (profile, plan) = _current();
        final result = await _api.submitFeedback(profile, plan, answers);
        await _save(profile, result.plan);
        return result;
      });

  // Bỏ plan đang có (giữ hồ sơ để điền sẵn form).
  Future<void> clearPlan() async {
    _plan = null;
    notifyListeners();
    await _prefs.remove(planKey);
  }

  Future<T?> _run<T>(Future<T> Function() task) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  (Profile, MealPlan) _current() {
    final profile = _profile;
    final plan = _plan;
    if (profile == null || plan == null) throw StateError('Chưa có plan — gọi generate() trước');
    return (profile, plan);
  }

  Future<void> _save(Profile profile, MealPlan plan) async {
    _profile = profile;
    _plan = plan;
    await _prefs.setString(profileKey, jsonEncode(profile.toJson()));
    await _prefs.setString(planKey, jsonEncode(plan.toJson()));
  }

  // Bản lưu hỏng hoặc của hợp đồng cũ → xoá, không crash. Plan không có hồ sơ đi kèm thì không đổi món/feedback
  // được, nên hồ sơ hỏng kéo theo xoá plan; plan hỏng thì hồ sơ vẫn giữ.
  void _restore() {
    _profile = _read(profileKey, Profile.fromJson);
    _plan = _profile == null ? null : _read(planKey, MealPlan.fromJson);
    if (_profile == null && _prefs.containsKey(planKey)) unawaited(_prefs.remove(planKey));
  }

  T? _read<T>(String key, T Function(Json json) parse) {
    final text = _prefs.getString(key);
    if (text == null) return null;
    try {
      return parse(readMap(jsonDecode(text), key));
    } on FormatException {
      unawaited(_prefs.remove(key));
      return null;
    }
  }
}
```

### Task 2 — `AuthProvider`

`frontend_app/lib/providers/auth_provider.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../services/api_client.dart';

// Đăng nhập (BRD FR-6, 6.3). Không đăng nhập vẫn dùng đủ tính năng như khách; đăng nhập để có lịch sử plan.
// JWT (7 ngày) lưu trong shared_preferences như BRD mục 4 — trên web là localStorage.
class AuthProvider extends ChangeNotifier {
  AuthProvider({required this._api, required this._prefs}) {
    _restore();
    // Token hết hạn hoặc tài khoản đã xoá → server trả 401 → về chế độ khách.
    _api.onUnauthorized = () => unawaited(signOut());
  }

  static const tokenKey = 'smartfit.access_token';
  static const userKey = 'smartfit.user.v1';

  final ApiClient _api;
  final SharedPreferences _prefs;

  AuthUser? _user;

  AuthUser? get user => _user;
  bool get isSignedIn => _user != null;

  // `idToken`: Google ID token (giai đoạn 8), hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
  Future<void> signIn(String idToken) async {
    final result = await _api.loginWithGoogle(idToken);
    _api.accessToken = result.accessToken;
    _user = result.user;
    notifyListeners();
    await _prefs.setString(tokenKey, result.accessToken);
    await _prefs.setString(userKey, jsonEncode(result.user.toJson()));
  }

  Future<void> signOut() async {
    _api.accessToken = null;
    _user = null;
    notifyListeners();
    await _prefs.remove(tokenKey);
    await _prefs.remove(userKey);
  }

  // Xoá tài khoản và toàn bộ lịch sử trên server (FR-6). Plan đang mở trên máy giữ nguyên, dùng tiếp như khách.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await signOut();
  }

  void _restore() {
    final token = _prefs.getString(tokenKey);
    final userText = _prefs.getString(userKey);
    if (token != null && userText != null) {
      try {
        _user = AuthUser.fromJson(readMap(jsonDecode(userText), userKey));
        _api.accessToken = token;
        return;
      } on FormatException {
        // bản lưu hỏng → xoá bên dưới
      }
    }
    unawaited(_prefs.remove(tokenKey));
    unawaited(_prefs.remove(userKey));
  }
}
```

### Task 3 — Backend giả cho test

`frontend_app/test/fake_backend.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ai_app/services/api_client.dart';

import 'fixture_loader.dart';

// Backend giả cho test provider/widget: trả fixture hợp đồng theo đường dẫn, ghi lại request đã nhận.
// `failWith` đặt mã lỗi (và fixture error_<mã>) cho mọi request tiếp theo; `hold` giữ response tới khi complete.
class FakeBackend {
  final requests = <http.Request>[];
  int? failWith;
  Completer<void>? hold;

  static const _fixtureFor = {
    '/health': 'health',
    '/api/v1/generate-plan': 'generate_plan',
    '/api/v1/meals/swap': 'meals_swap',
    '/api/v1/exercises/swap': 'exercises_swap',
    '/api/v1/feedback': 'feedback',
    '/api/v1/auth/google': 'auth_login',
    '/api/v1/plans/history': 'history',
  };

  late final ApiClient api = ApiClient(
    baseUrl: 'http://api.test',
    httpClient: MockClient((request) async {
      requests.add(request);
      await hold?.future;
      final status = failWith;
      if (status != null) return _json(loadFixture('error_$status'), status);
      if (request.method == 'DELETE') return http.Response('', 204);
      final name = _fixtureFor[request.url.path];
      if (name == null) return _json({'statusCode': 404, 'message': 'Cannot ${request.method} ${request.url.path}'}, 404);
      return _json(loadFixture(name), 200);
    }),
  );

  List<String> get paths => requests.map((request) => request.url.path).toList();

  static http.Response _json(Object body, int status) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});
}
```

### Task 4 — Test

`frontend_app/test/providers/plan_provider_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/plan_provider.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final profile = Profile.fromJson(loadFixture('profile'));
  final saved = {
    PlanProvider.profileKey: jsonEncode(loadFixture('profile')),
    PlanProvider.planKey: jsonEncode(loadFixture('generate_plan')),
  };

  Future<(PlanProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    return (PlanProvider(api: backend.api, prefs: prefs), backend, prefs);
  }

  test('máy chưa có gì → chưa có plan', () async {
    final (provider, _, _) = await create();
    expect(provider.hasPlan, isFalse);
    expect(provider.profile, isNull);
  });

  test('tạo plan → giữ trong bộ nhớ và lưu cả plan lẫn hồ sơ; mở lại app đọc được đúng như cũ', () async {
    final (provider, backend, prefs) = await create();
    await provider.generate(profile);

    expect(backend.paths, ['/api/v1/generate-plan']);
    expect(provider.plan!.toJson(), loadFixture('generate_plan'));
    expect(jsonDecode(prefs.getString(PlanProvider.planKey)!), loadFixture('generate_plan'));
    expect(jsonDecode(prefs.getString(PlanProvider.profileKey)!), loadFixture('profile'));

    final reopened = PlanProvider(api: backend.api, prefs: prefs);
    expect(reopened.plan!.toJson(), loadFixture('generate_plan'));
    expect(reopened.profile!.toJson(), loadFixture('profile'));
  });

  test('đổi món, đổi bài, feedback gửi plan đang có và thay bằng plan server trả', () async {
    final (provider, backend, prefs) = await create(saved);

    await provider.swapMeal('m1_2');
    expect(provider.plan!.toJson(), loadFixture('meals_swap')['plan']);
    expect(jsonDecode(prefs.getString(PlanProvider.planKey)!), loadFixture('meals_swap')['plan']);

    await provider.swapExercise('e1_2');
    expect(provider.plan!.toJson(), loadFixture('exercises_swap')['plan']);

    final result = await provider.submitFeedback(const FeedbackAnswers(
        dayNumber: 1, intensity: Intensity.hard, bodyStates: {BodyState.sore}, eating: Eating.onPlan));
    expect(result!.safetyWarning, isNull);
    expect(provider.plan!.toJson(), loadFixture('feedback')['plan']);

    expect(backend.paths, ['/api/v1/meals/swap', '/api/v1/exercises/swap', '/api/v1/feedback']);
    final lastBody = jsonDecode(utf8.decode(backend.requests.last.bodyBytes)) as Map<String, dynamic>;
    expect(lastBody['plan'], loadFixture('exercises_swap')['plan']);
    expect(lastBody['profile'], loadFixture('profile'));
  });

  test('server báo lỗi → ném ApiException, plan cũ giữ nguyên, hết trạng thái bận', () async {
    final (provider, backend, _) = await create(saved);
    backend.failWith = 409;

    await expectLater(provider.swapMeal('m1_2'), throwsA(isA<PlanOutdatedException>()));
    expect(provider.plan!.toJson(), loadFixture('generate_plan'));
    expect(provider.busy, isFalse);
  });

  test('đang chờ server → bận; bấm lần hai bị bỏ qua, không gọi server lần nữa', () async {
    final (provider, backend, _) = await create(saved);
    backend.hold = Completer<void>();
    final states = <bool>[];
    provider.addListener(() => states.add(provider.busy));

    final first = provider.swapMeal('m1_2');
    expect(provider.busy, isTrue);
    await provider.swapMeal('m1_3');
    expect(await provider.submitFeedback(const FeedbackAnswers(
        dayNumber: 1, intensity: Intensity.easy, bodyStates: {}, eating: Eating.onPlan)), isNull);

    backend.hold!.complete();
    await first;
    expect(backend.paths, ['/api/v1/meals/swap']);
    expect(states, [true, false]);
  });

  group('bản lưu hỏng → bỏ đi, không crash', () {
    test('plan hỏng → xoá plan, giữ hồ sơ', () async {
      final (provider, _, prefs) = await create({...saved, PlanProvider.planKey: '{"plan_id": 1}'});
      expect(provider.hasPlan, isFalse);
      expect(provider.profile!.toJson(), loadFixture('profile'));
      expect(prefs.containsKey(PlanProvider.planKey), isFalse);
    });

    test('hồ sơ hỏng → xoá cả plan (không có hồ sơ thì không đổi món/feedback được)', () async {
      final (provider, _, prefs) = await create({...saved, PlanProvider.profileKey: 'không phải JSON'});
      expect(provider.hasPlan, isFalse);
      expect(provider.profile, isNull);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  test('clearPlan bỏ plan, giữ hồ sơ để điền sẵn form', () async {
    final (provider, _, prefs) = await create(saved);
    await provider.clearPlan();
    expect(provider.hasPlan, isFalse);
    expect(provider.profile, isNotNull);
    expect(prefs.getKeys(), {PlanProvider.profileKey});
  });
}
```

`frontend_app/test/providers/auth_provider_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/providers/auth_provider.dart';
import 'package:my_ai_app/services/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_backend.dart';
import '../fixture_loader.dart';

void main() {
  final login = loadFixture('auth_login');
  final saved = {
    AuthProvider.tokenKey: login['access_token'] as String,
    AuthProvider.userKey: jsonEncode(login['user']),
  };

  Future<(AuthProvider, FakeBackend, SharedPreferences)> create([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final backend = FakeBackend();
    return (AuthProvider(api: backend.api, prefs: prefs), backend, prefs);
  }

  test('đăng nhập → token gắn vào mọi request sau, lưu lại cho lần mở app sau', () async {
    final (auth, backend, prefs) = await create();
    await auth.signIn('mock:lan@example.com');

    expect(auth.isSignedIn, isTrue);
    expect(auth.user!.email, (login['user'] as Map)['email']);
    expect(backend.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(prefs.getString(AuthProvider.tokenKey), login['access_token']);

    await backend.api.history();
    expect(backend.requests.last.headers['Authorization'], 'Bearer ${login['access_token']}');
  });

  test('mở lại app → đọc token đã lưu', () async {
    final (auth, backend, _) = await create(saved);
    expect(auth.isSignedIn, isTrue);
    expect(backend.api.accessToken, login['access_token']);
  });

  test('server trả 401 (token hết hạn) → đăng xuất, xoá token, request sau đi như khách', () async {
    final (auth, backend, prefs) = await create(saved);
    backend.failWith = 401;
    await expectLater(backend.api.generatePlan(Profile.fromJson(loadFixture('profile'))),
        throwsA(isA<UnauthorizedException>()));

    expect(auth.isSignedIn, isFalse);
    expect(backend.api.accessToken, isNull);
    await pumpEventQueue();
    expect(prefs.getKeys(), isEmpty);
  });

  test('đăng nhập hỏng (id_token sai) khi đang đăng nhập → vẫn giữ phiên cũ', () async {
    final (auth, backend, _) = await create(saved);
    backend.failWith = 401;
    await expectLater(auth.signIn('mock:'), throwsA(isA<UnauthorizedException>()));
    expect(auth.isSignedIn, isTrue);
  });

  test('xoá tài khoản → DELETE /api/v1/me rồi đăng xuất', () async {
    final (auth, backend, prefs) = await create(saved);
    await auth.deleteAccount();

    expect(backend.requests.single.method, 'DELETE');
    expect(backend.paths, ['/api/v1/me']);
    expect(auth.isSignedIn, isFalse);
    expect(prefs.getKeys(), isEmpty);
  });

  test('bản lưu hỏng hoặc thiếu một nửa → coi như chưa đăng nhập, xoá sạch', () async {
    final (broken, _, brokenPrefs) = await create({...saved, AuthProvider.userKey: '[]'});
    expect(broken.isSignedIn, isFalse);
    expect(brokenPrefs.getKeys(), isEmpty);

    final (half, halfBackend, halfPrefs) = await create({AuthProvider.tokenKey: 'abc'});
    expect(half.isSignedIn, isFalse);
    expect(halfBackend.api.accessToken, isNull);
    expect(halfPrefs.getKeys(), isEmpty);
  });
}
```

### Task 5 — Cổng kiểm tra F05

```bash
cd frontend_app
flutter analyze               # No issues found!
flutter test test/providers   # +14: All tests passed!
```
