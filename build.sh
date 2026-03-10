#!/bin/bash
set -e

APP_NAME="KeyStroke"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BUNDLE_ID="com.keystroke.app"

# Clean previous build
rm -rf "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp Resources/Info.plist "$APP_BUNDLE/Contents/"

# Compile
swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    -framework AppKit \
    -framework Carbon \
    -framework SwiftUI \
    -swift-version 5 \
    -target arm64-apple-macos13.0 \
    Sources/*.swift

# Strip extended attributes & ad-hoc code sign (required for stable Accessibility permission)
xattr -cr "$APP_BUNDLE"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"
