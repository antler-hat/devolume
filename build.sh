#!/bin/bash

set -e

echo "Cleaning previous build..."
rm -rf build/DeVolume.app build/DeVolume build/DeVolume.zip

# Create build directory
mkdir -p build

# Compile the application as a GUI app using swiftc
echo "Compiling DeVolume as a macOS GUI app..."
swiftc -sdk $(xcrun --show-sdk-path --sdk macosx) \
    -target arm64-apple-macosx10.13 \
    -o build/DeVolume \
    DeVolume/Sources/Models/*.swift \
    DeVolume/Sources/ViewControllers/*.swift \
    DeVolume/Sources/AppDelegate.swift \
    DeVolume/Sources/main.swift \
    -import-objc-header DeVolume/Sources/DeVolume-Bridging-Header.h

# Create application bundle structure
echo "Creating application bundle..."
mkdir -p build/DeVolume.app/Contents/MacOS
mkdir -p build/DeVolume.app/Contents/Resources

# Copy the compiled binary
cp build/DeVolume build/DeVolume.app/Contents/MacOS/DeVolume

# Copy Info.plist
cp DeVolume/Info.plist build/DeVolume.app/Contents/Info.plist

# Copy app icon if it exists
if [ -f "DeVolume/Resources/AppIcon.icns" ]; then
    cp DeVolume/Resources/AppIcon.icns build/DeVolume.app/Contents/Resources/
fi

# Copy entitlements if present
if [ -f "DeVolume/Resources/DeVolume.entitlements" ]; then
    cp DeVolume/Resources/DeVolume.entitlements build/DeVolume.app/Contents/Resources/
fi

echo "Build complete!"

# Create a zip archive for GitHub releases
if [ -f "build/DeVolume.zip" ]; then
    rm build/DeVolume.zip
fi
echo "Zipping build/DeVolume.app to build/DeVolume.zip..."
zip -r build/DeVolume.zip build/DeVolume.app
echo "Zip archive created at build/DeVolume.zip"
