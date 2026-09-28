import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/meal_plan.dart';

class SmartFitService {
  SmartFitService({String? baseUrl})
    : _baseUrl = baseUrl ?? 'http://localhost:3000';

  final String _baseUrl;

  Future<AuthSession> loginWithGoogle(String idToken) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    _throwForFailure(response);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final user = Map<String, dynamic>.from(payload['user'] as Map);
    return AuthSession(
      accessToken: payload['access_token'].toString(),
      userId: user['id'].toString(),
      email: user['email'].toString(),
      name: user['name'].toString(),
    );
  }

  Future<List<PlanHistoryEntry>> getPlanHistory(String accessToken) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/plans/history'),
      headers: _authHeaders(accessToken),
    );
    _throwForFailure(response);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['plans'] as List? ?? const [])
        .map((item) => PlanHistoryEntry.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<MealPlanResponse> getPlanHistoryEntry(
    String accessToken,
    String planId,
  ) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/plans/history/$planId'),
      headers: _authHeaders(accessToken),
    );
    return _readPlan(response);
  }

  Future<void> deleteAccount(String accessToken) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/me'),
      headers: _authHeaders(accessToken),
    );
    _throwForFailure(response);
  }

  Map<String, String> _authHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
  };

  void _throwForFailure(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SmartFitApiException(
        statusCode: response.statusCode,
        message: _errorMessage(response.body),
      );
    }
  }

  MealPlanResponse _readPlan(http.Response response, {bool nested = false}) {
    _throwForFailure(response);

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid plan response.');
    }
    final payload = nested ? decoded['plan'] : decoded;
    if (payload is! Map) {
      throw const FormatException('Plan payload is missing.');
    }
    return MealPlanResponse.fromJson(Map<String, dynamic>.from(payload));
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) {
        final message = decoded['message'];
        return message is List ? message.join('\n') : message.toString();
      }
    } on FormatException {
      // Use a generic message for non-JSON server responses.
    }
    return 'Yêu cầu không thành công. Vui lòng thử lại.';
  }

  Future<MealPlanResponse> generatePlan(Map<String, dynamic> profile) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/generate-plan'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(profile),
    );
    return _readPlan(response);
  }

  Future<MealPlanResponse> swapMeal({required Map<String, dynamic> profile, required MealPlanResponse plan, required String mealId}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/meals/swap'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile': profile, 'plan': plan.toJson(), 'meal_id': mealId}),
    );
    return _readPlan(response, nested: true);
  }

  Future<MealPlanResponse> swapExercise({required Map<String, dynamic> profile, required MealPlanResponse plan, required String exerciseId}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/exercises/swap'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile': profile, 'plan': plan.toJson(), 'exercise_id': exerciseId}),
    );
    return _readPlan(response, nested: true);
  }

  Future<FeedbackResult> submitFeedback({
    required Map<String, dynamic> profile,
    required MealPlanResponse plan,
    required int dayNumber,
    required String intensity,
    required List<String> bodyStates,
    required String eating,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/feedback'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'profile': profile,
        'plan': plan.toJson(),
        'day_number': dayNumber,
        'intensity': intensity,
        'body_states': bodyStates,
        'eating': eating,
      }),
    );
    final updatedPlan = _readPlan(response, nested: true);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final warning = payload['safety_warning'];
    return FeedbackResult(
      plan: updatedPlan,
      safetyWarning: warning is Map ? warning['message']?.toString() : null,
    );
  }
}

class FeedbackResult {
  const FeedbackResult({required this.plan, this.safetyWarning});

  final MealPlanResponse plan;
  final String? safetyWarning;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.userId,
    required this.email,
    required this.name,
  });

  final String accessToken;
  final String userId;
  final String email;
  final String name;
}

class PlanHistoryEntry {
  const PlanHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.targetCalories,
  });

  final String id;
  final DateTime createdAt;
  final int targetCalories;

  factory PlanHistoryEntry.fromJson(Map<String, dynamic> json) =>
      PlanHistoryEntry(
        id: json['id'].toString(),
        createdAt: DateTime.parse(json['created_at'].toString()),
        targetCalories: (json['target_calories'] as num).toInt(),
      );
}

class SmartFitApiException implements Exception {
  const SmartFitApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

