#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--settings|settings|--build-only|build|--install|install|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  *) echo "usage: $0 [run|--settings|--build-only|--install|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="KeyStroke"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
PLIST="$ROOT_DIR/Resources/Info.plist"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")
MIN_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")
ARCH="${KEYSTROKE_ARCH:-$(uname -m)}"
case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;; esac

mkdir -p "$DIST_DIR" "$ROOT_DIR/build/module-cache"
STAGING=$(mktemp -d "$DIST_DIR/.build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
STAGED_APP="$STAGING/$APP_NAME.app"
mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$PLIST" "$STAGED_APP/Contents/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$STAGED_APP/Contents/Resources/"
swiftc \
  -module-cache-path "$ROOT_DIR/build/module-cache" \
  -o "$STAGED_APP/Contents/MacOS/$APP_NAME" \
  -framework AppKit -framework Carbon -framework SwiftUI \
  -swift-version 5 -target "$ARCH-apple-macos$MIN_SYSTEM_VERSION" \
  "$ROOT_DIR"/Sources/*.swift
xattr -cr "$STAGED_APP"
codesign --force --sign - --identifier "$BUNDLE_ID" "$STAGED_APP"
codesign --verify --strict "$STAGED_APP"

# A failed compile leaves the previous build and running app intact.
case "$MODE" in
  --build-only|build|--install|install) ;;
  *) pkill -x "$APP_NAME" >/dev/null 2>&1 || true ;;
esac
rm -rf "$APP_BUNDLE"
mv "$STAGED_APP" "$APP_BUNDLE"
echo "Built $APP_BUNDLE ($ARCH)"

open_app() { /usr/bin/open -n "$APP_BUNDLE" "$@"; }
case "$MODE" in
  --build-only|build) ;;
  --install|install)
    # Keep the previous installation as a recoverable sibling until the swap succeeds.
    INSTALL_STAGE=$(mktemp -d "/Applications/.KeyStroke-install.XXXXXX")
    /usr/bin/ditto "$APP_BUNDLE" "$INSTALL_STAGE/$APP_NAME.app"
    codesign --verify --strict "$INSTALL_STAGE/$APP_NAME.app"
    if [[ -e "/Applications/$APP_NAME.app" ]]; then
      mv "/Applications/$APP_NAME.app" "$INSTALL_STAGE/Previous-$APP_NAME.app"
    fi
    if ! mv "$INSTALL_STAGE/$APP_NAME.app" "/Applications/$APP_NAME.app"; then
      if [[ -e "$INSTALL_STAGE/Previous-$APP_NAME.app" ]]; then
        mv "$INSTALL_STAGE/Previous-$APP_NAME.app" "/Applications/$APP_NAME.app"
      fi
      exit 1
    fi
    echo "Installed /Applications/$APP_NAME.app; previous copy (if any): $INSTALL_STAGE"
    ;;
  --settings|settings) open_app --args --settings ;;
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs|logs|--telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null
    echo "$APP_NAME process launched (keyboard permission and UI require separate verification)"
    ;;
esac
