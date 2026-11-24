#!/bin/bash
set -e

echo "==> Downloading Flutter SDK..."
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

echo "==> Building Flutter Web Release..."
./_flutter/bin/flutter build web --release

echo "==> Build finished successfully!"
