#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$ROOT_DIR/script/build_and_run.sh" --build-only
APP_BUNDLE="$ROOT_DIR/dist/KeyStroke.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")
ARCH=$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/KeyStroke")
DMG_PATH="$ROOT_DIR/dist/KeyStroke-$VERSION-$ARCH.dmg"
DMG_DIR=$(mktemp -d "$ROOT_DIR/build/dmg.XXXXXX")
trap 'rm -rf "$DMG_DIR"' EXIT
cp -R "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"
hdiutil create -volname KeyStroke -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"
echo "DMG created: $DMG_PATH"
echo "Local ad-hoc signature; Developer ID signing and notarization are required for public distribution."
