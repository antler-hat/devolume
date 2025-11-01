#!/bin/bash

set -e

APP_NAME="Ejector"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
PLIST_SRC="Ejector/Info.plist"
PLIST_DEST="$APP_BUNDLE/Contents/Info.plist"

echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
rm -rf ".build"

echo "Building with Swift Package Manager..."
swift build -c release

echo "Creating .app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "Copying executable..."
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

echo "Copying Info.plist..."
cp "$PLIST_SRC" "$PLIST_DEST"

# Copy resources if any exist
if [ -d "Ejector/Resources" ]; then
    echo "Copying resources..."
    cp -R Ejector/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

TARGET_APP=~/Applications/$APP_NAME.app
echo "Installing to ~/Applications..."
if [ -d "$TARGET_APP" ]; then
    echo "Found existing install at $TARGET_APP; replacing it."
    rm -rf "$TARGET_APP"
fi
cp -R "$APP_BUNDLE" ~/Applications/

echo "Build complete! $APP_NAME.app has been installed to ~/Applications/"
