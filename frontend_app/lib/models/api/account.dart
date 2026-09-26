import 'codes.dart';
import 'json_read.dart';
import 'meal_plan.dart';

// Đăng nhập, lịch sử, feedback, /health (BRD 6.3, 6.4).

class AuthUser {
  const AuthUser({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  factory AuthUser.fromJson(Json json) =>
      AuthUser(id: readString(json, 'id'), email: readString(json, 'email'), name: readString(json, 'name'));

  Json toJson() => {'id': id, 'email': email, 'name': name};
}

class AuthResult {
  const AuthResult({required this.accessToken, required this.user});

  final String accessToken;
  final AuthUser user;

  factory AuthResult.fromJson(Json json) => AuthResult(
        accessToken: readString(json, 'access_token'),
        user: AuthUser.fromJson(readMap(json['user'], 'user')),
      );

  Json toJson() => {'access_token': accessToken, 'user': user.toJson()};
}

class PlanSummary {
  const PlanSummary({required this.id, required this.createdAt, required this.targetCalories});

  final String id;
  final DateTime createdAt;
  final num targetCalories;

  factory PlanSummary.fromJson(Json json) {
    final createdAt = DateTime.tryParse(readString(json, 'created_at'));
    if (createdAt == null) throw const FormatException('"created_at" phải là thời điểm ISO 8601');
    return PlanSummary(id: readString(json, 'id'), createdAt: createdAt.toUtc(), targetCalories: readNum(json, 'target_calories'));
  }

  Json toJson() => {'id': id, 'created_at': createdAt.toUtc().toIso8601String(), 'target_calories': targetCalories};
}

List<PlanSummary> planSummariesFromJson(Json json) =>
    readList(json, 'plans', (item) => PlanSummary.fromJson(readMap(item, 'plans[]')));

class FeedbackResult {
  const FeedbackResult({required this.plan, this.safetyWarning});

  final MealPlan plan;
  // Khác null khi người dùng báo dấu hiệu nguy hiểm (chóng mặt, khó thở, đau ngực) — app phải hiện nổi bật.
  final String? safetyWarning;

  factory FeedbackResult.fromJson(Json json) {
    final warning = json['safety_warning'];
    return FeedbackResult(
      plan: MealPlan.fromJson(readMap(json['plan'], 'plan')),
      safetyWarning: warning == null ? null : readString(readMap(warning, 'safety_warning'), 'message'),
    );
  }

  Json toJson() => {
        'plan': plan.toJson(),
        'safety_warning': safetyWarning == null ? null : {'message': safetyWarning},
      };
}

class HealthStatus {
  const HealthStatus({required this.status, required this.gemini, required this.authMode});

  final String status;
  // "configured" | "fallback" — backend đang dùng Gemini thật hay dữ liệu mẫu.
  final String gemini;
  // "mock" | "google".
  final String authMode;

  factory HealthStatus.fromJson(Json json) => HealthStatus(
        status: readString(json, 'status'),
        gemini: readString(json, 'gemini'),
        authMode: readString(json, 'auth_mode'),
      );

  Json toJson() => {'status': status, 'gemini': gemini, 'auth_mode': authMode};
}

// Câu trả lời bảng feedback cuối ngày (BRD 6.4).
class FeedbackAnswers {
  const FeedbackAnswers({required this.dayNumber, required this.intensity, required this.bodyStates, required this.eating});

  final int dayNumber;
  final Intensity intensity;
  final Set<BodyState> bodyStates;
  final Eating eating;

  Json toJson() => {
        'day_number': dayNumber,
        'intensity': intensity.code,
        'body_states': bodyStates.map((state) => state.code).toList(),
        'eating': eating.code,
      };
}
