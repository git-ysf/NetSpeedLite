#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="NetSpeedLite"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/NetSpeedLite-macOS.zip"

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SOURCES=(
    "$SCRIPT_DIR/Sources/Theme.swift"
    "$SCRIPT_DIR/Sources/NetworkMonitor.swift"
    "$SCRIPT_DIR/Sources/SparklineView.swift"
    "$SCRIPT_DIR/Sources/PopoverViewController.swift"
    "$SCRIPT_DIR/Sources/AppDelegate.swift"
    "$SCRIPT_DIR/Sources/main.swift"
)

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "[1/4] Compiling arm64 slice..."
swiftc -O -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target arm64-apple-macos12.0 \
    -framework AppKit \
    -framework Foundation \
    -framework ServiceManagement \
    "${SOURCES[@]}" \
    -o "$BUILD_DIR/${APP_NAME}-arm64"

echo "[2/4] Compiling x86_64 slice..."
swiftc -O -whole-module-optimization \
    -sdk "$SDK_PATH" \
    -target x86_64-apple-macos12.0 \
    -framework AppKit \
    -framework Foundation \
    -framework ServiceManagement \
    "${SOURCES[@]}" \
    -o "$BUILD_DIR/${APP_NAME}-x86_64"

echo "[3/4] Creating universal binary & app bundle..."
lipo -create \
    "$BUILD_DIR/${APP_NAME}-arm64" \
    "$BUILD_DIR/${APP_NAME}-x86_64" \
    -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

rm -f "$BUILD_DIR/${APP_NAME}-arm64" "$BUILD_DIR/${APP_NAME}-x86_64"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE" || true
fi

echo "[4/4] Packaging $ZIP_PATH..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "Done:"
echo "  App: $APP_BUNDLE"
echo "  Zip: $ZIP_PATH"
lipo -info "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
