#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/Resources/AppIcon.svg"
ICONSET="$ROOT_DIR/Resources/AppIcon.iconset"
ICNS="$ROOT_DIR/Resources/AppIcon.icns"

if ! command -v magick >/dev/null 2>&1; then
  echo "ImageMagick 'magick' is required to render $SRC" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render_icon() {
  local pixels="$1"
  local name="$2"
  magick -background none "$SRC" -resize "${pixels}x${pixels}" -depth 8 "PNG32:$ICONSET/$name"
}

render_icon 16 "icon_16x16.png"
render_icon 32 "icon_16x16@2x.png"
render_icon 32 "icon_32x32.png"
render_icon 64 "icon_32x32@2x.png"
render_icon 128 "icon_128x128.png"
render_icon 256 "icon_128x128@2x.png"
render_icon 256 "icon_256x256.png"
render_icon 512 "icon_256x256@2x.png"
render_icon 512 "icon_512x512.png"
render_icon 1024 "icon_512x512@2x.png"

swift "$ROOT_DIR/script/make_icns.swift" "$ICONSET" "$ICNS"
echo "Generated $ICNS"
