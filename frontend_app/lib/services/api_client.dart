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
