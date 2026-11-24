import 'package:flutter/foundation.dart';

// Địa chỉ backend_api. Đặt khi build/chạy: `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
// Không đặt → backend chạy trên chính máy dev: máy ảo Android thấy máy dev ở 10.0.2.2, web/iOS Simulator/desktop
// thấy ở localhost. Điện thoại thật cần địa chỉ LAN của máy dev (xem CLAUDE.md, mục Commands).
const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String resolveApiBaseUrl({String configured = _configuredBaseUrl, bool isWeb = kIsWeb, TargetPlatform? platform}) {
  final url = configured.trim().isNotEmpty
      ? configured.trim()
      : 'https://smartfit-api-end-to-end.onrender.com';
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

