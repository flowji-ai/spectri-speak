#!/bin/bash
set -euo pipefail

APP_NAME="Speak2"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

# xcodebuild output location (set via -derivedDataPath .derivedData in CI)
DERIVED_DATA="${DERIVED_DATA_PATH:-.derivedData}"
XCODE_PRODUCTS="$DERIVED_DATA/Build/Products/Release"

echo "Creating app bundle..."

# Clean and create directories
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$FRAMEWORKS"

# Copy executable
cp "$XCODE_PRODUCTS/$APP_NAME" "$MACOS/$APP_NAME"

# Copy PackageFrameworks (contains MLX metallib and other framework bundles)
if [ -d "$XCODE_PRODUCTS/PackageFrameworks" ]; then
    cp -R "$XCODE_PRODUCTS/PackageFrameworks/"*.framework "$FRAMEWORKS/" 2>/dev/null || true
fi

# Copy Info.plist
cp "Sources/Info.plist" "$CONTENTS/Info.plist"

# Copy Resources (if any exist)
if [ -d "Resources" ] && [ "$(ls -A Resources 2>/dev/null)" ]; then
    cp -R Resources/* "$RESOURCES/"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "App bundle created at $APP_BUNDLE"
