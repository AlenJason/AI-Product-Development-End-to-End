#!/bin/bash
# Vẽ lại icon SmartFit AI và chép đủ kích thước cho Android, iOS, macOS, Windows, web (PLAN 6.8). Chạy trên macOS
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
# Windows: một file .ico gồm nhiều kích thước (thanh tác vụ, Explorer, tiêu đề cửa sổ).
tmp=$(mktemp -d)
for size in 16 24 32 48 64 128 256; do resize "$full" "$size" "$tmp/$size.png"; done
swift tool/make_ico.swift windows/runner/resources/app_icon.ico "$tmp"/{16,24,32,48,64,128,256}.png
rm -rf "$tmp"

echo "Đã cập nhật icon."
