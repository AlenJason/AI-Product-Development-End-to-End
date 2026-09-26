# F05 — Tên app, icon, màn khởi động, thanh hệ thống (PLAN 6.8)

## Feature

| Trước | Sau |
|---|---|
| Tên "my_ai_app" (Android, web), "My Ai App" (iOS) | "SmartFit AI" |
| Icon và màn khởi động logo Flutter | Nền xanh thương hiệu, chữ "S" trắng bo tròn và chiếc lá; Android 8+ có icon thích ứng; Android 12+ màn khởi động nền xanh; Android cũ hơn hiện icon giữa nền trắng |
| Dải đen trên thanh trạng thái / thanh điều hướng Android | Nền trong suốt, app vẽ bên dưới (`SafeArea`) |

**Icon vẽ bằng code, không cần công cụ thiết kế:** `tool/make_icon.swift` (CoreGraphics + AppKit có sẵn trên macOS) vẽ hai ảnh gốc 1024×1024 — `assets/icon/icon.png` (nền đầy, **không** kênh trong suốt — App Store bắt buộc) và `assets/icon/icon_foreground.png` (nền trong suốt, hình trong vùng an toàn 72/108 dp của icon thích ứng). `tool/update_icons.sh` gọi script đó rồi dùng `sips` thu nhỏ vào mọi vị trí (Android `mipmap-*` và `drawable-*/ic_launcher_foreground.png`, iOS `AppIcon.appiconset`, macOS, web). Chạy lại ra đúng từng byte (đã kiểm 39 file). Có logo thật thì thay hai ảnh gốc hoặc sửa script.

**Hai lỗi chỉ lộ ra khi chạy thật:**

- Android 12+ tự vẽ màn khởi động bằng lớp trước của icon thích ứng — hình trắng trên nền mặc định trắng thì biến mất → `values-v31/styles.xml` đặt `windowSplashScreenBackground` = `@color/ic_launcher_background` (#059669).
- Theme `Theme.Light.NoTitleBar` (template Flutter) không cho app vẽ nền thanh hệ thống, nên màu trong suốt Flutter đặt bị bỏ qua và thanh trạng thái bị tô đen → các theme thêm `windowDrawsSystemBarBackgrounds = true`, `statusBarColor` / `navigationBarColor` trong suốt (F04 đã bật `edgeToEdge` trong `main()`).

Script icon từng hỏng trên bản sạch vì thư mục `assets/icon` chưa có (bản nháp đã có sẵn) — `mkdir -p` trước khi vẽ.

## Scope

Cấu hình nền tảng + công cụ:

- `frontend_app/tool/make_icon.swift`, `tool/update_icons.sh`, `assets/icon/*.png` (mới)
- Android: `AndroidManifest.xml` (tên), `res/values/colors.xml`, `res/values-v31/styles.xml`, `res/mipmap-anydpi-v26/ic_launcher.xml` (mới), `res/values/styles.xml`, `res/values-night/styles.xml`, `res/drawable/launch_background.xml`, `res/drawable-v21/launch_background.xml` (sửa), icon PNG (sinh)
- iOS: `Info.plist` (tên), `AppIcon.appiconset/*.png` (sinh); macOS: `AppIcon.appiconset/*.png` (sinh)
- Web: `index.html`, `manifest.json` (tên, mô tả, màu), `favicon.png`, `icons/*.png` (sinh)

## Implementation

### API Routes

Không có.

### UI Components

Không đổi widget; chỉ cấu hình nền tảng.

### DB / KV Changes

Không có.

### Ràng buộc áp dụng

- **#29** giữ nguyên quyền mạng; chỉ thêm tên và theme.
- Chưa build được iOS/macOS (máy không có Xcode) — PNG iOS/macOS chỉ kiểm kích thước và kênh trong suốt.

## Definition of Done

- [ ] `tool/update_icons.sh` chạy trên macOS, sinh lại đúng từng byte
- [ ] `plutil -lint ios/Runner/Info.plist` OK; `xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/main/res/*/*.xml` sạch
- [ ] `flutter build apk --debug` và `flutter build web` thành công
- [ ] Trên máy ảo Android: launcher hiện "SmartFit AI" với icon mới; màn khởi động nền xanh; thanh trạng thái sáng, thấy giờ và pin

## Test Checklist

1. **@icon**: `sips -g hasAlpha assets/icon/icon.png` → `no`; icon_foreground → `yes`
2. **@android**: APK debug build được; `aapt2 dump xmltree … AndroidManifest.xml` có `label` "SmartFit AI"
3. **@device**: ảnh chụp launcher, màn khởi động, Onboarding (thanh trạng thái sáng)
4. **@web**: `build/web/index.html` có `<title>SmartFit AI</title>`
5. **@auth**, **@timeout**, **@token**, **@db**: không áp dụng

## Tasks

### Task 1 — Vẽ icon

`frontend_app/tool/make_icon.swift`:

```swift
// Vẽ icon SmartFit AI (giai đoạn 6, PLAN 6.8): nền xanh thương hiệu, chữ "S" trắng bo tròn và một chiếc lá.
// Chạy trên macOS: swift tool/make_icon.swift assets/icon
//   icon.png            1024×1024, nền đầy, không kênh trong suốt (iOS bắt buộc) — nguồn cho mọi icon vuông
//   icon_foreground.png 1024×1024, nền trong suốt — lớp trước của icon thích ứng Android 8+ và màn khởi động Android 12+
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Hình chính nằm trong ô vuông tâm, cạnh = size × scale.
func drawSymbol(_ ctx: CGContext, size: CGFloat, scale: CGFloat) {
  let box = size * scale
  let origin = (size - box) / 2
  let base = NSFont.systemFont(ofSize: box * 0.92, weight: .black)
  let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: box * 0.92) ?? base
  let text = NSAttributedString(string: "S", attributes: [.font: font, .foregroundColor: NSColor.white])
  let line = CTLineCreateWithAttributedString(text)
  let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
  ctx.textPosition = CGPoint(x: origin + (box - bounds.width) / 2 - bounds.minX - box * 0.04,
                             y: origin + (box - bounds.height) / 2 - bounds.minY - box * 0.02)
  CTLineDraw(line, ctx)

  // Chiếc lá: hai cung tròn giao nhau, nghiêng 45°, góc trên bên phải chữ S.
  ctx.saveGState()
  ctx.translateBy(x: origin + box * 0.80, y: origin + box * 0.80)
  ctx.rotate(by: .pi / 4)
  let leaf = CGMutablePath()
  let w = box * 0.30, h = box * 0.15
  leaf.move(to: CGPoint(x: -w / 2, y: 0))
  leaf.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: h))
  leaf.addQuadCurve(to: CGPoint(x: -w / 2, y: 0), control: CGPoint(x: 0, y: -h))
  ctx.addPath(leaf)
  ctx.setFillColor(color(0xA7F3D0))
  ctx.fillPath()
  ctx.restoreGState()
}

func render(_ name: String, opaque: Bool, scale: CGFloat) {
  let size: CGFloat = 1024
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
  let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: info)!
  if opaque {
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x10B981), color(0x047857)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
  }
  drawSymbol(ctx, size: size, scale: scale)
  let image = ctx.makeImage()!
  let rep = NSBitmapImageRep(cgImage: image)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

render("icon.png", opaque: true, scale: 0.62)
// Vùng an toàn của icon thích ứng: 72/108 dp ở giữa — hình nằm gọn trong đó.
render("icon_foreground.png", opaque: false, scale: 0.50)
```

`frontend_app/tool/update_icons.sh` (chmod +x):

```bash
#!/bin/bash
# Vẽ lại icon SmartFit AI và chép đủ kích thước cho Android, iOS, macOS, web (PLAN 6.8). Chạy trên macOS
# (cần swift và sips có sẵn):  cd frontend_app && tool/update_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/icon
swift tool/make_icon.swift assets/icon >/dev/null
full=assets/icon/icon.png
fg=assets/icon/icon_foreground.png
res=android/app/src/main/res
resize() { sips -z "$2" "$2" "$1" --out "$3" >/dev/null; }

# Android: icon vuông cho launcher cũ + icon thích ứng (Android 8+): nền màu + lớp trước 108 dp.
for pair in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  IFS=: read -r density legacy adaptive <<<"$pair"
  resize "$full" "$legacy" "$res/mipmap-$density/ic_launcher.png"
  mkdir -p "$res/drawable-$density"
  resize "$fg" "$adaptive" "$res/drawable-$density/ic_launcher_foreground.png"
done

# iOS và macOS: đọc kích thước từ chính tên file có sẵn trong Assets.xcassets.
for file in ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png; do
  size=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
  resize "$full" "$size" "$file"
done
for file in macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png; do
  size=$(sips -g pixelWidth "$file" | awk '/pixelWidth/{print $2}')
  resize "$full" "$size" "$file"
done

# Web: hình nằm trong vùng an toàn 80% nên dùng cùng ảnh cho bản maskable.
resize "$full" 16 web/favicon.png
for size in 192 512; do
  resize "$full" "$size" "web/icons/Icon-$size.png"
  resize "$full" "$size" "web/icons/Icon-maskable-$size.png"
done
echo "Đã cập nhật icon."
```

```bash
cd frontend_app && tool/update_icons.sh   # Đã cập nhật icon.
```

### Task 2 — Icon thích ứng và màn khởi động Android

`frontend_app/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!-- Icon thích ứng (Android 8+): nền xanh thương hiệu + hình trong vùng an toàn. Vẽ lại bằng tool/update_icons.sh -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

`frontend_app/android/app/src/main/res/values/colors.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Xanh thương hiệu SmartFit AI (AppColors.primary). -->
    <color name="ic_launcher_background">#059669</color>
</resources>
```

`frontend_app/android/app/src/main/res/values-v31/styles.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Android 12+ tự vẽ màn khởi động bằng lớp trước của icon thích ứng (hình trắng) — nền phải là màu thương
         hiệu, nếu để mặc định (trắng) thì hình biến mất. -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">@color/ic_launcher_background</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">?android:colorBackground</item>
        <!-- Cho app vẽ nền thanh trạng thái (theme đời cũ mặc định tô đen) — nền trong suốt, Flutter vẽ bên dưới. -->
        <item name="android:windowDrawsSystemBarBackgrounds">true</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
        <item name="android:navigationBarColor">@android:color/transparent</item>
    </style>
</resources>
```

```diff
--- a/frontend_app/android/app/src/main/res/drawable/launch_background.xml
+++ b/frontend_app/android/app/src/main/res/drawable/launch_background.xml
@@ -2,11 +2,10 @@
 <!-- Modify this file to customize your launch splash screen -->
 <layer-list xmlns:android="http://schemas.android.com/apk/res/android">
     <item android:drawable="@android:color/white" />
-
-    <!-- You can insert your own image assets here -->
-    <!-- <item>
+    <!-- Android dưới 12: icon SmartFit AI giữa màn khởi động. -->
+    <item>
         <bitmap
             android:gravity="center"
-            android:src="@mipmap/launch_image" />
-    </item> -->
+            android:src="@mipmap/ic_launcher" />
+    </item>
 </layer-list>
```

```diff
--- a/frontend_app/android/app/src/main/res/drawable-v21/launch_background.xml
+++ b/frontend_app/android/app/src/main/res/drawable-v21/launch_background.xml
@@ -2,11 +2,10 @@
 <!-- Modify this file to customize your launch splash screen -->
 <layer-list xmlns:android="http://schemas.android.com/apk/res/android">
     <item android:drawable="?android:colorBackground" />
-
-    <!-- You can insert your own image assets here -->
-    <!-- <item>
+    <!-- Android dưới 12: icon SmartFit AI giữa màn khởi động. -->
+    <item>
         <bitmap
             android:gravity="center"
-            android:src="@mipmap/launch_image" />
-    </item> -->
+            android:src="@mipmap/ic_launcher" />
+    </item>
 </layer-list>
```

### Task 3 — Thanh trạng thái / điều hướng

```diff
--- a/frontend_app/android/app/src/main/res/values/styles.xml
+++ b/frontend_app/android/app/src/main/res/values/styles.xml
@@ -14,5 +14,9 @@
          This Theme is only used starting with V2 of Flutter's Android embedding. -->
     <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
         <item name="android:windowBackground">?android:colorBackground</item>
+        <!-- Cho app vẽ nền thanh trạng thái (theme đời cũ mặc định tô đen) — nền trong suốt, Flutter vẽ bên dưới. -->
+        <item name="android:windowDrawsSystemBarBackgrounds">true</item>
+        <item name="android:statusBarColor">@android:color/transparent</item>
+        <item name="android:navigationBarColor">@android:color/transparent</item>
     </style>
 </resources>
```

```diff
--- a/frontend_app/android/app/src/main/res/values-night/styles.xml
+++ b/frontend_app/android/app/src/main/res/values-night/styles.xml
@@ -14,5 +14,9 @@
          This Theme is only used starting with V2 of Flutter's Android embedding. -->
     <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
         <item name="android:windowBackground">?android:colorBackground</item>
+        <!-- Cho app vẽ nền thanh trạng thái (theme đời cũ mặc định tô đen) — nền trong suốt, Flutter vẽ bên dưới. -->
+        <item name="android:windowDrawsSystemBarBackgrounds">true</item>
+        <item name="android:statusBarColor">@android:color/transparent</item>
+        <item name="android:navigationBarColor">@android:color/transparent</item>
     </style>
 </resources>
```

### Task 4 — Tên app

```diff
--- a/frontend_app/android/app/src/main/AndroidManifest.xml
+++ b/frontend_app/android/app/src/main/AndroidManifest.xml
@@ -2,7 +2,7 @@
     <!-- Gọi backend_api (bản release cũng cần; manifest debug/profile đã có sẵn cho công cụ Flutter). -->
     <uses-permission android:name="android.permission.INTERNET"/>
     <application
-        android:label="my_ai_app"
+        android:label="SmartFit AI"
         android:name="${applicationName}"
         android:icon="@mipmap/ic_launcher">
         <activity
```

```diff
--- a/frontend_app/ios/Runner/Info.plist
+++ b/frontend_app/ios/Runner/Info.plist
@@ -7,7 +7,7 @@
 	<key>CFBundleDevelopmentRegion</key>
 	<string>$(DEVELOPMENT_LANGUAGE)</string>
 	<key>CFBundleDisplayName</key>
-	<string>My Ai App</string>
+	<string>SmartFit AI</string>
 	<key>CFBundleExecutable</key>
 	<string>$(EXECUTABLE_NAME)</string>
 	<key>CFBundleIdentifier</key>
```

```diff
--- a/frontend_app/web/index.html
+++ b/frontend_app/web/index.html
@@ -18,18 +18,18 @@
 
   <meta charset="UTF-8">
   <meta content="IE=Edge" http-equiv="X-UA-Compatible">
-  <meta name="description" content="A new Flutter project.">
+  <meta name="description" content="Kế hoạch ăn uống món Việt và tập luyện tại nhà 3 ngày, điều chỉnh theo phản hồi.">
 
   <!-- iOS meta tags & icons -->
   <meta name="mobile-web-app-capable" content="yes">
   <meta name="apple-mobile-web-app-status-bar-style" content="black">
-  <meta name="apple-mobile-web-app-title" content="my_ai_app">
+  <meta name="apple-mobile-web-app-title" content="SmartFit AI">
   <link rel="apple-touch-icon" href="icons/Icon-192.png">
 
   <!-- Favicon -->
   <link rel="icon" type="image/png" href="favicon.png"/>
 
-  <title>my_ai_app</title>
+  <title>SmartFit AI</title>
   <link rel="manifest" href="manifest.json">
 </head>
 <body>
```

```diff
--- a/frontend_app/web/manifest.json
+++ b/frontend_app/web/manifest.json
@@ -1,11 +1,11 @@
 {
-    "name": "my_ai_app",
-    "short_name": "my_ai_app",
+    "name": "SmartFit AI",
+    "short_name": "SmartFit AI",
     "start_url": ".",
     "display": "standalone",
-    "background_color": "#0175C2",
-    "theme_color": "#0175C2",
-    "description": "A new Flutter project.",
+    "background_color": "#FDFBF7",
+    "theme_color": "#059669",
+    "description": "Kế hoạch ăn uống món Việt và tập luyện tại nhà 3 ngày.",
     "orientation": "portrait-primary",
     "prefer_related_applications": false,
     "icons": [
```

### Task 5 — Cổng kiểm tra F05

```bash
cd frontend_app
plutil -lint ios/Runner/Info.plist
xmllint --noout android/app/src/main/AndroidManifest.xml android/app/src/main/res/*/*.xml
flutter analyze && flutter test                 # +89: All tests passed!
flutter build apk --debug                       # ✓ Built build/app/outputs/flutter-apk/app-debug.apk
flutter build web --dart-define=API_BASE_URL=http://localhost:3000   # ✓ Built build/web
```
