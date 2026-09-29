# F04 — `ApiClient`: gọi mọi endpoint, lỗi thành thông báo dễ hiểu (PLAN 5.4)

## Feature

`ApiClient` (`lib/services/api_client.dart`) gọi 9 endpoint của backend. Nhận `http.Client` qua constructor — test thay bằng `MockClient` của `package:http/testing`, không cần backend chạy.

| Hàm | Endpoint | Timeout |
|---|---|---|
| `health()` | `GET /health` | 15 s |
| `generatePlan(profile)` | `POST /api/v1/generate-plan` | **60 s** |
| `swapMeal(profile, plan, mealId)` | `POST /api/v1/meals/swap` | **60 s** |
| `swapExercise(profile, plan, exerciseId)` | `POST /api/v1/exercises/swap` | **60 s** |
| `submitFeedback(profile, plan, answers)` | `POST /api/v1/feedback` (câu trả lời cùng cấp với `profile`, `plan`) | **60 s** |
| `loginWithGoogle(idToken)` | `POST /api/v1/auth/google` — **không** gửi token cũ | 15 s |
| `deleteAccount()` | `DELETE /api/v1/me` (204) | 15 s |
| `history()` | `GET /api/v1/plans/history` | 15 s |
| `historyPlan(id)` | `GET /api/v1/plans/history/:id` | 15 s |

**60 s** vì mọi request có thể gọi Gemini: backend tự dừng sau `GEMINI_TOTAL_TIMEOUT_MS` = 40 s rồi dùng dữ liệu dự phòng (#15, phát hiện F8, PLAN 6.3). App hết giờ sớm hơn thì báo lỗi trong khi backend vẫn đang trả plan.

**Lỗi → `ApiException`** (sealed; `message` là câu tiếng Việt hiện thẳng cho người dùng):

| Tình huống | Lớp | `message` |
|---|---|---|
| Không tới được máy chủ (`ClientException`: mất mạng, sai địa chỉ, backend chưa chạy, **CORS chặn trên web**) | `NetworkException` | "Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại." |
| Quá timeout | `ApiTimeoutException` | "Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút." |
| 400 | `ValidationException` | câu chung "Thông tin gửi lên chưa hợp lệ…"; câu của class-validator (tiếng Anh) giữ trong `details` để debug |
| 401 | `UnauthorizedException` | "Phiên đăng nhập đã hết hạn…"; nếu request có gửi token → gọi `onUnauthorized` (AuthProvider đăng xuất — F05) |
| 404 | `NotFoundException` | "Không tìm thấy kế hoạch này." |
| 409 | `PlanOutdatedException` | câu tiếng Việt của server (fixture `error_409`), không có thì câu dự phòng |
| 422 | `NoReplacementException` | câu tiếng Việt của server (fixture `error_422`) |
| 5xx, mã lạ, body không phải JSON, JSON sai hợp đồng | `ServerException(statusCode)` | "Máy chủ đang gặp sự cố…" |

Body luôn đọc bằng `utf8.decode(bodyBytes)` — không có `Content-Type` thì `response.body` của package `http` giải mã bằng latin1, tên món tiếng Việt sẽ vỡ. Parse model nằm **trong** khối bắt `FormatException` (`_send(method, path, parse)`), nên JSON sai hợp đồng thành `ServerException`, không lọt `FormatException` ra giao diện — lỗi này test bắt được khi lập plan (bản đầu parse ngoài khối `try`).

**Không bao giờ in log** request hay response: body chứa hồ sơ và `restrictions` (NFR-7, #12). `ApiException.toString()` chỉ có `message`.

## Scope

UI-only (service + test):

- `frontend_app/lib/services/api_exception.dart`, `api_client.dart` (mới)
- `frontend_app/test/services/api_client_test.dart` (mới)

## Implementation

### API Routes

Không thêm route; gọi các route đã có. **Độ trễ** do backend quyết định: chế độ giả lập vài ms (đo trong Chrome: `generate-plan` 27 ms kể cả preflight); có Gemini 8–13 s, tệ nhất ~40 s — dưới timeout 60 s của app.

**Token:** `accessToken` do `AuthProvider` đặt (F05). Token hết hạn → server 401 → `onUnauthorized` → đăng xuất, request sau đi như khách. Không tự gọi lại request như khách: người dùng thấy câu "phiên đăng nhập đã hết hạn" và bấm lại (tránh lặng lẽ tạo plan không vào lịch sử). Đăng nhập (`authorize: false`) không gửi token cũ, nên đăng nhập lại thất bại không làm mất phiên đang có.

### UI Components

Không có — giao diện bắt `ApiException` và hiện `message` từ giai đoạn 6.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#3** app không giữ khoá Gemini — chỉ gọi backend.
- **#10** app gửi JWT của backend, không gửi/lưu ID Token Google ngoài lúc đăng nhập.
- **#12** không in body ra log; `details` của 400 không hiện cho người dùng.
- **#15** timeout của app (60 s) dài hơn giới hạn Gemini của backend (40 s).
- **#22** 401 → đăng xuất; 404 cho plan của người khác hiện như không tìm thấy.
- **#24** 409 → `PlanOutdatedException` để giao diện gợi ý tạo plan mới (giai đoạn 7).
- Ràng buộc mới #28 ghi vào wiki ở F07.

## Definition of Done

- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test test/services` → `All tests passed!` (13 test)
- [ ] Mọi mã lỗi của fixture (`error_400` … `error_422`) thành đúng lớp `ApiException`
- [ ] Không có `print`/`debugPrint`/`log` nào trong `lib/services/`: `grep -rn "print\|log(" lib/services` không ra gì

## Test Checklist

1. **@happy**: `generatePlan` gửi POST JSON UTF-8 đúng hồ sơ (kể cả "Hải sản"), không có `Authorization` khi là khách; đổi món/đổi bài/feedback gửi đúng body; đăng nhập, xoá tài khoản (204), plan trong lịch sử, `/health`
2. **@auth**: có token → `Authorization: Bearer …`; 401 có gửi token → `onUnauthorized` gọi đúng 1 lần; 401 khi đăng nhập (không gửi token) → không gọi
3. **@timeout**: server không trả lời → `ApiTimeoutException` (timeout 20 ms trong test)
4. **@partial-fail**: 500, HTML 502, `not json`, `{"plan":{"plan_id":1}}`, mảng → `ServerException`; `ClientException` → `NetworkException`
5. **@token**: 409/422 hiện đúng câu tiếng Việt của server; 400 giữ `details`, `message` không chứa tên trường
6. **@encoding**: response không có `Content-Type` vẫn đọc đúng tiếng Việt
7. **@db**: không áp dụng

## Tasks

### Task 1 — Lớp lỗi

`frontend_app/lib/services/api_exception.dart`:

```dart
// Lỗi khi gọi backend_api. `message` là câu tiếng Việt hiện thẳng cho người dùng — không bao giờ chứa
// body request/response hay dữ liệu hồ sơ.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

// Không tới được máy chủ: mất mạng, sai địa chỉ, backend chưa chạy, CORS chặn (web).
class NetworkException extends ApiException {
  const NetworkException() : super('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException() : super('Máy chủ phản hồi quá lâu. Vui lòng thử lại sau ít phút.');
}

// 400. `details` là câu của class-validator (tiếng Anh, chỉ tên trường, không có giá trị) — để debug, không hiện
// cho người dùng.
class ValidationException extends ApiException {
  const ValidationException(this.details) : super('Thông tin gửi lên chưa hợp lệ. Vui lòng kiểm tra lại hồ sơ.');

  final List<String> details;
}

// 401: phiên đăng nhập hết hạn/tài khoản đã xoá, hoặc id_token không hợp lệ khi đăng nhập.
class UnauthorizedException extends ApiException {
  const UnauthorizedException() : super('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
}

class NotFoundException extends ApiException {
  const NotFoundException() : super('Không tìm thấy kế hoạch này.');
}

// 409: plan được tạo cho hồ sơ khác (mục tiêu calo đã đổi) — cần tạo plan mới (BRD 6.4).
class PlanOutdatedException extends ApiException {
  const PlanOutdatedException([super.message = 'Kế hoạch này không còn khớp với hồ sơ. Hãy tạo kế hoạch mới.']);
}

// 422: không tìm được món/động tác thay thế phù hợp (BRD 6.4).
class NoReplacementException extends ApiException {
  const NoReplacementException([super.message = 'Chưa tìm được lựa chọn thay thế phù hợp.']);
}

// 5xx, mã lạ, hoặc body không đúng hợp đồng.
class ServerException extends ApiException {
  const ServerException([this.statusCode]) : super('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.');

  final int? statusCode;
}
```

### Task 2 — `ApiClient`

`frontend_app/lib/services/api_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/api/account.dart';
import '../models/api/json_read.dart';
import '../models/api/meal_plan.dart';
import '../models/api/profile.dart';
import 'api_exception.dart';

// Gọi backend_api (BRD mục 6). Mọi lỗi thành ApiException. Không bao giờ in request/response ra log:
// body chứa hồ sơ và `restrictions` — dữ liệu sức khoẻ (NFR-7, #12).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.planTimeout = const Duration(seconds: 60),
    this.requestTimeout = const Duration(seconds: 15),
  }) : _http = httpClient ?? http.Client();

  // Không có dấu / ở cuối (resolveApiBaseUrl() đã bỏ).
  final String baseUrl;
  final http.Client _http;

  // Request có thể gọi Gemini: backend tự dừng Gemini sau GEMINI_TOTAL_TIMEOUT_MS (40 s) rồi dùng dữ liệu dự phòng.
  final Duration planTimeout;
  final Duration requestTimeout;

  // JWT của backend (AuthProvider đặt). null → gọi như khách.
  String? accessToken;

  // Gọi khi server trả 401 cho một request có gửi token — AuthProvider đăng xuất.
  void Function()? onUnauthorized;

  Future<HealthStatus> health() => _send('GET', '/health', HealthStatus.fromJson);

  Future<MealPlan> generatePlan(Profile profile) =>
      _send('POST', '/api/v1/generate-plan', MealPlan.fromJson, body: profile.toJson(), timeout: planTimeout);

  Future<MealPlan> swapMeal(Profile profile, MealPlan plan, String mealId) => _send(
        'POST',
        '/api/v1/meals/swap',
        _planIn,
        body: {'profile': profile.toJson(), 'plan': plan.toJson(), 'meal_id': mealId},
        timeout: planTimeout,
      );

  Future<MealPlan> swapExercise(Profile profile, MealPlan plan, String exerciseId) => _send(
        'POST',
        '/api/v1/exercises/swap',
        _planIn,
        body: {'profile': profile.toJson(), 'plan': plan.toJson(), 'exercise_id': exerciseId},
        timeout: planTimeout,
      );

  Future<FeedbackResult> submitFeedback(Profile profile, MealPlan plan, FeedbackAnswers answers) => _send(
        'POST',
        '/api/v1/feedback',
        FeedbackResult.fromJson,
        body: {'profile': profile.toJson(), 'plan': plan.toJson(), ...answers.toJson()},
        timeout: planTimeout,
      );

  // `idToken`: Google ID token, hoặc "mock:<email>" khi backend chạy AUTH_MODE=mock.
  Future<AuthResult> loginWithGoogle(String idToken) =>
      _send('POST', '/api/v1/auth/google', AuthResult.fromJson, body: {'id_token': idToken}, authorize: false);

  Future<void> deleteAccount() => _send('DELETE', '/api/v1/me', (_) {});

  Future<List<PlanSummary>> history() => _send('GET', '/api/v1/plans/history', planSummariesFromJson);

  Future<MealPlan> historyPlan(String id) =>
      _send('GET', '/api/v1/plans/history/${Uri.encodeComponent(id)}', MealPlan.fromJson);

  void close() => _http.close();

  static MealPlan _planIn(Json json) => MealPlan.fromJson(readMap(json['plan'], 'plan'));

  // `parse` chạy trong khối bắt FormatException: body sai hợp đồng → ServerException, không lọt lỗi parse ra UI.
  Future<T> _send<T>(
    String method,
    String path,
    T Function(Json json) parse, {
    Json? body,
    Duration? timeout,
    bool authorize = true,
  }) async {
    final token = authorize ? accessToken : null;
    final request = http.Request(method, Uri.parse('$baseUrl$path'))..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }

    final http.Response response;
    try {
      response = await _http.send(request).then(http.Response.fromStream).timeout(timeout ?? requestTimeout);
    } on TimeoutException {
      throw const ApiTimeoutException();
    } on http.ClientException {
      throw const NetworkException();
    }

    final status = response.statusCode;
    try {
      if (status == 204) return parse(const {});
      final decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
      if (status >= 200 && status < 300) return parse(readMap(decoded, 'response'));
      throw _errorFor(status, decoded is Map ? decoded['message'] : null, sentToken: token != null);
    } on FormatException {
      throw ServerException(status);
    }
  }

  ApiException _errorFor(int status, Object? message, {required bool sentToken}) {
    switch (status) {
      case 400:
        return ValidationException(switch (message) {
          List<Object?> list => list.whereType<String>().toList(growable: false),
          String text => [text],
          _ => const [],
        });
      case 401:
        if (sentToken) onUnauthorized?.call();
        return const UnauthorizedException();
      case 404:
        return const NotFoundException();
      case 409:
        return message is String ? PlanOutdatedException(message) : const PlanOutdatedException();
      case 422:
        return message is String ? NoReplacementException(message) : const NoReplacementException();
      default:
        return ServerException(status);
    }
  }
}
```

### Task 3 — Test

`frontend_app/test/services/api_client_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_ai_app/models/api/account.dart';
import 'package:my_ai_app/models/api/codes.dart';
import 'package:my_ai_app/models/api/meal_plan.dart';
import 'package:my_ai_app/models/api/profile.dart';
import 'package:my_ai_app/services/api_client.dart';
import 'package:my_ai_app/services/api_exception.dart';

import '../fixture_loader.dart';

const baseUrl = 'http://api.test';

http.Response jsonResponse(Object? body, int status, {bool contentType = true}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: contentType ? {'content-type': 'application/json; charset=utf-8'} : {},
    );

// Ghi lại request cuối cùng rồi trả `response`.
class Recorder {
  http.Request? last;

  ApiClient client(http.Response Function(http.Request) respond, {Duration? timeout}) => ApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((request) async {
          last = request;
          return respond(request);
        }),
        planTimeout: timeout ?? const Duration(seconds: 60),
        requestTimeout: timeout ?? const Duration(seconds: 15),
      );

  Map<String, dynamic> get body => jsonDecode(utf8.decode(last!.bodyBytes)) as Map<String, dynamic>;
}

void main() {
  final profile = Profile.fromJson(loadFixture('profile'));
  final plan = MealPlan.fromJson(loadFixture('generate_plan'));

  group('gửi đúng request', () {
    test('generate-plan: POST JSON UTF-8 đúng hồ sơ, không có Authorization khi là khách', () async {
      final rec = Recorder();
      final result = await rec.client((_) => jsonResponse(loadFixture('generate_plan'), 200)).generatePlan(profile);

      expect(rec.last!.method, 'POST');
      expect(rec.last!.url.toString(), '$baseUrl/api/v1/generate-plan');
      expect(rec.last!.headers['Content-Type'], startsWith('application/json'));
      expect(rec.last!.headers.containsKey('Authorization'), isFalse);
      expect(rec.body, loadFixture('profile'));
      expect(rec.body['restrictions']['allergies'], 'Hải sản');
      expect(result.toJson(), loadFixture('generate_plan'));
    });

    test('có token → Authorization: Bearer', () async {
      final rec = Recorder();
      final api = rec.client((_) => jsonResponse(loadFixture('history'), 200))..accessToken = 'abc.def.ghi';
      final plans = await api.history();

      expect(rec.last!.method, 'GET');
      expect(rec.last!.url.toString(), '$baseUrl/api/v1/plans/history');
      expect(rec.last!.headers['Authorization'], 'Bearer abc.def.ghi');
      expect(plans, hasLength(1));
    });

    test('đổi món gửi nguyên plan + meal_id, trả plan trong "plan"', () async {
      final rec = Recorder();
      final result =
          await rec.client((_) => jsonResponse(loadFixture('meals_swap'), 200)).swapMeal(profile, plan, 'm1_2');

      expect(rec.last!.url.path, '/api/v1/meals/swap');
      expect(rec.body, {'profile': loadFixture('profile'), 'plan': loadFixture('generate_plan'), 'meal_id': 'm1_2'});
      expect(result.toJson(), loadFixture('meals_swap')['plan']);
    });

    test('đổi bài gửi exercise_id', () async {
      final rec = Recorder();
      await rec.client((_) => jsonResponse(loadFixture('exercises_swap'), 200)).swapExercise(profile, plan, 'e1_2');

      expect(rec.last!.url.path, '/api/v1/exercises/swap');
      expect(rec.body['exercise_id'], 'e1_2');
    });

    test('feedback: câu trả lời nằm cùng cấp với profile/plan, safety_warning được đọc', () async {
      final rec = Recorder();
      final result = await rec.client((_) => jsonResponse(loadFixture('feedback_danger'), 200)).submitFeedback(
            profile,
            plan,
            const FeedbackAnswers(
                dayNumber: 1, intensity: Intensity.easy, bodyStates: {BodyState.dangerSign}, eating: Eating.onPlan),
          );

      expect(rec.last!.url.path, '/api/v1/feedback');
      expect(rec.body.keys, containsAll(['profile', 'plan', 'day_number', 'intensity', 'body_states', 'eating']));
      expect(rec.body['body_states'], ['danger_sign']);
      expect(result.safetyWarning, isNotEmpty);
    });

    test('đăng nhập, xoá tài khoản (204), plan trong lịch sử, /health', () async {
      final rec = Recorder();
      final auth = await rec.client((_) => jsonResponse(loadFixture('auth_login'), 200)).loginWithGoogle('mock:a@b.vn');
      expect(rec.body, {'id_token': 'mock:a@b.vn'});
      expect(auth.user.email, isNotEmpty);

      await rec.client((_) => http.Response('', 204)).deleteAccount();
      expect(rec.last!.method, 'DELETE');
      expect(rec.last!.url.path, '/api/v1/me');

      await rec.client((_) => jsonResponse(loadFixture('generate_plan'), 200)).historyPlan(plan.planId);
      expect(rec.last!.url.path, '/api/v1/plans/history/${plan.planId}');

      final health = await rec.client((_) => jsonResponse(loadFixture('health'), 200)).health();
      expect(health.gemini, 'fallback');
    });

    // Không có Content-Type thì package http mặc định latin1 — tên món tiếng Việt sẽ vỡ nếu đọc response.body.
    test('đọc body là UTF-8 cả khi response không có Content-Type', () async {
      final rec = Recorder();
      final result = await rec
          .client((_) => jsonResponse(loadFixture('generate_plan'), 200, contentType: false))
          .generatePlan(profile);
      expect(result.toJson(), loadFixture('generate_plan'));
    });
  });

  group('lỗi HTTP → ApiException', () {
    Future<ApiException> errorOf(http.Response response, {String? token, void Function()? onUnauthorized}) async {
      final api = Recorder().client((_) => response)
        ..accessToken = token
        ..onUnauthorized = onUnauthorized;
      try {
        await api.swapMeal(profile, plan, 'm1_2');
      } on ApiException catch (error) {
        return error;
      }
      fail('không ném ApiException');
    }

    test('400 → ValidationException giữ chi tiết, câu hiện cho người dùng là tiếng Việt chung', () async {
      final error = await errorOf(jsonResponse(loadFixture('error_400'), 400));
      expect(error, isA<ValidationException>());
      expect((error as ValidationException).details, loadFixture('error_400')['message']);
      expect(error.message, isNot(contains('age')));
    });

    test('401 có gửi token → onUnauthorized; không gửi token (đăng nhập hỏng) → không gọi', () async {
      var calls = 0;
      expect(await errorOf(jsonResponse(loadFixture('error_401'), 401), token: 't', onUnauthorized: () => calls++),
          isA<UnauthorizedException>());
      expect(calls, 1);
      await errorOf(jsonResponse(loadFixture('error_401'), 401), onUnauthorized: () => calls++);
      expect(calls, 1);
    });

    test('404, 409, 422 — 409/422 hiện đúng câu tiếng Việt của server', () async {
      expect(await errorOf(jsonResponse(loadFixture('error_404'), 404)), isA<NotFoundException>());

      final outdated = await errorOf(jsonResponse(loadFixture('error_409'), 409));
      expect(outdated, isA<PlanOutdatedException>());
      expect(outdated.message, loadFixture('error_409')['message']);

      final noReplacement = await errorOf(jsonResponse(loadFixture('error_422'), 422));
      expect(noReplacement, isA<NoReplacementException>());
      expect(noReplacement.message, loadFixture('error_422')['message']);
    });

    test('500, body không phải JSON, JSON sai hợp đồng → ServerException', () async {
      expect(await errorOf(jsonResponse({'statusCode': 500, 'message': 'Internal server error'}, 500)),
          isA<ServerException>().having((e) => e.statusCode, 'statusCode', 500));
      expect(await errorOf(http.Response('<html>502 Bad Gateway</html>', 502)), isA<ServerException>());
      expect(await errorOf(http.Response('not json', 200)), isA<ServerException>());
      expect(await errorOf(jsonResponse({'plan': {'plan_id': 1}}, 200)), isA<ServerException>());
      expect(await errorOf(jsonResponse([1, 2], 200)), isA<ServerException>());
    });

    test('mất kết nối → NetworkException', () async {
      final api = ApiClient(
          baseUrl: baseUrl, httpClient: MockClient((_) async => throw http.ClientException('Connection refused')));
      await expectLater(api.generatePlan(profile), throwsA(isA<NetworkException>()));
    });

    test('quá thời gian → ApiTimeoutException', () async {
      final never = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: baseUrl,
        httpClient: MockClient((_) => never.future),
        planTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(api.generatePlan(profile), throwsA(isA<ApiTimeoutException>()));
    });
  });
}
```

### Task 4 — Cổng kiểm tra F04

```bash
cd frontend_app
flutter analyze              # No issues found!
flutter test test/services   # +13: All tests passed!
grep -rn "print\|log(" lib/services   # không có dòng nào
```
