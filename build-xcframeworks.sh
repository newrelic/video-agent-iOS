#!/bin/bash

# Script to build universal XCFrameworks for New Relic Video Agent
# Supports iOS (device + simulator) and tvOS (device + simulator)

set -e

echo "🚀 Starting XCFramework build process (iOS + tvOS)..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build/
rm -rf *.xcframework
mkdir -p build

# Remove old framework dependencies that cause conflicts
echo "🧹 Removing old framework dependencies..."
rm -rf NRAVPlayerTracker/NewRelicVideoCore.framework
rm -rf NRIMATracker/NewRelicVideoCore.framework
rm -rf NRIMATracker/NRAVPlayerTracker.framework

# Download Google IMA SDK if not present
if [ ! -d "NRIMATracker/GoogleInteractiveMediaAds.xcframework" ]; then
    echo "Downloading Google IMA SDK..."

    # Create temporary directory for download
    TEMP_DIR=$(mktemp -d)
    ORIGINAL_DIR=$(pwd)
    cd "$TEMP_DIR"

    # Download the Google IMA SDK (latest version)
    # Using CocoaPods to get the framework
    cat > Podfile <<'EOF'
platform :ios, '12.0'
target 'Temp' do
  use_frameworks!
  pod 'GoogleAds-IMA-iOS-SDK'
end
EOF

    # Set UTF-8 encoding for CocoaPods
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    echo "  📍 Running 'pod install' in $TEMP_DIR"

    # Run pod install with error logging
    if ! pod install 2>&1 | tee pod_install.log; then
        echo "  ❌ Pod install failed. Log output:"
        cat pod_install.log
        cd "$ORIGINAL_DIR"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    echo "  📂 Checking for SDK at: Pods/GoogleAds-IMA-iOS-SDK/"
    ls -la Pods/ 2>&1 || echo "  ⚠️  Pods directory not found"

    # Extract the XCFramework
    if [ -d "Pods/GoogleAds-IMA-iOS-SDK/GoogleInteractiveMediaAds.xcframework" ]; then
        echo "  📦 Found Google IMA SDK XCFramework"
        cp -R "Pods/GoogleAds-IMA-iOS-SDK/GoogleInteractiveMediaAds.xcframework" "$ORIGINAL_DIR/NRIMATracker/"
        echo "  ✅ Google IMA SDK installed"
    else
        echo "  ❌ Failed to download Google IMA SDK"
        echo "  📂 Contents of Pods directory:"
        ls -la Pods/ 2>&1 || echo "Pods directory not found"
        if [ -d "Pods/GoogleAds-IMA-iOS-SDK" ]; then
            echo "  📂 Contents of GoogleAds-IMA-iOS-SDK:"
            ls -la Pods/GoogleAds-IMA-iOS-SDK/
        fi
        cd "$ORIGINAL_DIR"
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    # Clean up
    cd "$ORIGINAL_DIR"
    rm -rf "$TEMP_DIR"
fi

# Function to build for a specific platform
build_framework() {
    local framework=$1
    local scheme=$2
    local sdk=$3
    local archive_name=$4
    shift 4
    local extra_flags="$@"

    echo "  📦 Building $framework for $sdk..."

    if [ -z "$extra_flags" ]; then
        xcodebuild archive \
            -project "$framework/$framework.xcodeproj" \
            -scheme "$scheme" \
            -configuration Release \
            -sdk "$sdk" \
            -archivePath "build/$archive_name.xcarchive" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            CODE_SIGNING_ALLOWED=NO \
            > /dev/null 2>&1
    else
        eval "xcodebuild archive \
            -project \"$framework/$framework.xcodeproj\" \
            -scheme \"$scheme\" \
            -configuration Release \
            -sdk \"$sdk\" \
            -archivePath \"build/$archive_name.xcarchive\" \
            SKIP_INSTALL=NO \
            BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
            CODE_SIGNING_ALLOWED=NO \
            $extra_flags \
            > /dev/null 2>&1"
    fi

    echo "  ✅ Built $framework for $sdk"
}

# Function to setup dependency framework for a target
setup_dependency() {
    local target_dir=$1
    local dep_framework=$2
    local sdk=$3

    if [ "$sdk" == "iphoneos" ]; then
        cp -R "build/$dep_framework-ios-device.xcarchive/Products/Library/Frameworks/$dep_framework.framework" "$target_dir/"
    elif [ "$sdk" == "iphonesimulator" ]; then
        cp -R "build/$dep_framework-ios-simulator.xcarchive/Products/Library/Frameworks/$dep_framework.framework" "$target_dir/"
    elif [ "$sdk" == "appletvos" ]; then
        cp -R "build/$dep_framework-tvos-device.xcarchive/Products/Library/Frameworks/$dep_framework.framework" "$target_dir/"
    elif [ "$sdk" == "appletvsimulator" ]; then
        cp -R "build/$dep_framework-tvos-simulator.xcarchive/Products/Library/Frameworks/$dep_framework.framework" "$target_dir/"
    fi
}

# Function to build complete framework with all platforms
build_complete_framework() {
    local framework=$1
    local ios_scheme=$2
    local tvos_scheme=$3
    local depends_on=$4

    echo ""
    echo "🔨 Building $framework..."

    # Get absolute path for framework search
    local project_root="$(pwd)"

    # Build iOS Device
    if [ -n "$ios_scheme" ]; then
        if [ -n "$depends_on" ]; then
            rm -rf "$framework/$depends_on.framework" 2>/dev/null
            setup_dependency "$framework" "$depends_on" "iphoneos"
        fi
        local extra_flags=""
        if [ -n "$depends_on" ]; then
            extra_flags="FRAMEWORK_SEARCH_PATHS=\"\\\$(inherited) $project_root/$framework\""
        fi
        build_framework "$framework" "$ios_scheme" "iphoneos" "$framework-ios-device" "$extra_flags"
        rm -rf "$framework/$depends_on.framework" 2>/dev/null
    fi

    # Build iOS Simulator
    if [ -n "$ios_scheme" ]; then
        if [ -n "$depends_on" ]; then
            rm -rf "$framework/$depends_on.framework" 2>/dev/null
            setup_dependency "$framework" "$depends_on" "iphonesimulator"
        fi
        local extra_flags=""
        if [ -n "$depends_on" ]; then
            extra_flags="FRAMEWORK_SEARCH_PATHS=\"\\\$(inherited) $project_root/$framework\""
        fi
        build_framework "$framework" "$ios_scheme" "iphonesimulator" "$framework-ios-simulator" "$extra_flags"
        rm -rf "$framework/$depends_on.framework" 2>/dev/null
    fi

    # Build tvOS Device (if scheme exists)
    if [ -n "$tvos_scheme" ]; then
        if [ -n "$depends_on" ]; then
            rm -rf "$framework/$depends_on.framework" 2>/dev/null
            setup_dependency "$framework" "$depends_on" "appletvos"
        fi
        local extra_flags=""
        if [ -n "$depends_on" ]; then
            extra_flags="FRAMEWORK_SEARCH_PATHS=\"\\\$(inherited) $project_root/$framework\""
        fi
        build_framework "$framework" "$tvos_scheme" "appletvos" "$framework-tvos-device" "$extra_flags"
        rm -rf "$framework/$depends_on.framework" 2>/dev/null
    fi

    # Build tvOS Simulator (if scheme exists)
    if [ -n "$tvos_scheme" ]; then
        if [ -n "$depends_on" ]; then
            rm -rf "$framework/$depends_on.framework" 2>/dev/null
            setup_dependency "$framework" "$depends_on" "appletvsimulator"
        fi
        local extra_flags=""
        if [ -n "$depends_on" ]; then
            extra_flags="FRAMEWORK_SEARCH_PATHS=\"\\\$(inherited) $project_root/$framework\""
        fi
        build_framework "$framework" "$tvos_scheme" "appletvsimulator" "$framework-tvos-simulator" "$extra_flags"
        rm -rf "$framework/$depends_on.framework" 2>/dev/null
    fi

    # Create XCFramework
    echo "  🎁 Creating XCFramework..."

    XCFRAMEWORK_ARGS=()

    if [ -n "$ios_scheme" ]; then
        XCFRAMEWORK_ARGS+=(-framework "build/$framework-ios-device.xcarchive/Products/Library/Frameworks/$framework.framework")
        XCFRAMEWORK_ARGS+=(-framework "build/$framework-ios-simulator.xcarchive/Products/Library/Frameworks/$framework.framework")
    fi

    if [ -n "$tvos_scheme" ]; then
        XCFRAMEWORK_ARGS+=(-framework "build/$framework-tvos-device.xcarchive/Products/Library/Frameworks/$framework.framework")
        XCFRAMEWORK_ARGS+=(-framework "build/$framework-tvos-simulator.xcarchive/Products/Library/Frameworks/$framework.framework")
    fi

    xcodebuild -create-xcframework \
        "${XCFRAMEWORK_ARGS[@]}" \
        -output "$framework.xcframework" \
        > /dev/null 2>&1

    echo "  ✅ $framework.xcframework created successfully!"
}

# Build NewRelicVideoCore first (it's the base dependency)
build_complete_framework "NewRelicVideoCore" "iOS NewRelicVideoCore" "tvOS NewRelicVideoCore" ""

# Build NRAVPlayerTracker (depends on NewRelicVideoCore)
build_complete_framework "NRAVPlayerTracker" "iOS NRAVPlayerTracker" "tvOS NRAVPlayerTracker" "NewRelicVideoCore"

# Build NRIMATracker (depends on NewRelicVideoCore) - iOS only
build_complete_framework "NRIMATracker" "NRIMATracker" "" "NewRelicVideoCore"

# Clean up Google IMA SDK after building NRIMATracker
if [ -d "NRIMATracker/GoogleInteractiveMediaAds.xcframework" ]; then
    echo "🧹 Cleaning up Google IMA SDK..."
    rm -rf NRIMATracker/GoogleInteractiveMediaAds.xcframework
fi

echo ""
echo "🎉 All XCFrameworks built successfully!"
echo ""
echo "📦 Output:"
ls -lh *.xcframework
echo ""
echo "📍 XCFrameworks location: $(pwd)"
echo ""
echo "✨ Supported platforms:"
echo "   - iOS Device (arm64)"
echo "   - iOS Simulator (arm64 + x86_64)"
echo "   - tvOS Device (arm64)"
echo "   - tvOS Simulator (arm64 + x86_64)"
echo ""
echo "Note: NRIMATracker is iOS-only (Google IMA SDK doesn't support tvOS)"
echo ""
echo "🔍 To verify architectures:"
echo "   find NewRelicVideoCore.xcframework -name 'NewRelicVideoCore' -type f -exec lipo -info {} \\;"

echo ""
# Group all .xcframeworks in a folder called xcframeworks
mkdir -p xcframeworks
mv *.xcframework xcframeworks/

# Zip the xcframeworks folder
zip -rq xcframeworks.zip xcframeworks

# Remove the folder and .xcframeworks
rm -rf xcframeworks
