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
let releaseTag = "v4.4.0"
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
            checksum: "0294fc1909814e6ed3805476e3ffd9a028ea88de3221a27ddaeed268c931cccc"
        ),
        .binaryTarget(
            name: "NRAVPlayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRAVPlayerTracker.xcframework.zip",
            checksum: "e27daa0263ce428640f132a24fbd30ba4b870c5feb3aa52597c7849fd1afc947"
        ),
        .binaryTarget(
            name: "NRIMATracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRIMATracker.xcframework.zip",
            checksum: "1c04cfa1b28f0c32716c3ae70acc1bb58740dbed13d85ce2bcca705f765908f4"
        ),
        .binaryTarget(
            name: "NRMediaTailorTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRMediaTailorTracker.xcframework.zip",
            checksum: "4840ce33e9c2f1d1376375945967701fe35a65da443aa621c34ba107873882ae"
        ),
        .binaryTarget(
            name: "NRTHEOplayerTracker",
            url: "\(releaseBaseURL)/\(releaseTag)/NRTHEOplayerTracker.xcframework.zip",
            checksum: "0000000000000000000000000000000000000000000000000000000000000000"
        ),
    ]
)
