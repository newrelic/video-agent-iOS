#!/usr/bin/env bash
#
# bootstrap-newrelic-video-core.sh
#
# Pre-builds the NewRelicVideoCore.framework for all four SDK / simulator
# combinations so consumer-module schemes (NRAVPlayerTracker, NRIMATracker,
# NRMediaTailorTracker) can link against a usable framework on a fresh
# clone.
#
# Background: NewRelicVideoCore is checked out as a sibling directory of
# this repo's consumer modules. Each tracker's xcodeproj declares a
# framework search path pointing at
# `../NewRelicVideoCore/build/<Configuration>-<sdk>/NewRelicVideoCore.framework`
# but the `build/` directory is gitignored. Running this script populates
# the four .framework variants the consumer modules expect:
#
#   NewRelicVideoCore/build/Debug-iphonesimulator/NewRelicVideoCore.framework
#   NewRelicVideoCore/build/Debug-iphoneos/NewRelicVideoCore.framework
#   NewRelicVideoCore/build/Debug-appletvsimulator/NewRelicVideoCore.framework
#   NewRelicVideoCore/build/Debug-appletvos/NewRelicVideoCore.framework
#
# Run once after cloning. Re-run if you bump the NewRelicVideoCore source.
# Originally surfaced by ios-builder-1 during T01 (2026-06-22) when the
# tvOS scheme could not link without a pre-built artifact.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CORE_PROJECT="${REPO_ROOT}/NewRelicVideoCore/NewRelicVideoCore.xcodeproj"
CORE_BUILD_DIR="${REPO_ROOT}/NewRelicVideoCore/build"

if [[ ! -d "${CORE_PROJECT}" ]]; then
    echo "❌ Cannot find ${CORE_PROJECT}"
    echo "   Run this script from inside the repo, or from any subdir of it."
    exit 1
fi

mkdir -p "${CORE_BUILD_DIR}"

# (scheme, sdk) pairs. Each xcodebuild invocation writes to
# build/<Configuration>-<sdk>/NewRelicVideoCore.framework via SYMROOT.
combos=(
    "iOS NewRelicVideoCore|iphonesimulator"
    "iOS NewRelicVideoCore|iphoneos"
    "tvOS NewRelicVideoCore|appletvsimulator"
    "tvOS NewRelicVideoCore|appletvos"
)

for combo in "${combos[@]}"; do
    scheme="${combo%|*}"
    sdk="${combo#*|}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔧 Building NewRelicVideoCore for: scheme='${scheme}' sdk='${sdk}'"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    xcodebuild \
        -project "${CORE_PROJECT}" \
        -scheme "${scheme}" \
        -sdk "${sdk}" \
        -configuration Debug \
        SYMROOT="${CORE_BUILD_DIR}" \
        CODE_SIGNING_ALLOWED=NO \
        build \
        2>&1 | tail -3
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Bootstrap complete. Frameworks at:"
ls -d "${CORE_BUILD_DIR}"/Debug-* 2>/dev/null | sed 's|^|   |'
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
