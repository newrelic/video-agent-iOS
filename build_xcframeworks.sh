#!/bin/bash

# Build XCFrameworks for New Relic Video Agent iOS
# Creates universal XCFrameworks for iOS and tvOS platforms

set -e

# Configuration
CONFIGURATION="Release"
BUILD_DIR="./build"
XCFRAMEWORK_DIR="./XCFrameworks"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🏗️ Building New Relic Video Agent XCFrameworks${NC}"

# Clean and setup directories
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR" "$XCFRAMEWORK_DIR"
mkdir -p "$BUILD_DIR" "$XCFRAMEWORK_DIR"

# Build function
build_framework() {
    local PROJECT=$1
    local SCHEME=$2
    local SDK=$3
    local ARCH=$4
    
    echo -e "${YELLOW}📱 Building $SCHEME for $SDK...${NC}"
    
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -sdk "$SDK" \
        -archivePath "$BUILD_DIR/$SCHEME-$SDK.xcarchive" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        ONLY_ACTIVE_ARCH=NO \
        ARCHS="$ARCH" \
        -quiet
}

# Build NewRelicVideoCore
echo -e "${GREEN}🎯 Building NewRelicVideoCore...${NC}"
cd NewRelicVideoCore

build_framework "NewRelicVideoCore.xcodeproj" "iOS NewRelicVideoCore" "iphoneos" "arm64"
build_framework "NewRelicVideoCore.xcodeproj" "iOS NewRelicVideoCore" "iphonesimulator" "arm64 x86_64"
build_framework "NewRelicVideoCore.xcodeproj" "tvOS NewRelicVideoCore" "appletvos" "arm64"
build_framework "NewRelicVideoCore.xcodeproj" "tvOS NewRelicVideoCore" "appletvsimulator" "arm64 x86_64"

echo -e "${YELLOW}📦 Creating NewRelicVideoCore.xcframework...${NC}"
xcodebuild -create-xcframework \
    -framework "../$BUILD_DIR/iOS NewRelicVideoCore-iphoneos.xcarchive/Products/Library/Frameworks/NewRelicVideoCore.framework" \
    -framework "../$BUILD_DIR/iOS NewRelicVideoCore-iphonesimulator.xcarchive/Products/Library/Frameworks/NewRelicVideoCore.framework" \
    -framework "../$BUILD_DIR/tvOS NewRelicVideoCore-appletvos.xcarchive/Products/Library/Frameworks/NewRelicVideoCore.framework" \
    -framework "../$BUILD_DIR/tvOS NewRelicVideoCore-appletvsimulator.xcarchive/Products/Library/Frameworks/NewRelicVideoCore.framework" \
    -output "../$XCFRAMEWORK_DIR/NewRelicVideoCore.xcframework"

cd ..

# Build NRAVPlayerTracker
echo -e "${GREEN}🎯 Building NRAVPlayerTracker...${NC}"
cd NRAVPlayerTracker

build_framework "NRAVPlayerTracker.xcodeproj" "iOS NRAVPlayerTracker" "iphoneos" "arm64"
build_framework "NRAVPlayerTracker.xcodeproj" "iOS NRAVPlayerTracker" "iphonesimulator" "arm64 x86_64"
build_framework "NRAVPlayerTracker.xcodeproj" "tvOS NRAVPlayerTracker" "appletvos" "arm64"
build_framework "NRAVPlayerTracker.xcodeproj" "tvOS NRAVPlayerTracker" "appletvsimulator" "arm64 x86_64"

echo -e "${YELLOW}📦 Creating NRAVPlayerTracker.xcframework...${NC}"
xcodebuild -create-xcframework \
    -framework "../$BUILD_DIR/iOS NRAVPlayerTracker-iphoneos.xcarchive/Products/Library/Frameworks/NRAVPlayerTracker.framework" \
    -framework "../$BUILD_DIR/iOS NRAVPlayerTracker-iphonesimulator.xcarchive/Products/Library/Frameworks/NRAVPlayerTracker.framework" \
    -framework "../$BUILD_DIR/tvOS NRAVPlayerTracker-appletvos.xcarchive/Products/Library/Frameworks/NRAVPlayerTracker.framework" \
    -framework "../$BUILD_DIR/tvOS NRAVPlayerTracker-appletvsimulator.xcarchive/Products/Library/Frameworks/NRAVPlayerTracker.framework" \
    -output "../$XCFRAMEWORK_DIR/NRAVPlayerTracker.xcframework"

cd ..

# Build NRIMATracker (iOS only - Google IMA doesn't support tvOS)
echo -e "${GREEN}🎯 Building NRIMATracker (iOS only)...${NC}"
cd NRIMATracker

build_framework "NRIMATracker.xcodeproj" "NRIMATracker" "iphoneos" "arm64"
build_framework "NRIMATracker.xcodeproj" "NRIMATracker" "iphonesimulator" "arm64 x86_64"

echo -e "${YELLOW}📦 Creating NRIMATracker.xcframework...${NC}"
xcodebuild -create-xcframework \
    -framework "../$BUILD_DIR/NRIMATracker-iphoneos.xcarchive/Products/Library/Frameworks/NRIMATracker.framework" \
    -framework "../$BUILD_DIR/NRIMATracker-iphonesimulator.xcarchive/Products/Library/Frameworks/NRIMATracker.framework" \
    -output "../$XCFRAMEWORK_DIR/NRIMATracker.xcframework"

cd ..

# Clean up build artifacts
echo -e "${YELLOW}🧹 Cleaning up build artifacts...${NC}"
rm -rf "$BUILD_DIR"

# Show results
echo -e "${GREEN}✅ XCFrameworks built successfully!${NC}"
echo -e "${GREEN}📁 XCFrameworks location: $XCFRAMEWORK_DIR${NC}"
ls -la "$XCFRAMEWORK_DIR"
