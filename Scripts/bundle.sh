#!/bin/bash
# Builds the AppRunner executable and assembles a minimal, ad-hoc-signed
# .app bundle from it. Intended to run on a macOS GitHub Actions runner.
set -euo pipefail

CONFIG="${1:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="AppRunner"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --package-path "$ROOT_DIR"

BIN_PATH="$ROOT_DIR/.build/$CONFIG/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Build output not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "==> Building Now Playing helper (mediaremote-adapter)"
"$ROOT_DIR/Scripts/build-mediaremote-adapter.sh" "$APP_BUNDLE/Contents/Resources" || true

echo "==> Ad-hoc signing"
codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/Resources/AppRunner.entitlements" \
    "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
