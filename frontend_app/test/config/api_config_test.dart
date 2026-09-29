import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_ai_app/config/api_config.dart';

void main() {
  test('API_BASE_URL được đặt → dùng nó, bỏ dấu / cuối', () {
    expect(resolveApiBaseUrl(configured: 'https://api.example.com/', isWeb: false, platform: TargetPlatform.android),
        'https://api.example.com');
  });

  test('không đặt: máy ảo Android → 10.0.2.2, web/iOS/desktop → localhost', () {
    expect(resolveApiBaseUrl(configured: '', isWeb: false, platform: TargetPlatform.android), 'http://10.0.2.2:3000');
    expect(resolveApiBaseUrl(configured: '', isWeb: true, platform: TargetPlatform.android), 'http://localhost:3000');
    expect(resolveApiBaseUrl(configured: '', isWeb: false, platform: TargetPlatform.iOS), 'http://localhost:3000');
    expect(resolveApiBaseUrl(configured: ' ', isWeb: false, platform: TargetPlatform.macOS), 'http://localhost:3000');
  });
}
