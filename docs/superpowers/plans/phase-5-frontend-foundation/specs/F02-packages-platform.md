# F02 — Package, địa chỉ backend, quyền mạng theo nền tảng (PLAN 5.1, 5.2)

## Feature

- **Package (5.1):** `http ^1.6.0`, `provider ^6.1.5`, `shared_preferences ^2.5.5` — đúng ba package BRD mục 4 đã chọn. Dùng API cũ `SharedPreferences.getInstance()` (chưa bị đánh dấu deprecated ở 2.5.5): đọc hết dữ liệu một lần lúc mở app, sau đó đọc đồng bộ — `MainShell` biết ngay có plan hay chưa (F06).
- **Địa chỉ backend (5.2):** `resolveApiBaseUrl()` đọc `--dart-define=API_BASE_URL=...`; không đặt thì theo nơi chạy:

  | Chạy trên | Mặc định | Ghi chú |
  |---|---|---|
  | Web (Chrome) | `http://localhost:3000` | cần CORS (F01) |
  | Máy ảo Android | `http://10.0.2.2:3000` | 10.0.2.2 là máy dev nhìn từ máy ảo |
  | iOS Simulator, macOS, Windows, Linux | `http://localhost:3000` | |
  | Điện thoại thật | — | phải đặt `API_BASE_URL=http://<IP LAN của máy dev>:3000`; hai máy cùng Wi-Fi, tường lửa mở cổng 3000 |

  Bỏ khoảng trắng và dấu `/` cuối để nối đường dẫn không bị `//`.
- **Quyền mạng:**

  | Nền tảng | File | Thay đổi | Vì sao |
  |---|---|---|---|
  | Android | `android/app/src/main/AndroidManifest.xml` | `INTERNET` | manifest `debug`/`profile` có sẵn quyền này cho công cụ Flutter, bản release thì không → APK release không gọi được mạng |
  | Android | `android/app/src/debug/AndroidManifest.xml` | `usesCleartextTraffic="true"` | Android 9+ chặn `http://`; chỉ bật ở bản debug để gọi backend trên máy dev |
  | iOS | `ios/Runner/Info.plist` | `NSAppTransportSecurity` → `NSAllowsLocalNetworking` | cho `http://` tới `localhost` và mạng LAN, không mở mọi domain |
  | macOS | `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` | `com.apple.security.network.client` | app macOS chạy trong sandbox, thiếu quyền này thì mọi request ra ngoài lỗi |

## Scope

UI-only (cấu hình):

- `frontend_app/pubspec.yaml`, `pubspec.lock` (sinh bằng `flutter pub get`), `macos/Flutter/GeneratedPluginRegistrant.swift` (sinh — file này có trong git)
- `frontend_app/lib/config/api_config.dart` (mới), `test/config/api_config_test.dart` (mới)
- 5 file nền tảng ở bảng trên

## Implementation

### API Routes

Không có.

### UI Components

Không có.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- Ràng buộc mới #29 (quyền mạng theo nền tảng; bản release chỉ gọi `https://`) ghi vào wiki ở F07.
- Không kiểm được trên máy lập plan: không có Xcode (iOS, macOS) và tải Gradle bị ngắt (Android). `plutil -lint` và `xmllint` đã kiểm cú pháp; bản web build được (`flutter build web`). Chạy thử trên máy ảo Android / iOS Simulator là việc của giai đoạn 6 (6.3 gọi API thật).

## Definition of Done

- [ ] `flutter pub get` thành công; `pubspec.lock` có `http`, `provider`, `shared_preferences`
- [ ] `flutter analyze` → `No issues found!`
- [ ] `flutter test test/config` → `All tests passed!` (2 test)
- [ ] `plutil -lint ios/Runner/Info.plist macos/Runner/*.entitlements` → `OK`; `xmllint --noout android/app/src/{main,debug}/AndroidManifest.xml` sạch
- [ ] `flutter build web --dart-define=API_BASE_URL=http://localhost:3000` → `✓ Built build/web`

## Test Checklist

1. **@happy**: `API_BASE_URL` đặt → dùng đúng giá trị, bỏ `/` cuối
2. **@platform**: không đặt → Android `10.0.2.2`, web/iOS/macOS `localhost`; chuỗi toàn khoảng trắng coi như không đặt
3. **@auth**: không áp dụng
4. **@timeout**: không áp dụng
5. **@partial-fail**: không áp dụng
6. **@token**: không áp dụng
7. **@db**: không áp dụng

## Tasks

### Task 1 — Package

`frontend_app/pubspec.yaml`, khối `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  http: ^1.6.0
  provider: ^6.1.5
  shared_preferences: ^2.5.5
```

```bash
cd frontend_app
flutter pub get
git status --short   # pubspec.yaml, pubspec.lock, macos/Flutter/GeneratedPluginRegistrant.swift
```

### Task 2 — Địa chỉ backend

`frontend_app/lib/config/api_config.dart`:

```dart
import 'package:flutter/foundation.dart';

// Địa chỉ backend_api. Đặt khi build/chạy: `flutter run --dart-define=API_BASE_URL=https://api.example.com`.
// Không đặt → backend chạy trên chính máy dev: máy ảo Android thấy máy dev ở 10.0.2.2, web/iOS Simulator/desktop
// thấy ở localhost. Điện thoại thật cần địa chỉ LAN của máy dev (xem CLAUDE.md, mục Commands).
const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

String resolveApiBaseUrl({String configured = _configuredBaseUrl, bool isWeb = kIsWeb, TargetPlatform? platform}) {
  final isAndroid = !isWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;
  final url = configured.trim().isNotEmpty
      ? configured.trim()
      : isAndroid
          ? 'http://10.0.2.2:3000'
          : 'http://localhost:3000';
  return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}
```

`frontend_app/test/config/api_config_test.dart`:

```dart
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
```

### Task 3 — Quyền mạng

`android/app/src/main/AndroidManifest.xml` — thêm trước `<application`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Gọi backend_api (bản release cũng cần; manifest debug/profile đã có sẵn cho công cụ Flutter). -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <application
```

`android/app/src/debug/AndroidManifest.xml` — thêm sau dòng `INTERNET` có sẵn:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- Chỉ bản debug: cho gọi backend chạy http:// trên máy dev (10.0.2.2 hoặc IP mạng LAN).
         Bản release chỉ gọi https://. -->
    <application android:usesCleartextTraffic="true"/>
</manifest>
```

`ios/Runner/Info.plist` — thêm ngay trước `</dict>` cuối file:

```xml
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsLocalNetworking</key>
		<true/>
	</dict>
```

`macos/Runner/DebugProfile.entitlements` và `macos/Runner/Release.entitlements` — thêm ngay sau `com.apple.security.app-sandbox`:

```xml
	<key>com.apple.security.network.client</key>
	<true/>
```

```bash
plutil -lint ios/Runner/Info.plist macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements
xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/debug/AndroidManifest.xml
```

### Task 4 — Cổng kiểm tra F02

```bash
cd frontend_app
flutter analyze            # No issues found!
flutter test test/config   # +2: All tests passed!
flutter build web --dart-define=API_BASE_URL=http://localhost:3000   # ✓ Built build/web
```

`flutter test` toàn bộ vẫn đỏ ở `widget_test.dart` như trước giai đoạn này (test tìm chữ "MỤC TIÊU HÔM NAY" không còn trong màn hình — phát hiện F2 của brainstorm); F06 viết lại test này.
