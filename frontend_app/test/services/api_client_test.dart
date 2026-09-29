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
