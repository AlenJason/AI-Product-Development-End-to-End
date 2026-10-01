# F03 — Loại dữ liệu khỏi sao lưu Android, chạy trên thiết bị

## Feature

- **Android (quyết định Q7, brainstorm P14):** manifest không khai báo gì về sao lưu → Auto Backup mặc định bật: `shared_preferences` (hồ sơ có dữ liệu sức khoẻ, JWT, plan) lên Google Drive và sang máy mới khi chuyển máy. Thêm `android:dataExtractionRules` (Android 12+: `cloud-backup` và `device-transfer` — với `targetSdk` ≥ 31, `allowBackup="false"` không chặn chép giữa hai máy) và `android:fullBackupContent` (Android 11 trở xuống), cùng loại `domain="sharedpref"`.
- **Integration test:** bài giao diện viết lại cho luồng giai đoạn 8: màn chào → đăng nhập demo (`ui-smoke@example.com`) → Onboarding → plan thật → đổi món → feedback ngày 1 → tab Lịch sử có đúng một plan, nhãn "Đang dùng" → xem chi tiết (đúng món đã đổi, không có nút đổi) → tab Cá nhân → "Xoá tài khoản" → "Xoá vĩnh viễn" → về khách, plan trên máy giữ. Bài này dọn luôn tài khoản thử trên backend.
- **macOS:** không commit `GIDClientID`, URL scheme, keychain sharing (SETUP mục 3.4, F04).

**Phát hiện khi lập plan:**

| # | Phát hiện | Xử lý |
|---|---|---|
| P21 | Kiểm sao lưu thật bằng `bmgr` + LocalTransport trên Android 16 (máy ảo, `adb root`): bản debug báo "Size quota exceeded" (`app_flutter` ~55 MB); app vừa cài hoặc bị force-stop báo "Backup is not allowed" | Kiểm bằng bản release, mở app bằng `am start` trước khi `bmgr backupnow` |
| P22 | Cùng cách kiểm: bản HEAD đưa `apps/com.example.my_ai_app/sp/FlutterSharedPreferences.xml` (có token) vào bản sao lưu; bản mới chỉ còn `r/app_flutter`, `f/…` — đúng tệp app ghi (`flutter.smartfit.welcome_done.v1` nằm trong `FlutterSharedPreferences.xml`) | Giữ luật; ghi cách kiểm vào [[flutter-ui]] |
| P23 | Thêm `keychain-access-groups` vào entitlements macOS → `flutter build macos` không ký dừng: `"Runner" has entitlements that require signing with a development certificate` | Không commit; SETUP 3.4 hướng dẫn chọn Team trong Xcode |

## Scope

- `frontend_app/android/app/src/main/AndroidManifest.xml` (sửa); `android/app/src/main/res/xml/data_extraction_rules.xml`, `backup_rules.xml` (mới)
- `frontend_app/integration_test/backend_smoke_test.dart` (sửa)

## Implementation

### API Routes

Không có. Integration test gọi backend thật ở chế độ giả lập (#17: tự dừng nếu `/health` báo `gemini: configured` hoặc `auth_mode` khác `mock`). Thời gian chờ trong test: `pumpUntil` tối đa 60 s, bằng timeout của app.

### UI Components

Không có.

### DB / KV Changes

Không có. Luật sao lưu chỉ áp cho tệp của app trên Android.

### Ràng buộc áp dụng

- **#12, NFR-7** dữ liệu sức khoẻ và token không rời máy ngoài ý muốn.
- **#17** không gọi Gemini, Google thật.
- **#29** manifest chính vẫn có `INTERNET`.
- **#37** (mới) không bỏ hai luật sao lưu.

## Definition of Done

- [ ] `xmllint --noout android/app/src/main/res/xml/*.xml android/app/src/main/AndroidManifest.xml` → không lỗi
- [ ] `flutter build apk --release` → `✓ Built`; manifest trong APK có `dataExtractionRules` và `fullBackupContent`
- [ ] `flutter test integration_test -d emulator-5554` → `+3: All tests passed!`
- [ ] `flutter test integration_test -d macos` → `+3: All tests passed!`

## Test Checklist

1. **@device**: Android 16 (máy ảo Pixel 8) và macOS — đăng nhập demo qua giao diện, plan thật, lịch sử, xem chi tiết, xoá tài khoản qua giao diện
2. **@backup**: (tay, không tự động) bản release, `bmgr backupnow` qua LocalTransport — không có `sp/FlutterSharedPreferences.xml`
3. **@auth**: xoá tài khoản thật trên backend giả lập trả 204, app về khách
4. **@timeout**, **@token**, **@db**: không đổi

## Tasks

### Task 1 — Luật sao lưu

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Android 12+ (targetSdk ≥ 31): không đưa dữ liệu của app lên bản sao lưu Google Drive, cũng không chép sang máy mới
     khi chuyển máy (allowBackup="false" không chặn được chép giữa hai máy). shared_preferences lưu trong sharedpref:
     hồ sơ có dữ liệu sức khoẻ (NFR-7), JWT đăng nhập, plan. Giai đoạn 8, quyết định Q7. -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="." />
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="." />
    </device-transfer>
</data-extraction-rules>
```

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Android 11 trở xuống: như data_extraction_rules.xml — không sao lưu shared_preferences (hồ sơ sức khoẻ, JWT, plan). -->
<full-backup-content>
    <exclude domain="sharedpref" path="." />
</full-backup-content>
```

```diff
--- a/frontend_app/android/app/src/main/AndroidManifest.xml
+++ b/frontend_app/android/app/src/main/AndroidManifest.xml
@@ -1,10 +1,13 @@
 <manifest xmlns:android="http://schemas.android.com/apk/res/android">
     <!-- Gọi backend_api (bản release cũng cần; manifest debug/profile đã có sẵn cho công cụ Flutter). -->
     <uses-permission android:name="android.permission.INTERNET"/>
+    <!-- Không sao lưu / chép sang máy khác dữ liệu đã lưu (hồ sơ sức khoẻ, token) — res/xml/*_rules.xml. -->
     <application
         android:label="SmartFit AI"
         android:name="${applicationName}"
-        android:icon="@mipmap/ic_launcher">
+        android:icon="@mipmap/ic_launcher"
+        android:dataExtractionRules="@xml/data_extraction_rules"
+        android:fullBackupContent="@xml/backup_rules">
         <activity
             android:name=".MainActivity"
             android:exported="true"
```

```bash
cd frontend_app
xmllint --noout android/app/src/main/res/xml/*.xml android/app/src/main/AndroidManifest.xml
flutter build apk --release
"$(ls -d ~/Library/Android/sdk/build-tools/*/ | tail -1)aapt2" dump xmltree --file AndroidManifest.xml \
  build/app/outputs/flutter-apk/app-release.apk | grep -E "dataExtractionRules|fullBackupContent"
```

Kiểm tay trên máy ảo có `adb root` (không chạy trong CI):

```bash
ADB=~/Library/Android/sdk/platform-tools/adb; P=com.example.my_ai_app
$ADB root
$ADB install -r build/app/outputs/flutter-apk/app-release.apk
$ADB shell am start -n $P/.MainActivity      # app không được ở trạng thái force-stop; bấm "Dùng ngay" để có dữ liệu
$ADB shell input keyevent KEYCODE_HOME
$ADB shell bmgr enable true
$ADB shell bmgr transport com.android.localtransport/.LocalTransport
$ADB shell bmgr backupnow $P                 # "Success"
$ADB shell "cat /data/data/com.android.localtransport/files/1/_full/$P" > backup.tar
tar -tf backup.tar                            # không có apps/com.example.my_ai_app/sp/...
$ADB shell bmgr transport com.google.android.gms/.backup.BackupTransportService
$ADB unroot
```

### Task 2 — Integration test (diff so với mốc F02)

```diff
--- a/frontend_app/integration_test/backend_smoke_test.dart
+++ b/frontend_app/integration_test/backend_smoke_test.dart
@@ -120,12 +120,12 @@
     await expectLater(closedPort.health(), throwsA(isA<NetworkException>()));
   });
 
-  // Thao tác giao diện thật trên thiết bị (giai đoạn 6, 7): Onboarding → backend thật tạo plan → Dashboard → đổi món
-  // → feedback cuối ngày 1 (bảng trượt, báo điều đã đổi, khoá ngày).
-  testWidgets('giao diện trên thiết bị: Onboarding → plan thật → Dashboard → đổi món → feedback ngày 1', (tester) async {
+  // Thao tác giao diện thật trên thiết bị (giai đoạn 6–8): màn chào → đăng nhập demo → Onboarding → backend thật tạo
+  // plan → Dashboard → đổi món → feedback cuối ngày 1 → tab Lịch sử có plan đang dùng → xem lại → xoá tài khoản.
+  testWidgets('giao diện trên thiết bị: đăng nhập demo → plan thật → đổi món → feedback → lịch sử → xoá tài khoản',
+      (tester) async {
     final prefs = await SharedPreferences.getInstance();
     await prefs.clear();
-    await prefs.setBool(AuthProvider.welcomeKey, true);
     final api = ApiClient(baseUrl: resolveApiBaseUrl());
     final auth = AuthProvider(api: api, prefs: prefs, google: PluginGoogleAuth());
     final plans = PlanProvider(api: api, prefs: prefs);
@@ -135,6 +135,14 @@
       grocery: GroceryProvider(prefs: prefs, plans: plans),
       history: HistoryProvider(api: api, auth: auth),
     ));
+    // Màn chào hỏi /health: backend giả lập → ô email "Đăng nhập demo".
+    await pumpUntil(tester, find.text('Đăng nhập demo'));
+    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'ui-smoke@example.com');
+    await tester.pump();
+    await tester.tap(find.text('Đăng nhập demo'));
+    await pumpUntil(tester, find.text('Tiếp tục'));
+    expect(auth.user!.email, 'ui-smoke@example.com');
+
     await fillOnboarding(tester);
     await tester.tap(find.text('Tạo kế hoạch 3 ngày'));
     await pumpUntil(tester, find.text('Hôm nay là Ngày 1'));
@@ -160,6 +168,28 @@
     await tester.pumpAndSettle();
     await scrollTo(tester, find.text('Đã gửi đánh giá ngày 1'));
     expect(plans.feedbackDays, {1});
+
+    // Lịch sử (FR-7.2): plan vừa tạo nằm trên server, đánh dấu "Đang dùng"; xem lại được bản đã đổi món.
+    await tester.tap(find.text('Lịch sử'));
+    await pumpUntil(tester, find.text('Đang dùng'));
+    expect(find.byType(ListTile), findsOneWidget);
+    await tester.tap(find.byType(ListTile));
+    await pumpUntil(tester, find.text('BỮA SÁNG'));
+    expect(find.text(plans.plan!.days.first.meals.first.name), findsOneWidget);
+    expect(find.text('Đổi món'), findsNothing);
+    await tester.pageBack();
+    await tester.pumpAndSettle();
+
+    // Xoá tài khoản (FR-6.4) qua giao diện: server xoá tài khoản + lịch sử, plan trên máy giữ.
+    await tester.tap(find.text('Cá nhân'));
+    await tester.pumpAndSettle();
+    await scrollTo(tester, find.text('Xoá tài khoản'));
+    await tester.tap(find.text('Xoá tài khoản'));
+    await tester.pumpAndSettle();
+    await tester.tap(find.text('Xoá vĩnh viễn'));
+    await pumpUntil(tester, find.text('Đã xoá tài khoản và lịch sử kế hoạch.'));
+    expect(auth.isSignedIn, isFalse);
+    expect(plans.hasPlan, isTrue);
     await tester.pumpWidget(const SizedBox());
     await prefs.clear();
   });
```

```bash
cd backend_api && GEMINI_API_KEY= AUTH_MODE=mock npm run start:dev   # backend giả lập
cd frontend_app
flutter test integration_test -d emulator-5554   # +3: All tests passed!
flutter test integration_test -d macos           # +3: All tests passed!
```
