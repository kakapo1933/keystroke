#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="KeyStroke"
BUNDLE_ID="com.keystroke.app"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"

build_app() {
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_MACOS" "$APP_RESOURCES"
  cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/"

  swiftc \
    -o "$APP_BINARY" \
    -framework AppKit \
    -framework Carbon \
    -framework SwiftUI \
    -swift-version 5 \
    -target arm64-apple-macos13.0 \
    "$ROOT_DIR"/Sources/*.swift

  chmod +x "$APP_BINARY"
  xattr -cr "$APP_BUNDLE"
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --build-only|build)
    echo "Built $APP_BUNDLE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched"
    ;;
  *)
    echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
