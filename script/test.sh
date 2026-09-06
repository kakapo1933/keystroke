#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/build/tests" "$ROOT_DIR/build/module-cache"
XCODE_PLATFORM=$(xcrun --show-sdk-platform-path)
swiftc -module-cache-path "$ROOT_DIR/build/module-cache" \
  -F "$XCODE_PLATFORM/Developer/Library/Frameworks" \
  -I "$XCODE_PLATFORM/Developer/usr/lib" -L "$XCODE_PLATFORM/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$XCODE_PLATFORM/Developer/usr/lib" \
  -Xlinker -rpath -Xlinker "$XCODE_PLATFORM/Developer/Library/Frameworks" \
  -framework XCTest -framework AppKit -framework Carbon -framework SwiftUI \
  -swift-version 5 \
  "$ROOT_DIR/Sources/KeyDisplayToken.swift" "$ROOT_DIR/Sources/KeystrokeEntry.swift" \
  "$ROOT_DIR/Sources/KeyMapper.swift" "$ROOT_DIR/Sources/KeystrokePreferences.swift" \
  "$ROOT_DIR/Sources/KeystrokeViewModel.swift" "$ROOT_DIR/Sources/MonitoringController.swift" \
  "$ROOT_DIR/Sources/AppLog.swift" "$ROOT_DIR/Tests/main.swift" \
  -o "$ROOT_DIR/build/tests/KeystrokeTests"
"$ROOT_DIR/build/tests/KeystrokeTests"
bash -n "$ROOT_DIR/build.sh" "$ROOT_DIR/package.sh" "$ROOT_DIR/script/build_and_run.sh" "$ROOT_DIR/script/test.sh"
plutil -lint "$ROOT_DIR/Resources/Info.plist"
