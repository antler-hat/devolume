#!/bin/bash

set -e

# Create build directory
mkdir -p build

# Copy app icon if it exists
if [ -f "DeVolume/Resources/AppIcon.icns" ]; then
    echo "Adding app icon..."
    mkdir -p build/DeVolume.app/Contents/Resources
    cp DeVolume/Resources/AppIcon.icns build/DeVolume.app/Contents/Resources/
fi


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

echo "Build complete!"
