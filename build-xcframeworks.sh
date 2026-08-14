#!/bin/bash

# Script to build universal XCFrameworks for New Relic Video Agent
# Supports iOS (device + simulator) and tvOS (device + simulator)

set -e

echo "Starting XCFramework build process (iOS + tvOS)..."

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf build/
rm -rf *.xcframework
mkdir -p build

# Remove old framework dependencies that cause conflicts
echo "Removing old framework dependencies..."
rm -rf NRAVPlayerTracker/NewRelicVideoCore.framework
rm -rf NRIMATracker/NewRelicVideoCore.framework
rm -rf NRIMATracker/NRAVPlayerTracker.framework
rm -rf NRIMATracker/GoogleInteractiveMediaAds.xcframework

# Download a Google IMA SDK variant (iOS or tvOS) into a holding directory under build/,
# so NRIMATracker's per-platform build steps can swap in the correct one.
# tvOS note: the current Google IMA tvOS SDK (GoogleAds-IMA-tvOS-SDK) only ships real
# device+simulator slices from ~> 4.17.0 onward, which requires tvOS 15.0+ - higher than
# this repo's overall tvOS 12.0 baseline. That's a real constraint of Google's SDK, not
# something this script can work around, so NRIMATracker's tvOS target is pinned to
# tvOS 15.0 (see NRIMATracker.xcodeproj) even though the rest of the SDK targets tvOS 12.0.
download_google_ima_sdk() {
    local platform=$1          # ios | tvos
    local min_deployment=$2    # e.g. 12.0 or 15.0
    local pod_name=$3          # GoogleAds-IMA-iOS-SDK | GoogleAds-IMA-tvOS-SDK
    local version_constraint=$4 # e.g. '' or "~> 4.17.0"
    local dest="build/GoogleInteractiveMediaAds-${platform}.xcframework"

    if [ -d "$dest" ]; then
        return 0
    fi

    echo "Downloading Google IMA SDK for $platform..."

    local temp_dir
    temp_dir=$(mktemp -d)
    local original_dir="$(pwd)"
    cd "$temp_dir"

    {
        echo "platform :${platform}, '${min_deployment}'"
        echo "install! 'cocoapods', :integrate_targets => false"
        echo "use_frameworks!"
        if [ -n "$version_constraint" ]; then
            echo "pod '${pod_name}', '${version_constraint}'"
        else
            echo "pod '${pod_name}'"
        fi
    } > Podfile

    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    echo "Running 'pod install' in $temp_dir"

    if ! pod install 2>&1 | tee pod_install.log; then
        echo "Pod install failed for $pod_name. Log output:"
        cat pod_install.log
        cd "$original_dir"
        rm -rf "$temp_dir"
        exit 1
    fi

    if [ -d "Pods/${pod_name}/GoogleInteractiveMediaAds.xcframework" ]; then
        echo "Found Google IMA SDK XCFramework for $platform"
        mkdir -p "$original_dir/build"
        cp -R "Pods/${pod_name}/GoogleInteractiveMediaAds.xcframework" "$original_dir/$dest"
    else
        echo "Failed to download Google IMA SDK for $platform"
        echo "Contents of Pods directory:"
        ls -la Pods/ 2>&1 || echo "Pods directory not found"
        cd "$original_dir"
        rm -rf "$temp_dir"
        exit 1
    fi

    cd "$original_dir"
    rm -rf "$temp_dir"
}

# Function to build for a specific platform
build_framework() {
    local framework=$1
    local scheme=$2
    local sdk=$3
    local archive_name=$4
    shift 4
    local extra_flags="$@"

    echo "Building $framework for $sdk..."

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

    echo "Built $framework for $sdk"
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

# Swap in the correct platform's Google IMA SDK xcframework for NRIMATracker's build.
# Needed because a single xcframework can't hold arbitrary third-party slices the way
# our own archived frameworks do - each platform's build needs its own copy in place.
setup_google_ima_sdk() {
    local target_dir=$1
    local sdk=$2

    rm -rf "$target_dir/GoogleInteractiveMediaAds.xcframework"

    if [ "$sdk" == "iphoneos" ] || [ "$sdk" == "iphonesimulator" ]; then
        cp -R "build/GoogleInteractiveMediaAds-ios.xcframework" "$target_dir/GoogleInteractiveMediaAds.xcframework"
    elif [ "$sdk" == "appletvos" ] || [ "$sdk" == "appletvsimulator" ]; then
        cp -R "build/GoogleInteractiveMediaAds-tvos.xcframework" "$target_dir/GoogleInteractiveMediaAds.xcframework"
    fi
}

# Function to build complete framework with all platforms
build_complete_framework() {
    local framework=$1
    local ios_scheme=$2
    local tvos_scheme=$3
    local depends_on=$4
    local needs_google_ima=$5   # "true" for NRIMATracker, empty otherwise

    echo ""
    echo "Building $framework..."

    # Get absolute path for framework search
    local project_root="$(pwd)"

    # Build iOS Device
    if [ -n "$ios_scheme" ]; then
        if [ -n "$depends_on" ]; then
            rm -rf "$framework/$depends_on.framework" 2>/dev/null
            setup_dependency "$framework" "$depends_on" "iphoneos"
        fi
        if [ "$needs_google_ima" == "true" ]; then
            setup_google_ima_sdk "$framework" "iphoneos"
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
        if [ "$needs_google_ima" == "true" ]; then
            setup_google_ima_sdk "$framework" "iphonesimulator"
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
        if [ "$needs_google_ima" == "true" ]; then
            setup_google_ima_sdk "$framework" "appletvos"
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
        if [ "$needs_google_ima" == "true" ]; then
            setup_google_ima_sdk "$framework" "appletvsimulator"
        fi
        local extra_flags=""
        if [ -n "$depends_on" ]; then
            extra_flags="FRAMEWORK_SEARCH_PATHS=\"\\\$(inherited) $project_root/$framework\""
        fi
        build_framework "$framework" "$tvos_scheme" "appletvsimulator" "$framework-tvos-simulator" "$extra_flags"
        rm -rf "$framework/$depends_on.framework" 2>/dev/null
    fi

    if [ "$needs_google_ima" == "true" ]; then
        rm -rf "$framework/GoogleInteractiveMediaAds.xcframework"
    fi

    # Create XCFramework
    echo "Creating XCFramework..."

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

    echo "$framework.xcframework created successfully!"
}

# Google IMA SDK - iOS variant (used by NRIMATracker's iOS build)
download_google_ima_sdk "ios" "12.0" "GoogleAds-IMA-iOS-SDK" ""

# Google IMA SDK - tvOS variant (used by NRIMATracker's tvOS build)
# Pinned to ~> 4.17.0: this is the first version confirmed to ship real tvOS
# device+simulator slices, and it requires tvOS 15.0+ (see NRIMATracker.xcodeproj).
download_google_ima_sdk "tvos" "15.0" "GoogleAds-IMA-tvOS-SDK" "~> 4.17.0"

# Build NewRelicVideoCore first (it's the base dependency)
build_complete_framework "NewRelicVideoCore" "iOS NewRelicVideoCore" "tvOS NewRelicVideoCore" "" ""

# Build NRAVPlayerTracker (depends on NewRelicVideoCore)
build_complete_framework "NRAVPlayerTracker" "iOS NRAVPlayerTracker" "tvOS NRAVPlayerTracker" "NewRelicVideoCore" ""

# Build NRIMATracker (depends on NewRelicVideoCore + Google IMA SDK)
build_complete_framework "NRIMATracker" "iOS NRIMATracker" "tvOS NRIMATracker" "NewRelicVideoCore" "true"

# Build NRMediaTailorTracker (depends on NewRelicVideoCore) - iOS + tvOS
build_complete_framework "NRMediaTailorTracker" "NRMediaTailorTracker-iOS" "NRMediaTailorTracker-tvOS" "NewRelicVideoCore"

echo ""
echo "All XCFrameworks built successfully!"
echo ""
echo "Output:"
ls -lh *.xcframework
echo ""
echo "XCFrameworks location: $(pwd)"
echo ""
echo "Supported platforms:"
echo "   - iOS Device (arm64)"
echo "   - iOS Simulator (arm64 + x86_64)"
echo "   - tvOS Device (arm64)"
echo "   - tvOS Simulator (arm64 + x86_64)"
echo ""
echo "Note: NRIMATracker's tvOS build targets tvOS 15.0+ (Google IMA SDK requirement)."
echo "      The rest of this SDK targets tvOS 12.0 - this is a deliberate, narrower floor"
echo "      for IMA ad-tracking on tvOS specifically, not a change to the overall baseline."
echo ""
echo "To verify architectures:"
echo "   find NewRelicVideoCore.xcframework -name 'NewRelicVideoCore' -type f -exec lipo -info {} \\;"

echo ""
# Per-tracker zips, for SPM (each product independently resolvable) - additive,
# does not change the combined xcframeworks.zip below, which the existing manual
# "Install via XCFrameworks" README option continues to rely on unchanged.
for fw in NewRelicVideoCore NRAVPlayerTracker NRIMATracker; do
    zip -rq "${fw}.xcframework.zip" "${fw}.xcframework"
done
echo "Per-tracker zips created: NewRelicVideoCore.xcframework.zip, NRAVPlayerTracker.xcframework.zip, NRIMATracker.xcframework.zip"

# Group all .xcframeworks in a folder called xcframeworks
mkdir -p xcframeworks
mv *.xcframework xcframeworks/
zip -rq xcframeworks.zip xcframeworks
