#!/bin/bash

set -e

# Create build directory
mkdir -p build

# (App icon will be copied at the end of the script)

# Build with Swift Package Manager
echo "Building with Swift Package Manager..."
swift build

# If DeVolume.app exists in the project root, use it; otherwise, create a minimal .app bundle from the SPM binary
if [ -d "DeVolume.app" ]; then
    echo "Copying DeVolume.app bundle to build/ directory..."
    rm -rf build/DeVolume.app
    cp -R DeVolume.app build/
else
    # Create a minimal .app bundle from the SPM binary
    echo "Creating minimal .app bundle from SPM build..."
    mkdir -p build/DeVolume.app/Contents/MacOS
    mkdir -p build/DeVolume.app/Contents/Resources
    cp .build/debug/DeVolume build/DeVolume.app/Contents/MacOS/
    cp DeVolume/Info.plist build/DeVolume.app/Contents/
fi

# Ensure Info.plist is present in the final bundle
if [ -f "DeVolume/Info.plist" ]; then
    echo "Copying Info.plist to final bundle..."
    cp DeVolume/Info.plist build/DeVolume.app/Contents/
fi

# Copy app icon if it exists (after bundle is created/copied)
if [ -f "DeVolume/Resources/AppIcon.icns" ]; then
    echo "Adding app icon to final bundle..."
    mkdir -p build/DeVolume.app/Contents/Resources
    cp DeVolume/Resources/AppIcon.icns build/DeVolume.app/Contents/Resources/
fi

echo "Build complete!"

# Create a zip archive for GitHub releases
if [ -f "build/DeVolume.zip" ]; then
    rm build/DeVolume.zip
fi
echo "Zipping build/DeVolume.app to build/DeVolume.zip..."
zip -r build/DeVolume.zip build/DeVolume.app
echo "Zip archive created at build/DeVolume.zip"
