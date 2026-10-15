// swift-tools-version:5.5
import PackageDescription

// NOTE: url/checksum below are placeholders, not tied to a release yet.
// They are populated automatically by ios-publish.yml as part of the next
// version release - this file does not become resolvable via SPM until then.
//
// NOTE on NRTHEOplayerTracker specifically: this package declares iOS 12/tvOS 12 as its
// overall platform floor, but NRTHEOplayerTracker's real minimum is iOS 15.0 (THEOplayerSDK-core
// 11.x's own requirement - see NRTHEOplayerTracker.podspec). SPM's binaryTarget has no per-product
// platform override the way a podspec does, so this can't be expressed in the manifest itself:
// a consumer building below iOS 15 who imports NRTHEOplayerTracker will hit a real deployment-target
// error from Xcode at link time, not from SPM resolution. Not a bug in this file - same limitation
// CocoaPods callers avoid only because the podspec can declare its own floor.
let releaseTag = "v5.1.0"
let releaseBaseURL = "https://github.com/newrelic/video-agent-iOS/releases/download"

let package = Package(
    name: "video-agent-iOS",
    platforms: [.iOS(.v12), .tvOS(.v12)],
    products: [
        .library(name: "NewRelicVideoCore", targets: ["NewRelicVideoCore"]),
        .library(name: "NRAVPlayerTracker", targets: ["NRAVPlayerTracker"]),
        .library(name: "NRIMATracker", targets: ["NRIMATracker"]),
        .library(name: "NRMediaTailorTracker", targets: ["NRMediaTailorTracker"]),
        .library(name: "NRTHEOplayerTracker", targets: ["NRTHEOplayerTracker"]),
    ],
    targets: [
        .binaryTarget(
            name: "NewRelicVideoCore",
            url: "\(releaseBaseURL)/\(releaseTag)/NewRelicVideoCore.xcframework.zip",
            checksum: "833c76f60f22d9db7ef82604840d68c1d7cd486e5bc3c61080028e728938d086"
        ),
        .binaryTarget(
            name: "NRAVPlayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRAVPlayerTracker.xcframework.zip",
            checksum: "869068f5d15fccdf5c73a230591c690ed84fe080e49b054cba3d8bdb51d39cbc"
        ),
        .binaryTarget(
            name: "NRIMATracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRIMATracker.xcframework.zip",
            checksum: "91bc79066f89c9a5efa3581f25609b13e108c8dfccd70a7e0505d7909acd9bf1"
        ),
        .binaryTarget(
            name: "NRMediaTailorTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRMediaTailorTracker.xcframework.zip",
            checksum: "f8a3fe567affaeae637f1fcfa60915ea07e4bfd0076d8d3a31ed69829ca05304"
        ),
        .binaryTarget(
            name: "NRTHEOplayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRTHEOplayerTracker.xcframework.zip",
            checksum: "f61a5ef5503e913c55b85f5212a81f3900eaa5bde9e6978df1a4aeb101361604"
        ),
    ]
)
