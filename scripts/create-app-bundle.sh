#!/bin/bash
set -euo pipefail

APP_NAME="Speak2"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# xcodebuild output location (set via -derivedDataPath .derivedData in CI)
DERIVED_DATA="${DERIVED_DATA_PATH:-.derivedData}"
XCODE_PRODUCTS="$DERIVED_DATA/Build/Products/Release"

echo "Creating app bundle..."

# Clean and create directories
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

# Copy executable
cp "$XCODE_PRODUCTS/$APP_NAME" "$MACOS/$APP_NAME"

# Copy resource bundles (MLX metallib lives inside mlx-swift_Cmlx.bundle)
for bundle in "$XCODE_PRODUCTS/"*.bundle; do
    [ -e "$bundle" ] || continue
    echo "  Bundling $(basename "$bundle")"
    cp -R "$bundle" "$RESOURCES/"
done

# Copy Info.plist
cp "Sources/Info.plist" "$CONTENTS/Info.plist"

# Copy Resources (if any exist)
if [ -d "Resources" ] && [ "$(ls -A Resources 2>/dev/null)" ]; then
    cp -R Resources/* "$RESOURCES/"
fi

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "App bundle created at $APP_BUNDLE"
