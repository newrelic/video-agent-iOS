[![Community Project header](https://github.com/newrelic/opensource-website/raw/master/src/images/categories/Community_Project.png)](https://opensource.newrelic.com/oss-category/#community-project)

# New Relic Video Agent for iOS & tvOS

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The New Relic Video Agent for iOS & tvOS provides comprehensive video analytics for Apple platform applications using AVPlayer. Track video events, monitor playback quality, identify errors, and gain deep insights into user engagement and performance — for both iPhone/iPad and Apple TV.

## Features

- **Automatic Event Detection** — Captures AVPlayer lifecycle events automatically without manual instrumentation
- **QoE Metrics** — Quality of Experience aggregation for startup time, buffering ratio, bitrate, and playback errors
- **Event Segregation** — Organized event types: `VideoAction`, `VideoAdAction`, `VideoErrorAction`, `VideoCustomAction`
- **IMA Ads Support** — Built-in Google IMA SDK ad tracking via dedicated ad tracker
- **tvOS Support** — Auto-detection of Apple TV with optimized harvest cycles
- **Multi-Player Support** — Track multiple simultaneous video players in the same application
- **Easy Integration** — XCFrameworks, CocoaPods, or manual source import

## Table of Contents

- [Installation](#installation)
  - [Option 1: XCFrameworks (Recommended)](#option-1-install-via-xcframeworks-recommended)
  - [Option 2: CocoaPods](#option-2-install-via-cocoapods)
  - [Option 3: Manual Build](#option-3-install-manually-using-source-code)
- [Prerequisites](#prerequisites)
- [Modules](#modules)
- [Usage](#usage)
- [Best Practices](#best-practices)
- [Configuration Options](#configuration-options)
- [API Reference](#api-reference)
- [Data Model](#data-model)
- [Support](#support)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Option 1: Install via XCFrameworks (Recommended)

Download the latest pre-built XCFrameworks from the [Releases](https://github.com/newrelic/video-agent-iOS/releases/latest) page. Look for `XCFrameworks.zip`, extract it, and drag the `.xcframework` files into your Xcode project under **Frameworks, Libraries, and Embedded Content**, set to **"Embed & Sign"**.

### Option 2: Install via CocoaPods

Add the dependencies to your `Podfile`:

```ruby
pod 'NewRelicVideoAgent'
pod 'NRAVPlayerTracker'
pod 'NRIMATracker'   # Optional — only if using Google IMA ads
```

Then run:

```bash
pod install
```

> **Note:** Replace with the desired [release version](https://github.com/newrelic/video-agent-iOS/releases) if pinning.

### Option 3: Install Manually Using Source Code

1. Clone this repo.
2. In Xcode, go to **File > Add Files to "YourProject"**.
3. Select the module directory and click **Add**.
4. Repeat for each module you need.

For more details on all installation methods, see [INSTALLATION.md](INSTALLATION.md).

## Prerequisites

Before using the Video Agent, ensure you have:

- **New Relic Account** — Active account with a valid application token
- **New Relic iOS Agent** — [Installed and configured](https://docs.newrelic.com/docs/mobile-monitoring/new-relic-mobile-ios/installation/spm-installation) in your project
- **AVFoundation** — Available by default on iOS 12+ / tvOS 12+
- **Google IMA SDK** (optional) — Required only if tracking IMA ads
- **Minimum Deployment Target** — iOS 12.0 / tvOS 12.0 or higher

## Modules

The Video Agent is composed of three modules:

| Module | Description | Required |
|--------|-------------|----------|
| **NewRelicVideoCore** | Base classes for tracker management, event generation, and data harvesting. Depends on the New Relic iOS Agent. | Yes |
| **NRAVPlayerTracker** | Video tracker for AVPlayer. Automatically hooks into player lifecycle events via KVO and notifications. | Yes (for AVPlayer) |
| **NRIMATracker** | Ad tracker for the Google IMA SDK. Captures ad lifecycle events including quartiles, breaks, and errors. | Optional |

## Usage

### Getting Your Application Token

Before initializing the Video Agent, obtain your application token:

1. Log in to [one.newrelic.com](https://one.newrelic.com)
2. Navigate to the Streaming Video & Ads onboarding flow
3. Copy your `applicationToken`

### Basic Setup — AVPlayer Only

<details>
<summary>Objective-C</summary>
<p>

```objc
// Step 1: Initialize NRVAVideo in AppDelegate
NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEW_RELIC_TOKEN"]
    withDebugLogging:YES]
    build];
[[[NRVAVideo newBuilder] withConfiguration:config] build];

// Step 2: Register your player in your ViewController
NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
    initWithPlayerName:@"MainVideoPlayer"
    player:yourAVPlayer
    adEnabled:NO
    customAttributes:@{@"contentTitle": @"My Video Title"}];
NSInteger trackerId = [NRVAVideo addPlayer:playerConfig];

// Step 3 (Optional): Release the tracker when done
- (void)dealloc {
    [NRVAVideo releaseTracker:trackerId];
}
```

</p>
</details>

<details>
<summary>Swift</summary>
<p>

```swift
// Step 1: Initialize NRVAVideo in AppDelegate
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEW_RELIC_TOKEN")
    .withDebugLogging(true)
    .build()
NRVAVideo.newBuilder().with(configuration: config).build()

// Step 2: Register your player in your ViewController
let playerConfig = NRVAVideoPlayerConfiguration(
    playerName: "MainVideoPlayer",
    player: yourAVPlayer,
    adEnabled: false,
    customAttributes: ["contentTitle": "My Video Title"]
)
let trackerId = NRVAVideo.addPlayer(playerConfig)

// Step 3 (Optional): Release the tracker when done
deinit {
    NRVAVideo.releaseTracker(trackerId)
}
```

</p>
</details>

### Setup with AVPlayer and IMA Ads

<details>
<summary>Objective-C</summary>
<p>

```objc
// Step 1: Initialize NRVAVideo (same as above)

// Step 2: Register the player with ads enabled
NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
    initWithPlayerName:@"MainVideoPlayer"
    player:yourAVPlayer
    adEnabled:YES
    customAttributes:nil];
NSInteger trackerId = [NRVAVideo addPlayer:playerConfig];

// Step 3: Wire up the IMA ad tracker
NRIMATracker *adTracker = (NRIMATracker *)[NRVAVideo adTrackerForId:trackerId];
// Pass adTracker to your IMA ads loader setup
```

</p>
</details>

<details>
<summary>Swift</summary>
<p>

```swift
// Step 1: Initialize NRVAVideo (same as above)

// Step 2: Register the player with ads enabled
let playerConfig = NRVAVideoPlayerConfiguration(
    playerName: "MainVideoPlayer",
    player: yourAVPlayer,
    adEnabled: true,
    customAttributes: nil
)
let trackerId = NRVAVideo.addPlayer(playerConfig)

// Step 3: Wire up the IMA ad tracker
let adTracker = NRVAVideo.adTracker(forId: trackerId) as? NRIMATracker
// Pass adTracker to your IMA ads loader setup
```

</p>
</details>

For comprehensive setup instructions and additional examples, see the [Developer Onboarding Guide](ONBOARDING.md).

## Best Practices

### 1. Setting `contentTitle`

For best results, explicitly set the content title during player configuration:

```swift
let playerConfig = NRVAVideoPlayerConfiguration(
    playerName: "MainVideoPlayer",
    player: yourAVPlayer,
    adEnabled: false,
    customAttributes: ["contentTitle": "My Video Title"]
)
```

### 2. Setting `userId`

Set a user identifier to track video analytics per user:

```swift
// Set userId globally across all trackers
NRVAVideo.setUserId("user-12345")
```

### 3. Adding Custom Attributes

Add custom attributes to improve data aggregation and analysis:

```swift
let customAttrs: [String: Any] = [
    "contentTitle": videoMetadata.title,
    "subscriptionTier": "premium",
    "contentProvider": "studio-abc",
    "region": "us-west-2",
    "cdnProvider": "cloudflare"
]

let playerConfig = NRVAVideoPlayerConfiguration(
    playerName: "MainVideoPlayer",
    player: yourAVPlayer,
    adEnabled: false,
    customAttributes: customAttrs
)
```

You can also set attributes after initialization:

```swift
// String
NRVAVideo.setAttribute("contentSeries", value: "Season 1", trackerId: trackerId)

// Number / Bool
NRVAVideo.setAttribute("contentResolution", value: 1080, trackerId: trackerId)
NRVAVideo.setAttribute("isDVR", value: true, trackerId: trackerId)

// Date — automatically converted to epoch seconds
NRVAVideo.setAttribute("sessionStart", value: Date(), trackerId: trackerId)

// Set global attribute across all trackers
NRVAVideo.setGlobalAttribute("appVersion", value: "2.1.0")
```

**Use these attributes in New Relic queries:**

```sql
-- Analyze by subscription tier
SELECT count(*) FROM VideoAction WHERE actionName = 'CONTENT_START'
FACET subscriptionTier SINCE 1 day ago

-- Monitor by region
SELECT average(contentPlayhead) FROM VideoAction
FACET region SINCE 1 hour ago
```

### 4. Gradual Rollout with Feature Flags

When deploying to production, use feature flags to enable the tracker gradually:

```swift
let rolloutPercentage = 5 // Start with 5% of users

let shouldEnable = (userId.hashValue % 100) < rolloutPercentage

if shouldEnable {
    let config = NRVAVideoConfiguration.builder()
        .withApplicationToken("YOUR_NEW_RELIC_TOKEN")
        .withHarvestCycle(300) // 5 minutes
        .build()
    NRVAVideo.newBuilder().with(configuration: config).build()
}
```

**Recommended Rollout Schedule:**

| Phase | Percentage | Duration | Validation |
|-------|-----------|----------|------------|
| Initial | 5% | 2–3 days | Verify data flowing to New Relic |
| Early | 15% | 3–5 days | Check data quality and performance |
| Expansion | 25% | 5–7 days | Validate across device types |
| Majority | 50% | 1–2 weeks | Monitor at scale |
| Full | 100% | Ongoing | Complete deployment |

## Configuration Options

### NRVAVideoConfiguration

| Builder Method | Type | Default | Description |
|----------------|------|---------|-------------|
| `withApplicationToken(_:)` | `String` | — | **Required.** Your New Relic application token. |
| `withHarvestCycle(_:)` | `Int` | 300 (Mobile) / 180 (TV) | Interval in seconds between data harvests. |
| `withDebugLogging(_:)` | `Bool` | `false` | Enable debug logging for development. |
| `withQoeAggregateEnabled(_:)` | `Bool` | `true` | QoE aggregation is enabled out of the box. Disable with `withQoeAggregateEnabled(NO)`. |
| `withQoeAggregateIntervalMultiplier(_:)` | `Int` | `2` | Multiplier applied to the harvest interval for QoE aggregation. Configure with `withQoeAggregateIntervalMultiplier:`. |

### NRVAVideoPlayerConfiguration

| Parameter | Type | Description |
|-----------|------|-------------|
| `playerName` | `String` | Unique identifier for the video player. |
| `player` | `AVPlayer` | The AVPlayer instance to track. |
| `adEnabled` | `Bool` | Set `true` if the player uses an IMA ads loader; `false` otherwise. |
| `customAttributes` | `[String: Any]?` | Custom attributes to attach to all events from this player. |

### Custom Attribute Limits

Limits for custom attributes added to default mobile events:

- **Attributes:** 128 maximum
- **String attributes:** 4 KB maximum length (empty string values are not accepted)

### Accepted Attribute Value Types

| Type | Behaviour | Example |
|------|-----------|---------|
| `NSString` / `String` | Stored as-is | `"premium"` |
| `NSNumber` / `Int`, `Double`, `Bool` | Stored as-is | `@(1080)`, `true` |
| `NSDate` / `Date` | Converted to epoch seconds (`NSNumber`) | `NSDate.now` |
| `NSArray` / `Array` | Stored recursively; invalid elements are dropped | `@[@"hls", @(4)]` |
| `NSDictionary` / `[String: Any]` | Stored recursively; entries with non-string keys or invalid values are dropped | `@{@"cdn": @"cloudflare"}` |
| `NSNull` | Stored as JSON `null` | `[NSNull null]` |
| Anything else (`NSURL`, `NSData`, custom objects…) | **Dropped** with an error log; key is not stored | — |

> **Note:** There are special keywords reserved for default attributes documented in [DATAMODEL.md](./DATAMODEL.md). Do not use these as custom attribute names, as they will be dropped by the agent.

### Live Stream Configuration

For live streams, the agent automatically uses a shorter harvest cycle (30–60 seconds) for near-real-time data transmission.

## API Reference

### `NRVAVideo` (Primary API)

#### `NRVAVideo.addPlayer(_:)`
Register a player with the Video Agent. Returns a `trackerId` for future reference.

```swift
let trackerId = NRVAVideo.addPlayer(playerConfig)
```

#### `NRVAVideo.releaseTracker(_:)`
Release a tracker when the player is destroyed.

```swift
NRVAVideo.releaseTracker(trackerId)
```

#### `NRVAVideo.setUserId(_:)`
Set a unique identifier for the current user across all trackers.

```swift
NRVAVideo.setUserId("user-12345")
```

#### `NRVAVideo.setAttribute(_:value:trackerId:)`
Set a custom attribute on a specific content tracker.

```swift
NRVAVideo.setAttribute("contentSeries", value: "Season 1", trackerId: trackerId)
```

#### `NRVAVideo.setGlobalAttribute(_:value:)`
Set a custom attribute across all active trackers.

```swift
NRVAVideo.setGlobalAttribute("appVersion", value: "2.1.0")
```

#### `NRVAVideo.recordCustomEvent(_:)`
Record a custom event across all trackers.

```swift
NRVAVideo.recordCustomEvent([
    "actionName": "VideoBookmarked",
    "bookmarkPosition": player.currentTime().seconds
])
```

## Data Model

The Video Agent captures comprehensive video analytics across four event types:

- **VideoAction** — Playback lifecycle events (request, start, pause, resume, buffer, seek, rendition changes, heartbeats)
- **VideoAdAction** — Ad lifecycle events (request, start, end, quartiles, breaks, clicks)
- **VideoErrorAction** — Error events (playback failures, ad errors, crashes)
- **VideoCustomAction** — Custom events defined by your application

**Full Documentation:** See [DATAMODEL.md](./DATAMODEL.md) for the complete event and attribute reference, and [Advanced Topics](advanced.md) for creating custom trackers.

## Obfuscation Rules

Obfuscation rules let you mask sensitive data before it is transmitted to New Relic.

Each rule is a regex pattern paired with a replacement string. Rules are applied **in order** to every string attribute value in every outgoing event — including QoE events and crash-recovered events.

### Configuration

**Objective-C**
```objc
NRVAVideoConfiguration *config = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEW_RELIC_TOKEN"]
    withObfuscationRules:@[
        @{ @"regex": @"account-\\d+",  @"replacement": @"ACCOUNT_ID" },
        @{ @"regex": @"token=[^&\"]+", @"replacement": @"token=REDACTED" },
    ]]
    build];
[[[NRVAVideo newBuilder] withConfiguration:config] build];
```

**Swift**
```swift
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEW_RELIC_TOKEN")
    .withObfuscationRules([
        ["regex": "account-\\d+",  "replacement": "ACCOUNT_ID"],
        ["regex": "token=[^&\"]+", "replacement": "token=REDACTED"],
    ])
    .build()
NRVAVideo.newBuilder().with(configuration: config).build()
```

### How it works

- Rules are applied per string attribute value, not on the raw JSON payload — numeric and boolean attributes are unaffected.
- All rules run against every outgoing event (regular, live, QoE, and crash-recovered).
- Rules are evaluated **in the order they are declared**. If two rules can match the same value, order matters.
- The `applicationToken` and HTTP auth headers are never touched — obfuscation only runs on event attribute values.

### Edge cases

| Scenario | Behavior |
|---|---|
| No rules configured | No-op; zero performance overhead |
| Empty `replacement` string | Matched content is deleted (this is intentional and allowed) |
| Invalid regex pattern | `withObfuscationRules:` throws `NSInvalidArgumentException` at configuration time — fail fast before any events are sent |
| Non-string attribute value (number, bool) | Skipped; only string values are processed |
| Malformed rules array entry (not a dictionary) | Entry is skipped with a warning log |
| `applicationToken` / auth headers | Never included in event attributes; not affected |
| Rule ordering | Rules apply in array order — document this to your team if order matters |
| Catastrophic backtracking | `NSRegularExpression` has no built-in timeout on iOS. Avoid patterns with unbounded quantifier nesting (e.g. `(a+)+`). Test rules against worst-case inputs before deploying. |

## Documentation

To generate source code documentation using [appledoc](https://github.com/tomaz/appledoc):

```bash
appledoc --project-name NewRelicVideoAgent --project-company "New Relic Inc." --company-id com.newrelic --create-html --no-create-docset --output ./docs NewRelicVideoCore/NewRelicVideoCore/**/*.h
```

Then open `docs/html/index.html` in your preferred browser. The source code annotations are also compatible with Doxygen.

## Examples

The `Examples` folder contains all usage examples. The `Test` folder contains the test apps.

## Support

Should you need assistance with New Relic products, you are in good hands with several support channels.

If the issue has been confirmed as a bug or is a feature request, please file a GitHub issue.

### Support Channels

- [New Relic Documentation](https://docs.newrelic.com): Comprehensive guidance for using our platform
- [New Relic Community](https://discuss.newrelic.com): The best place to engage in troubleshooting questions
- [New Relic University](https://learn.newrelic.com): A range of online training for New Relic users of every level
- [New Relic Technical Support](https://support.newrelic.com): 24/7/365 ticketed support. Read more about our [Technical Support Offerings](https://docs.newrelic.com/docs/licenses/license-information/general-usage-licenses/support-plan)

## Contributing

We encourage your contributions to improve the New Relic Video Agent for iOS & tvOS! Keep in mind that when you submit your pull request, you'll need to sign the CLA via the click-through using CLA-Assistant. You only have to sign the CLA one time per project.

If you have any questions, or to execute our corporate CLA (which is required if your contribution is on behalf of a company), drop us an email at opensource@newrelic.com.

For more details on how best to contribute, see [CONTRIBUTING.md](./CONTRIBUTING.md).

### A note about vulnerabilities

As noted in our [security policy](../../security/policy), New Relic is committed to the privacy and security of our customers and their data. We believe that providing coordinated disclosure by security researchers and engaging with the security community are important means to achieve our security goals.

If you believe you have found a security vulnerability in this project or any of New Relic's products or websites, we welcome and greatly appreciate you reporting it to New Relic through our [bug bounty program](https://docs.newrelic.com/docs/security/security-privacy/information-security/report-security-vulnerabilities/).

To all contributors, we thank you! Without your contribution, this project would not be what it is today.

## License

The New Relic Video Agent for iOS & tvOS is licensed under the [Apache 2.0](http://apache.org/licenses/LICENSE-2.0.txt) License.
