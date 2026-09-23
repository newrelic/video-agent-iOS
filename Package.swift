// swift-tools-version:5.5
import PackageDescription

// NOTE: url/checksum below are placeholders, not tied to a release yet.
// They are populated automatically by ios-publish.yml as part of the next
// version release - this file does not become resolvable via SPM until then.
//
// NOTE on NRTHEOplayerTracker specifically: this package declares iOS 12/tvOS 12 as its
// overall platform floor, but NRTHEOplayerTracker's real minimum is iOS 13.0 (THEOplayerSDK-core's
// own requirement - see NRTHEOplayerTracker.podspec). SPM's binaryTarget has no per-product
// platform override the way a podspec does, so this can't be expressed in the manifest itself:
// a consumer building below iOS 13 who imports NRTHEOplayerTracker will hit a real deployment-target
// error from Xcode at link time, not from SPM resolution. Not a bug in this file - same limitation
// CocoaPods callers avoid only because the podspec can declare its own floor.
let releaseTag = "v5.0.0"
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
            checksum: "88053ea9b4c8136bf506f18fbc3b88e5b6cb700081109cbb5a0b3f2c590b8c51"
        ),
        .binaryTarget(
            name: "NRAVPlayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRAVPlayerTracker.xcframework.zip",
            checksum: "7294b52e23ce521f084f2384206a46644b460c324d97d9078f2e8cc4514925ad"
        ),
        .binaryTarget(
            name: "NRIMATracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRIMATracker.xcframework.zip",
            checksum: "c93081eb157c4f408afc188c47f61f29de18dbc0ff72bfd2759274037c90fa70"
        ),
        .binaryTarget(
            name: "NRMediaTailorTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRMediaTailorTracker.xcframework.zip",
            checksum: "23fd2603f2098e3277ecb34301a4f5813aaddf61a6d0b753926960b06d751379"
        ),
        .binaryTarget(
            name: "NRTHEOplayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRTHEOplayerTracker.xcframework.zip",
            checksum: "c672f09caeb2ecfcac859a29132db8f829548fc46a233fe5e6427afa642144f0"
        ),
    ]
)
