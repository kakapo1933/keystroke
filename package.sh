#!/bin/bash
set -e

APP_NAME="KeyStroke"
VERSION="0.2.0"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_DIR="$BUILD_DIR/dmg"

# Step 1: Build the app
echo "📦 Building $APP_NAME..."
bash build.sh

# Step 2: Prepare DMG contents
echo "📀 Creating DMG..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$APP_BUNDLE" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Step 3: Create DMG
rm -f "$BUILD_DIR/$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

# Clean up
rm -rf "$DMG_DIR"

echo ""
echo "✅ DMG created: $BUILD_DIR/$DMG_NAME"
echo ""
echo "Distribution notes:"
echo "  • Users open the DMG and drag KeyStroke.app to Applications"
echo "  • First launch: right-click → Open to bypass Gatekeeper"
echo "  • Grant Accessibility permission when prompted"
