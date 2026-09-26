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
