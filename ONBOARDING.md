# New Relic Video Agent iOS - Developer Onboarding Guide

## Overview

The New Relic Video Agent for iOS provides comprehensive video analytics and monitoring capabilities with minimal integration effort. This guide covers everything you need to get started with video tracking for both simple video playback and ad-enabled scenarios.

## Installation

See [INSTALLATION.md](INSTALLATION.md) for detailed installation instructions using either:

- **CocoaPods** (recommended)
- **XCFramework** (binary distribution)

## Dependencies

**Required for all methods:**

- iOS 12.0+ or tvOS 12.0+
- Xcode 12.0+

**Additional for IMA Ad Tracking:**

- Google Interactive Media Ads SDK (automatically handled by CocoaPods)

## Import Statements

### Objective-C

```objective-c
#import <NewRelicVideoCore/NewRelicVideoCore.h>
```

### Swift

```swift
import NewRelicVideoCore
```

## Quick Start

### 1. AppDelegate Setup (Required)

#### Objective-C

In your `AppDelegate.m`:

```objectivec
#import <NewRelicVideoCore/NewRelicVideoCore.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize New Relic Video Agent with automatic optimization
    NRVAVideoConfiguration *videoConfig = [[[[[NRVAVideoConfiguration builder]
        withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
        withHarvestCycle:60]
        withDebugLogging:YES]
        build];

    [[[NRVAVideo newBuilder] withConfiguration:videoConfig] build];

    return YES;
}
```

#### Swift

In your `AppDelegate.swift`:

```swift
import UIKit
import NewRelicVideoCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize New Relic Video Agent with automatic optimization
        let videoConfig = NRVAVideoConfiguration.builder()
            .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
            .withHarvestCycle(60)
            .withDebugLogging(true)
            .build()

        NRVAVideo.newBuilder()
            .withConfiguration(videoConfig)
            .build()

        return true
    }
}
```

**🆕 Fully Automatic Detection:**

- **TV Platform Detection** - Automatically detects Apple TV vs iOS and applies optimal settings
- **Memory Optimization** - Automatically enables memory optimization on low-memory devices (< 2GB RAM)
- **User Agent Tagging** - Automatically adds `;TV` or `;LowMem` tags to user agent
- **No manual calls needed** - Everything happens automatically during configuration creation

**Configuration Options:**

- `withApplicationToken:` - Your New Relic application token (required)
- `withHarvestCycle:` - Data harvest interval in seconds (default: 30)
- `withDebugLogging:` - Enable debug logs (recommended for development)

### Advanced Configuration Options

For production and performance optimization, you can configure additional options:

#### Objective-C

```objectivec
NRVAVideoConfiguration *advancedConfig = [[[[[[[[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withHarvestCycle:30]                    // Regular harvest cycle (5-300 seconds)
    withLiveHarvestCycle:10]                // Live content harvest cycle (1-60 seconds)
    withRegularBatchSize:64 * 1024]         // Regular content batch size (64KB default)
    withLiveBatchSize:32 * 1024]            // Live content batch size (32KB default)
    withMaxDeadLetterSize:100]              // Failed request queue size (10-1000)
    withMaxOfflineStorageSize:100]          // Offline storage limit in MB (10-1000MB)
    withCollectorAddress:@"mobile-collector.newrelic.com"] // Custom collector domain (optional)
    withMemoryOptimization:NO]              // Enable for low-memory devices
    forTVOS:NO]                             // Enable tvOS optimizations
    withDebugLogging:YES]                   // Debug logging
    build];
```

#### Swift

```swift
let advancedConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withHarvestCycle(30)                    // Regular harvest cycle (5-300 seconds)
    .withLiveHarvestCycle(10)                // Live content harvest cycle (1-60 seconds)
    .withRegularBatchSize(64 * 1024)         // Regular content batch size (64KB default)
    .withLiveBatchSize(32 * 1024)            // Live content batch size (32KB default)
    .withMaxDeadLetterSize(100)              // Failed request queue size (10-1000)
    .withMaxOfflineStorageSize(100)          // Offline storage limit in MB (10-1000MB)
    .withCollectorAddress("mobile-collector.newrelic.com") // Custom collector domain (optional)
    .withMemoryOptimization(false)           // Enable for low-memory devices
    .forTVOS(false)                          // Enable tvOS optimizations
    .withDebugLogging(true)                  // Debug logging
    .build()
```

**Complete Configuration Reference:**

| Option                       | Type       | Default       | Range         | Description                            |
| ---------------------------- | ---------- | ------------- | ------------- | -------------------------------------- |
| `withApplicationToken:`      | NSString\* | _(required)_  | -             | Your New Relic application token       |
| `withHarvestCycle:`          | NSInteger  | 300 (5 min)   | 5-300 seconds | How often to send regular content data |
| `withLiveHarvestCycle:`      | NSInteger  | 30            | 1-60 seconds  | How often to send live content data    |
| `withRegularBatchSize:`      | NSInteger  | 65,536 (64KB) | 1KB-1MB       | Batch size for regular content uploads |
| `withLiveBatchSize:`         | NSInteger  | 32,768 (32KB) | 512B-512KB    | Batch size for live content uploads    |
| `withMaxDeadLetterSize:`     | NSInteger  | 100           | 10-1000       | Failed request queue capacity          |
| `withMaxOfflineStorageSize:` | NSInteger  | 100           | > 0 MB        | Maximum offline storage size limit     |
| `withCollectorAddress:`      | NSString\* | auto-detected | -             | Custom collector domain for /connect and /data endpoints |
| `withMemoryOptimization:`    | BOOL       | NO            | YES/NO        | Optimize for low-memory devices        |
| `forTVOS:`                   | BOOL       | auto-detected | YES/NO        | Enable Apple TV optimizations          |
| `withDebugLogging:`          | BOOL       | NO            | YES/NO        | Enable detailed debug logging          |

## Automatic Detection & Override Examples

### Understanding Auto-Detection Behavior

The New Relic Video Agent automatically detects your device capabilities and applies optimal settings. Here's how it works and how you can override when needed.

#### Example 1: Pure Auto-Detection (Recommended)

**Objective-C:**

```objectivec
// ✅ SIMPLEST SETUP - Everything automatic
NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withDebugLogging:YES]  // Optional: Enable logging to see what was detected
    build];
```

**Swift:**

```swift
// ✅ SIMPLEST SETUP - Everything automatic
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withDebugLogging(true)  // Optional: Enable logging to see what was detected
    .build()
```

**What happens automatically:**

- **iPhone/iPad (Standard Memory)**: harvestCycle=300s, batchSize=64KB
- **iPhone/iPad (Low Memory < 2GB)**: harvestCycle=60s, batchSize=32KB
- **Apple TV**: harvestCycle=180s, batchSize=128KB
- **User Agent**: Automatically tagged with `;TV` or `;LowMem`

#### Example 2: Override Harvest Cycle (Keep Other Auto-Settings)

**Objective-C:**

```objectivec
// Device: Apple TV detected (auto: 180s harvest, 128KB batch)
// Want: Faster harvest but keep TV batch sizes
NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withHarvestCycle:60]                    // Override: 60s instead of 180s
    build];

// Result: harvestCycle=60s, regularBatchSize=128KB (mixed auto+override)
```

**Swift:**

```swift
// Device: Apple TV detected (auto: 180s harvest, 128KB batch)
// Want: Faster harvest but keep TV batch sizes
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withHarvestCycle(60)                    // Override: 60s instead of 180s
    .build()

// Result: harvestCycle=60s, regularBatchSize=128KB (mixed auto+override)
```

**Debug Output:**

```
[DEBUG] Auto-detected: Apple TV platform
[DEBUG] Applied TV optimizations: harvest=180s, batch=128KB
[DEBUG] Override: harvestCycle set to 60s
[DEBUG] Final config: harvest=60s, batch=128KB, isTV=YES
```

#### Example 3: Override Memory Optimization

**Objective-C:**

```objectivec
// Device: Low memory detected (auto: 60s harvest, 32KB batch)
// Want: High performance despite low memory
NRVAVideoConfiguration *config = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withMemoryOptimization:NO]              // Override: Disable memory optimization
    withHarvestCycle:30]                    // Override: Fast harvest
    withRegularBatchSize:128 * 1024]        // Override: Large batches
    build];

// Result: All overridden - acts like high-end device
```

**Swift:**

```swift
// Device: Low memory detected (auto: 60s harvest, 32KB batch)
// Want: High performance despite low memory
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withMemoryOptimization(false)              // Override: Disable memory optimization
    .withHarvestCycle(30)                    // Override: Fast harvest
    .withRegularBatchSize(128 * 1024)        // Override: Large batches
    .build()

// Result: All overridden - acts like high-end device
```

#### Example 4: Force TV Mode on iOS Device

**Objective-C:**

```objectivec
// Device: iPhone detected (auto: standard settings)
// Want: Use TV optimizations for testing
NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    forTVOS:YES]                           // Override: Force TV mode
    build];

// Result: iPhone with TV settings (180s harvest, 128KB batch)
```

**Swift:**

```swift
// Device: iPhone detected (auto: standard settings)
// Want: Use TV optimizations for testing
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .forTVOS(true)                           // Override: Force TV mode
    .build()

// Result: iPhone with TV settings (180s harvest, 128KB batch)
```

#### Example 5: Completely Custom Configuration

**Objective-C:**

```objectivec
// Ignore all auto-detection, use completely custom settings
NRVAVideoConfiguration *config = [[[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    forTVOS:NO]                            // Override: Force non-TV
    withMemoryOptimization:NO]             // Override: Force non-memory-optimized
    withHarvestCycle:45]                   // Override: Custom harvest
    withLiveHarvestCycle:8]                // Override: Custom live harvest
    withRegularBatchSize:96 * 1024]        // Override: Custom batch size
    withLiveBatchSize:48 * 1024]           // Override: Custom live batch size
    build];

// Result: Completely custom configuration, auto-detection ignored
```

**Swift:**

```swift
// Ignore all auto-detection, use completely custom settings
let config = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .forTVOS(false)                            // Override: Force non-TV
    .withMemoryOptimization(false)             // Override: Force non-memory-optimized
    .withHarvestCycle(45)                   // Override: Custom harvest
    .withLiveHarvestCycle(8)                // Override: Custom live harvest
    .withRegularBatchSize(96 * 1024)        // Override: Custom batch size
    .withLiveBatchSize(48 * 1024)           // Override: Custom live batch size
    .build()

// Result: Completely custom configuration, auto-detection ignored
```

## Video Player Integration

### Option 1: Simple Video Player (No Ads)

For basic video playback without advertisements:

#### Objective-C Implementation

```objectivec
#import <NewRelicVideoCore/NewRelicVideoCore.h>
@import AVKit;

@interface ViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerViewController *playerController;
@property (nonatomic, assign) NSInteger trackerId;
@end

@implementation ViewController

- (void)playVideo:(NSString *)videoURL {
    // Create your AVPlayer
    NSURL *url = [NSURL URLWithString:videoURL];
    self.player = [AVPlayer playerWithURL:url];

    // Setup player controller
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = self.player;
    self.playerController.showsPlaybackControls = YES;

    // ✅ CONFIGURATION-BASED SETUP
    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"MainVideoPlayer"
        player:self.player
        adEnabled:NO
        customAttributes:@{
            @"videoTitle": @"Sample Video",
            @"category": @"Entertainment",
            @"videoURL": videoURL
        }];

    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    // Present player
    [self presentViewController:self.playerController animated:YES completion:^{
        [self.player play];
    }];
}

- (void)dealloc {
    // Clean up tracking when done
    [NRVAVideo releaseTracker:@(self.trackerId)];
}

@end
```

#### Swift Implementation

```swift
import UIKit
import AVFoundation
import AVKit
import NewRelicVideoCore

class ViewController: UIViewController {
    private var player: AVPlayer?
    private var playerController: AVPlayerViewController?
    private var trackerId: Int = 0

    func playVideo(videoURL: String) {
        // Create your AVPlayer
        guard let url = URL(string: videoURL) else { return }
        player = AVPlayer(url: url)

        // Setup player controller
        playerController = AVPlayerViewController()
        playerController?.player = player
        playerController?.showsPlaybackControls = true

        // ✅ CONFIGURATION-BASED SETUP
        let playerConfig = NRVAVideoPlayerConfiguration(
            playerName: "MainVideoPlayer",
            player: player!,
            adEnabled: false,
            customAttributes: [
                "videoTitle": "Sample Video",
                "category": "Entertainment",
                "videoURL": videoURL
            ]
        )

        trackerId = NRVAVideo.addPlayer(playerConfig)

        // Present player
        if let playerVC = playerController {
            present(playerVC, animated: true) {
                self.player?.play()
            }
        }
    }

    deinit {
        // Clean up tracking when done
        NRVAVideo.releaseTracker(trackerId)
    }
}
```

### Option 2: Video Player with Ads

For video playback with Google IMA advertisements:

#### Objective-C Implementation

```objectivec
#import <NewRelicVideoCore/NewRelicVideoCore.h>
@import AVKit;
@import GoogleInteractiveMediaAds;

@interface ViewController () <IMAAdsLoaderDelegate, IMAAdsManagerDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerViewController *playerController;
@property (nonatomic, strong) IMAAdsLoader *adsLoader;
@property (nonatomic, strong) IMAAdsManager *adsManager;
@property (nonatomic, strong) IMAAVPlayerContentPlayhead *contentPlayhead;
@property (nonatomic, assign) NSInteger trackerId;
@end

@implementation ViewController

- (void)playVideo:(NSString *)videoURL {
    // Create your AVPlayer
    NSURL *url = [NSURL URLWithString:videoURL];
    self.player = [AVPlayer playerWithURL:url];

    // Setup player controller
    self.playerController = [[AVPlayerViewController alloc] init];
    self.playerController.player = self.player;
    self.playerController.showsPlaybackControls = YES;

    // ✅ CONFIGURATION-BASED SETUP WITH ADS
    NSString *adTagURL = @"https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator=";

    NRVAVideoPlayerConfiguration *playerConfig = [[NRVAVideoPlayerConfiguration alloc]
        initWithPlayerName:@"MainVideoPlayer"
        player:self.player
        adEnabled:YES
        customAttributes:@{
            @"videoTitle": @"Sample Video with Ads",
            @"category": @"Entertainment",
            @"videoURL": videoURL,
            @"adTagURL": adTagURL
        }];

    self.trackerId = [NRVAVideo addPlayer:playerConfig];

    // ✅ GLOBAL custom event (trackerId = nil sends to ALL trackers)
    [NRVAVideo recordCustomEvent:@"PLAYER_SETUP_COMPLETE"
                      trackerId:nil
                     attributes:@{
                         @"setupMethod": @"configuration-based",
                         @"hasAds": @YES
                     }];

    // ✅ TRACKER-SPECIFIC custom event (enriched with video attributes)
    [NRVAVideo recordCustomEvent:@"VIDEO_READY"
                      trackerId:@(self.trackerId)
                     attributes:@{
                         @"videoURL": videoURL,
                         @"hasAds": @YES
                     }];

    // Setup IMA ads
    [self setupAds];

    // Present player
    [self presentViewController:self.playerController animated:YES completion:^{
        [self.player play];
        [self requestAds:adTagURL];
    }];
}

- (void)setupAds {
    self.contentPlayhead = [[IMAAVPlayerContentPlayhead alloc] initWithAVPlayer:self.player];
    self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
    self.adsLoader.delegate = self;
}

- (void)requestAds:(NSString *)adTagURL {
    IMAAdDisplayContainer *adDisplayContainer = [[IMAAdDisplayContainer alloc]
        initWithAdContainer:self.playerController.view
        viewController:self.playerController];

    IMAAdsRequest *request = [[IMAAdsRequest alloc]
        initWithAdTagUrl:adTagURL
        adDisplayContainer:adDisplayContainer
        contentPlayhead:self.contentPlayhead
        userContext:nil];

    [self.adsLoader requestAdsWithRequest:request];
}

- (void)releaseAds {
    [self.adsLoader contentComplete];
    if (self.adsManager != nil) {
        [self.adsManager destroy];
        self.adsManager = nil;
    }
    self.adsLoader = nil;
}

#pragma mark - IMA Ads Loader Delegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    [self.adsManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    NSLog(@"Error loading ads: %@", adErrorData.adError.message);

    [NRVAVideo handleAdError:@(self.trackerId) error:adErrorData.adError];

    // Continue with content
    [self.player play];
}

#pragma mark - IMA Ads Manager Delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    NSLog(@"Ads Manager did receive event = %@", event.typeString);

    [NRVAVideo handleAdEvent:@(self.trackerId) event:event adsManager:adsManager];

    // Handle specific events
    if (event.type == kIMAAdEvent_LOADED) {
        [adsManager start];
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    NSLog(@"Ads Manager received error = %@", error.message);

    [NRVAVideo handleAdError:@(self.trackerId) error:error adsManager:adsManager];

    // Continue with content
    [self.player play];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request pause");

    [NRVAVideo sendAdBreakStart:@(self.trackerId)];
    [self.player pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    NSLog(@"Ads request resume");

    [NRVAVideo sendAdBreakEnd:@(self.trackerId)];
    [self.player play];
}

- (void)dealloc {
    // Clean up tracking when done
    [NRVAVideo releaseTracker:@(self.trackerId)];
    [self releaseAds];
}

@end
```

#### Swift Implementation

```swift
import UIKit
import AVFoundation
import AVKit
import NewRelicVideoCore
import GoogleInteractiveMediaAds

class ViewController: UIViewController {
    private var player: AVPlayer?
    private var playerController: AVPlayerViewController?
    private var adsLoader: IMAAdsLoader?
    private var adsManager: IMAAdsManager?
    private var contentPlayhead: IMAAVPlayerContentPlayhead?
    private var trackerId: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    func playVideo(videoURL: String) {
        // Create your AVPlayer
        guard let url = URL(string: videoURL) else { return }
        player = AVPlayer(url: url)

        // Setup player controller
        playerController = AVPlayerViewController()
        playerController?.player = player
        playerController?.showsPlaybackControls = true

        // ✅ CONFIGURATION-BASED SETUP WITH ADS
        let adTagURL = "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator="

        let playerConfig = NRVAVideoPlayerConfiguration(
            playerName: "MainVideoPlayer",
            player: player!,
            adEnabled: true,
            customAttributes: [
                "videoTitle": "Sample Video with Ads",
                "category": "Entertainment",
                "videoURL": url.absoluteString,
                "adTagURL": adTagURL
            ]
        )

        trackerId = NRVAVideo.addPlayer(playerConfig)

        // ✅ GLOBAL custom event (trackerId = nil sends to ALL trackers)
        NRVAVideo.recordCustomEvent(
            "PLAYER_SETUP_COMPLETE",
            trackerId: nil,
            attributes: [
                "setupMethod": "configuration-based",
                "hasAds": true
            ]
        )

        // ✅ TRACKER-SPECIFIC custom event (enriched with video attributes)
        NRVAVideo.recordCustomEvent(
            "VIDEO_READY",
            trackerId: NSNumber(value: trackerId),
            attributes: [
                "videoURL": videoURL,
                "hasAds": true
            ]
        )

        // Setup IMA ads
        setupAds(adTagURL: adTagURL)

        // Present player
        if let playerVC = playerController {
            present(playerVC, animated: true) {
                self.player?.play()
                self.requestAds()
            }
        }
    }

    private func setupAds(adTagURL: String) {
        guard let player = player else { return }

        contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
        adsLoader = IMAAdsLoader(settings: nil)
        adsLoader?.delegate = self
    }

    private func requestAds() {
        guard let playerVC = playerController,
              let contentPlayhead = contentPlayhead else { return }

        let adDisplayContainer = IMAAdDisplayContainer(
            adContainer: playerVC.view!,
            viewController: playerVC
        )

        guard let adTagURL = "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/ad_rule_samples&ciu_szs=300x250&ad_rule=1&impl=s&gdfp_req=1&env=vp&output=xml_vmap1&unviewed_position_start=1&cust_params=sample_ar%3Dpremidpostpod%26deployment%3Dgmf-js&cmsid=496&vid=short_onecue&correlator=" as String? else { return }

        let request = IMAAdsRequest(
            adTagUrl: adTagURL,
            adDisplayContainer: adDisplayContainer,
            contentPlayhead: contentPlayhead,
            userContext: nil
        )

        adsLoader?.requestAds(with: request)
    }

    private func releaseAds() {
        adsLoader?.contentComplete()
        if let manager = adsManager {
            manager.destroy()
            adsManager = nil
        }
        adsLoader = nil
    }

    deinit {
        // Clean up tracking when done
        NRVAVideo.releaseTracker(trackerId)
        releaseAds()
    }
}

// MARK: - IMA Ads Loader Delegate
extension ViewController: IMAAdsLoaderDelegate {
    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        adsManager?.initialize(with: nil)
        print("Ads Loader Loaded Data")
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        print("Error loading ads: \(adErrorData.adError.message ?? "Unknown error")")

        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: adErrorData.adError)

        // Continue with content
        player?.play()
    }
}

// MARK: - IMA Ads Manager Delegate
extension ViewController: IMAAdsManagerDelegate {
    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        print("Ads Manager did receive event = \(event.typeString ?? "Unknown")")

        NRVAVideo.handleAdEvent(NSNumber(value: trackerId), event: event, adsManager: adsManager)

        // Handle specific events
        if event.type == .LOADED {
            print("Ads Manager call start()")
            adsManager.start()
        }
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        print("Ads Manager received error = \(error.message ?? "Unknown error")")

        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: error, adsManager: adsManager)

        // Continue with content
        player?.play()
    }

    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        print("Ads request pause")

        NRVAVideo.sendAdBreakStart(NSNumber(value: trackerId))
        player?.pause()
    }

    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        print("Ads request resume")

        NRVAVideo.sendAdBreakEnd(NSNumber(value: trackerId))
        player?.play()
    }
}
```

## Advanced Features

### Custom Attributes

Add custom metadata to your video tracking:

#### Objective-C

```objectivec
// Set attributes for specific tracker
[NRVAVideo setAttribute:self.trackerId
                    key:@"videoGenre"
                  value:@"Documentary"];

// Set global attributes (applies to all trackers)
[NRVAVideo setGlobalAttribute:@"userTier"
                        value:@"Premium"];

// Set ad-specific attributes
[NRVAVideo setAdAttribute:self.trackerId
                      key:@"adCampaign"
                    value:@"Summer2024"];
```

#### Swift

```swift
// Set attributes for specific tracker
NRVAVideo.setAttribute(trackerId, key: "videoGenre", value: "Documentary")

// Set global attributes (applies to all trackers)
NRVAVideo.setGlobalAttribute("userTier", value: "Premium")

// Set ad-specific attributes
NRVAVideo.setAdAttribute(trackerId, key: "adCampaign", value: "Summer2024")
```

### User Identification

Associate video sessions with specific users:

#### Objective-C

```objectivec
[NRVAVideo setUserId:@"user123456"];
```

#### Swift

```swift
NRVAVideo.setUserId("user123456")
```

### Custom Events (API)

Record custom video events:

#### Objective-C

```objectivec
//  TRACKER-SPECIFIC CUSTOM EVENT (enriched with video attributes)
// Optional trackerId parameter - if nil, sends globally
[NRVAVideo recordCustomEvent:@"QualityChanged"
                   trackerId:@(self.trackerId)
                  attributes:@{
                      @"newQuality": @"1080p",
                      @"previousQuality": @"720p"
                  }];

// ✅ ALTERNATIVE: Global event by passing nil trackerId
[NRVAVideo recordCustomEvent:@"UserInteraction"
                   trackerId:nil
                  attributes:@{
                      @"interactionType": @"skip",
                      @"skipPosition": @(30.5)
                  }];
```

#### Swift

```swift
// TRACKER-SPECIFIC CUSTOM EVENT (enriched with video attributes)
// Optional trackerId parameter - if nil, sends globally
NRVAVideo.recordCustomEvent(
    "QualityChanged",
    trackerId: NSNumber(value: trackerId),
    attributes: [
        "newQuality": "1080p",
        "previousQuality": "720p"
    ]
)

// ✅ ALTERNATIVE: Global event by passing nil trackerId
NRVAVideo.recordCustomEvent(
    "UserInteraction",
    trackerId: nil,
    attributes: [
        "interactionType": "skip",
        "skipPosition": 30.5
    ]
)
```

### Manual Ad Event Control

For advanced ad implementations, you can manually control ad break events:

#### Objective-C

```objectivec
// Manual ad break control
[NRVAVideo sendAdBreakStart:@(self.trackerId)];
// ... ad playback ...
[NRVAVideo sendAdBreakEnd:@(self.trackerId)];
```

#### Swift

```swift
// Manual ad break control
NRVAVideo.sendAdBreakStart(NSNumber(value: trackerId))
// ... ad playback ...
NRVAVideo.sendAdBreakEnd(NSNumber(value: trackerId))
```

### Tracker Management

#### Objective-C

```objectivec
// Release tracker by ID
[NRVAVideo releaseTracker:self.trackerId];

// Release tracker by player name
[NRVAVideo releaseTrackerWithPlayerName:@"MainVideoPlayer"];
```

#### Swift

```swift
// Release tracker by ID
NRVAVideo.releaseTracker(trackerId)

// Release tracker by player name
NRVAVideo.releaseTrackerWithPlayerName("MainVideoPlayer")
```

## Configuration Examples

### Production Configuration

#### Objective-C

```objectivec
NRVAVideoConfiguration *productionConfig = [[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_PRODUCTION_TOKEN"]
    withHarvestCycle:30]  // Less frequent harvesting for production
    withDebugLogging:NO]  // Disable debug logs in production
    build];
```

#### Swift

```swift
let productionConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_PRODUCTION_TOKEN")
    .withHarvestCycle(30)  // Less frequent harvesting for production
    .withDebugLogging(false)  // Disable debug logs in production
    .build()
```

### Development Configuration

#### Objective-C

```objectivec
NRVAVideoConfiguration *devConfig = [[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_DEVELOPMENT_TOKEN"]
    withHarvestCycle:5]   // More frequent harvesting for testing
    withDebugLogging:YES] // Enable debug logs for development
    build];
```

#### Swift

```swift
let devConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_DEVELOPMENT_TOKEN")
    .withHarvestCycle(5)   // More frequent harvesting for testing
    .withDebugLogging(true) // Enable debug logs for development
    .build()
```

### Battery Optimization & Performance Configurations

#### Memory-Optimized Configuration (Recommended for Low-End Devices)

**Objective-C**

```objectivec
NRVAVideoConfiguration *memoryOptimizedConfig = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withMemoryOptimization:YES]  // Automatically applies memory-optimized settings
    withDebugLogging:NO]         // Disable debug logs to save battery
    build];
```

**Swift**

```swift
let memoryOptimizedConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withMemoryOptimization(true)  // Automatically applies memory-optimized settings
    .withDebugLogging(false)       // Disable debug logs to save battery
    .build()
```

**Memory Optimization automatically sets:**

- Harvest cycle: 60 seconds (vs 300 default)
- Live harvest cycle: 15 seconds (vs 30 default)
- Regular batch size: 32KB (vs 64KB default)
- Live batch size: 16KB (vs 32KB default)
- Max dead letter size: 50 (vs 100 default)

#### Apple TV Configuration

**Objective-C**

```objectivec
NRVAVideoConfiguration *tvConfig = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    forTVOS:YES]         // Automatically applies TV-optimized settings
    withDebugLogging:NO] // Production settings
    build];
```

**Swift**

```swift
let tvConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .forTVOS(true)         // Automatically applies TV-optimized settings
    .withDebugLogging(false) // Production settings
    .build()
```

**TV Optimization automatically sets:**

- Harvest cycle: 180 seconds (3 minutes)
- Live harvest cycle: 10 seconds
- Regular batch size: 128KB
- Live batch size: 64KB

#### Custom Performance Tuning

**Objective-C**

```objectivec
// High-performance configuration for powerful devices
NRVAVideoConfiguration *highPerfConfig = [[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withHarvestCycle:120]           // 2 minutes
    withLiveHarvestCycle:5]         // 5 seconds for real-time data
    withRegularBatchSize:128 * 1024] // 128KB batches
    withLiveBatchSize:64 * 1024]    // 64KB live batches
    build];

// Battery-conscious configuration
NRVAVideoConfiguration *batterySaverConfig = [[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEWRELIC_APP_TOKEN"]
    withHarvestCycle:300]           // 5 minutes (maximum)
    withLiveHarvestCycle:60]        // 1 minute (maximum)
    withRegularBatchSize:32 * 1024] // Smaller 32KB batches
    withLiveBatchSize:16 * 1024]    // Smaller 16KB live batches
    build];
```

**Swift**

```swift
// High-performance configuration for powerful devices
let highPerfConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withHarvestCycle(120)           // 2 minutes
    .withLiveHarvestCycle(5)         // 5 seconds for real-time data
    .withRegularBatchSize(128 * 1024) // 128KB batches
    .withLiveBatchSize(64 * 1024)    // 64KB live batches
    .build()

// Battery-conscious configuration
let batterySaverConfig = NRVAVideoConfiguration.builder()
    .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
    .withHarvestCycle(300)           // 5 minutes (maximum)
    .withLiveHarvestCycle(60)        // 1 minute (maximum)
    .withRegularBatchSize(32 * 1024) // Smaller 32KB batches
    .withLiveBatchSize(16 * 1024)    // Smaller 16KB live batches
    .build()
```

## Best Practices

### 1. **Initialization**

- Always initialize in `AppDelegate.didFinishLaunchingWithOptions`
- Use appropriate tokens for different environments
- Enable debug logging during development

### 2. **Player Setup**

- Use `NRVAVideoPlayerConfiguration` for all player setup
- Include relevant custom attributes in configuration
- Always release trackers in `dealloc` or appropriate cleanup methods

### 3. **Event Recording**

- **Always provide action parameter** - it's mandatory for all event methods
- Use global events to send to all trackers (includes video attribute enrichment)
- Use tracker-specific events for player-specific data
- All events automatically include video context (playhead, duration, src, etc.)

### 4. **Ad Integration**

- Use ad event methods (`handleAdEvent`, `handleAdError`)
- Handle ad errors gracefully
- Consider manual ad break control for custom ad implementations

### 5. **Performance**

- Set appropriate harvest cycles (30s for production, 5-10s for development)
- Use custom attributes sparingly
- Release trackers when no longer needed
- Events without trackers are automatically dropped (no unnecessary processing)

### 5. **Battery Optimization**

- Use `withMemoryOptimization:YES` for low-end devices
- Increase harvest cycles for battery-conscious apps (up to 300 seconds)
- Reduce batch sizes on cellular networks
- Consider `forTVOS:YES` for Apple TV apps (optimized for stable networks)
- Disable debug logging in production builds

### 6. **Performance Tuning Guidelines**

**For Different Device Types:**

- **iPhone/iPad Standard**: Default settings work well
- **Low-Memory Devices**: Use `withMemoryOptimization:YES`
- **Apple TV**: Use `forTVOS:YES` for optimal performance
- **Cellular-Heavy Apps**: Reduce batch sizes (32KB regular, 16KB live)
- **Real-Time Apps**: Decrease live harvest cycle (5-10 seconds)

**Network Considerations:**

- **WiFi-Primary Apps**: Larger batches (128KB) and frequent harvesting
- **Cellular-Primary Apps**: Smaller batches (32KB) and longer cycles
- **International Apps**: Consider regional data costs with longer cycles

### 7. **Debugging**

- Enable debug logging to see detailed tracking information
- Check console logs for tracking events and errors
- Use custom attributes to identify specific video sessions

## Troubleshooting

### Common Issues

1. **"NRVAVideo not initialized" error**

   - Ensure you call the initialization in `AppDelegate` before using any tracking methods

2. **"Action parameter is mandatory" error**

   - The `recordCustomEvent` method requires an action parameter
   - Update old API calls: `recordCustomEvent:@{@"action": @"MyAction", ...}` → `recordCustomEvent:@"MyAction" trackerId:@(trackerId) attributes:@{...}`
   - Use `trackerId:nil` for global events, or `trackerId:@(yourTrackerId)` for tracker-specific events
   - No need to specify `eventType` - automatically uses `VideoCustomAction`

3. **"No trackers available - dropping event" warning**

   - Events are dropped if no trackers exist (proper behavior for attribute enrichment)
   - Ensure you have at least one active player/tracker before recording events

4. **Missing ad events**

   - Verify IMA SDK is properly integrated
   - Check that ad delegates are properly implemented
   - Ensure ad methods (`handleAdEvent`, `handleAdError`) are called in correct delegate methods

5. **No tracking data**
   - Verify your New Relic token is correct
   - Check network connectivity
   - Ensure harvest cycle is appropriate

6. **Language-specific issues**

   **Objective-C:**
   - Ensure imports use `#import <NewRelicVideoCore/NewRelicVideoCore.h>`
   - Use `@import AVKit;` for AVFoundation/AVKit
   - Wrap tracker IDs in `@(self.trackerId)` when passing to methods

   **Swift:**
   - **Import errors**: Ensure you have the correct import statements at the top of your Swift files:
     ```swift
     import UIKit
     import AVFoundation
     import AVKit
     import NewRelicVideoCore
     import GoogleInteractiveMediaAds  // If using ads
     ```
   - **Type conversion errors**: Always wrap tracker IDs in `NSNumber`:
     ```swift
     // Correct:
     NRVAVideo.handleAdEvent(NSNumber(value: trackerId), event: event, adsManager: adsManager)
     NRVAVideo.recordCustomEvent("MyAction", trackerId: NSNumber(value: trackerId), attributes: [:])

     // Incorrect:
     NRVAVideo.handleAdEvent(trackerId, ...) // Compilation error
     ```
   - **Dictionary types**: Swift dictionaries `[String: Any]` are automatically bridged to `NSDictionary` for Objective-C methods
   - **Optional handling**: Use proper optional unwrapping for IMA SDK properties:
     ```swift
     print("Error: \(error.message ?? "Unknown error")")
     print("Event: \(event.typeString ?? "Unknown")")
     ```
   - **"Use of unresolved identifier" errors**: Ensure you've run `pod install` and are opening the `.xcworkspace` file, not the `.xcodeproj` file

### Debug Logging

When debug logging is enabled, you'll see detailed logs like:

```
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.152): Created content tracker (without player)
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.153): Created IMA ad tracker
NRVideoAgent (2025-08-11 14:30:45.154): Started tracking for player 'MainVideoPlayer' with tracker ID: 1
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.200): 📊 Sent global event to tracker 1: VideoCustomAction action: UserInteraction with enriched attributes
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.201): 📊 Recorded tracker-specific event via content tracker 1: VideoAction action: QualitySelection with enriched attributes
```

**New Logging Features:**

- Clear indication of attribute enrichment (📊 emoji)
- Shows whether events are global (all trackers) or tracker-specific
- Displays action parameters explicitly
- Indicates when events are dropped due to missing trackers

## Complete Swift Example

Here's a complete, production-ready Swift example that you can use as a template:

```swift
import UIKit
import AVFoundation
import AVKit
import NewRelicVideoCore
import GoogleInteractiveMediaAds

// MARK: - AppDelegate Setup
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Initialize New Relic Video Agent
        let videoConfig = NRVAVideoConfiguration.builder()
            .withApplicationToken("YOUR_NEWRELIC_APP_TOKEN")
            .withHarvestCycle(60)
            .withDebugLogging(true)
            .build()

        NRVAVideo.newBuilder()
            .withConfiguration(videoConfig)
            .build()

        return true
    }
}

// MARK: - Video Player with Ads
class VideoPlayerViewController: UIViewController {

    // MARK: - Properties
    private var player: AVPlayer?
    private var playerController: AVPlayerViewController?
    private var trackerId: Int = 0

    // IMA Ad Properties
    private var adsLoader: IMAAdsLoader?
    private var adsManager: IMAAdsManager?
    private var contentPlayhead: IMAAVPlayerContentPlayhead?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Setup your UI
    }

    // MARK: - Video Playback
    func playVideo(urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid video URL")
            return
        }

        // Create AVPlayer
        player = AVPlayer(url: url)

        // Create player controller
        playerController = AVPlayerViewController()
        playerController?.player = player
        playerController?.showsPlaybackControls = true

        // Configure New Relic tracking
        let playerConfig = NRVAVideoPlayerConfiguration(
            playerName: "MainPlayer",
            player: player!,
            adEnabled: true,
            customAttributes: [
                "videoTitle": "My Video",
                "contentType": "vod",
                "videoURL": urlString
            ]
        )

        // Start tracking
        trackerId = NRVAVideo.addPlayer(playerConfig)

        // Record custom event
        NRVAVideo.recordCustomEvent(
            "VIDEO_PLAYER_INITIALIZED",
            trackerId: NSNumber(value: trackerId),
            attributes: [
                "platform": "iOS",
                "hasAds": true
            ]
        )

        // Setup IMA ads
        setupAds()

        // Present player
        if let playerVC = playerController {
            present(playerVC, animated: true) {
                self.requestAds()
            }
        }
    }

    // MARK: - IMA Ads Setup
    private func setupAds() {
        guard let player = player else { return }

        contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
        adsLoader = IMAAdsLoader(settings: nil)
        adsLoader?.delegate = self
    }

    private func requestAds() {
        guard let playerVC = playerController,
              let contentPlayhead = contentPlayhead else {
            player?.play()
            return
        }

        let adDisplayContainer = IMAAdDisplayContainer(
            adContainer: playerVC.view!,
            viewController: playerVC
        )

        let adTagURL = "YOUR_AD_TAG_URL"

        let request = IMAAdsRequest(
            adTagUrl: adTagURL,
            adDisplayContainer: adDisplayContainer,
            contentPlayhead: contentPlayhead,
            userContext: nil
        )

        adsLoader?.requestAds(with: request)
    }

    private func cleanupAds() {
        adsLoader?.contentComplete()
        adsManager?.destroy()
        adsManager = nil
        adsLoader = nil
    }

    // MARK: - Cleanup
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent {
            NRVAVideo.releaseTracker(trackerId)
            cleanupAds()
        }
    }

    deinit {
        NRVAVideo.releaseTracker(trackerId)
        cleanupAds()
    }
}

// MARK: - IMAAdsLoaderDelegate
extension VideoPlayerViewController: IMAAdsLoaderDelegate {

    func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
        adsManager = adsLoadedData.adsManager
        adsManager?.delegate = self
        adsManager?.initialize(with: nil)
    }

    func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
        print("Ad loading failed: \(adErrorData.adError.message ?? "Unknown error")")

        // Track error with New Relic
        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: adErrorData.adError)

        // Continue with content playback
        player?.play()
    }
}

// MARK: - IMAAdsManagerDelegate
extension VideoPlayerViewController: IMAAdsManagerDelegate {

    func adsManager(_ adsManager: IMAAdsManager, didReceive event: IMAAdEvent) {
        // Track ad event with New Relic
        NRVAVideo.handleAdEvent(NSNumber(value: trackerId), event: event, adsManager: adsManager)

        // Handle specific events
        switch event.type {
        case .LOADED:
            adsManager.start()
        case .ALL_ADS_COMPLETED:
            // Ads completed, content will resume automatically
            break
        default:
            break
        }
    }

    func adsManager(_ adsManager: IMAAdsManager, didReceive error: IMAAdError) {
        print("Ad playback error: \(error.message ?? "Unknown error")")

        // Track error with New Relic
        NRVAVideo.handleAdError(NSNumber(value: trackerId), error: error, adsManager: adsManager)

        // Continue with content playback
        player?.play()
    }

    func adsManagerDidRequestContentPause(_ adsManager: IMAAdsManager) {
        // Ad break is starting
        NRVAVideo.sendAdBreakStart(NSNumber(value: trackerId))
        player?.pause()
    }

    func adsManagerDidRequestContentResume(_ adsManager: IMAAdsManager) {
        // Ad break is ending
        NRVAVideo.sendAdBreakEnd(NSNumber(value: trackerId))
        player?.play()
    }
}
```

## Support

For additional support:

- Check the [Advanced Configuration Guide](advanced.md)
- Review the [Data Model Documentation](DATAMODEL.md)
- Contact New Relic support for account-specific issues

---
