#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
PROJECT_PATH="$SCRIPT_DIR/NetSpeedLite.xcodeproj"

cd "$SCRIPT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
    echo "[1/3] Generating Xcode project via XcodeGen..."
    xcodegen generate --spec "$SCRIPT_DIR/project.yml"
elif [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: xcodegen not found and NetSpeedLite.xcodeproj does not exist."
    echo "Install xcodegen (brew install xcodegen) and re-run ./build_ios.sh."
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "[2/3] Building for iOS Simulator (arm64 + x86_64)..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme NetSpeedLite \
    -configuration Release \
    -sdk iphonesimulator \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    build

echo "[3/3] Building unsigned iOS device archive..."
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme NetSpeedLite \
    -configuration Release \
    -sdk iphoneos \
    -archivePath "$BUILD_DIR/NetSpeedLite.xcarchive" \
    CODE_SIGNING_ALLOWED=NO \
    archive

APP_PATH="$BUILD_DIR/NetSpeedLite.xcarchive/Products/Applications/NetSpeedLite.app"
if [ -d "$APP_PATH" ]; then
    mkdir -p "$BUILD_DIR/Payload"
    cp -R "$APP_PATH" "$BUILD_DIR/Payload/"
    (cd "$BUILD_DIR" && zip -qry NetSpeedLite-iOS-unsigned.ipa Payload)
    rm -rf "$BUILD_DIR/Payload"
    echo "Done: $BUILD_DIR/NetSpeedLite-iOS-unsigned.ipa"
fi
