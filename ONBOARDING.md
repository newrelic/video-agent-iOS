# New Relic Video Agent iOS - Developer Onboarding Guide

## Overview

The New Relic Video Agent for iOS provides comprehensive video analytics and monitoring capabilities with minimal integration effort. This guide covers everything you need to get started with video tracking for both simple video playback and ad-enabled scenarios.

## Quick Start

### 1. AppDelegate Setup (Required)

In your `AppDelegate.m`, initialize the video agent:

```objectivec
#import <NewRelicVideoCore.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Initialize New Relic Video Agent
    NRVAVideoConfiguration *videoConfig = [[[[[NRVAVideoConfiguration builder]
        withApplicationToken:@"YOUR_NEW_RELIC_TOKEN"]
        withHarvestCycle:10]
        withDebugLogging:YES] build];

    [[[NRVAVideo newBuilder] withConfiguration:videoConfig] build];

    return YES;
}
```

**Configuration Options:**

- `withApplicationToken:` - Your New Relic application token (required)
- `withHarvestCycle:` - Data harvest interval in seconds (default: 30)
- `withDebugLogging:` - Enable debug logs (recommended for development)

### Advanced Configuration Options

For production and performance optimization, you can configure additional options:

```objectivec
NRVAVideoConfiguration *advancedConfig = [[[[[[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_NEW_RELIC_TOKEN"]
    withHarvestCycle:30]                    // Regular harvest cycle (5-300 seconds)
    withLiveHarvestCycle:10]                // Live content harvest cycle (1-60 seconds)
    withRegularBatchSize:64 * 1024]         // Regular content batch size (64KB default)
    withLiveBatchSize:32 * 1024]            // Live content batch size (32KB default)
    withMaxDeadLetterSize:100]              // Failed request queue size (10-1000)
    withMemoryOptimization:NO]              // Enable for low-memory devices
    forTVOS:NO]                             // Enable tvOS optimizations
    withDebugLogging:YES]                   // Debug logging
    build];
```

**Complete Configuration Reference:**

| Option | Type | Default | Range | Description |
|--------|------|---------|-------|-------------|
| `withApplicationToken:` | NSString* | *(required)* | - | Your New Relic application token |
| `withHarvestCycle:` | NSInteger | 300 (5 min) | 5-300 seconds | How often to send regular content data |
| `withLiveHarvestCycle:` | NSInteger | 30 | 1-60 seconds | How often to send live content data |
| `withRegularBatchSize:` | NSInteger | 65,536 (64KB) | 1KB-1MB | Batch size for regular content uploads |
| `withLiveBatchSize:` | NSInteger | 32,768 (32KB) | 512B-512KB | Batch size for live content uploads |
| `withMaxDeadLetterSize:` | NSInteger | 100 | 10-1000 | Failed request queue capacity |
| `withMemoryOptimization:` | BOOL | NO | YES/NO | Optimize for low-memory devices |
| `forTVOS:` | BOOL | auto-detected | YES/NO | Enable Apple TV optimizations |
| `withDebugLogging:` | BOOL | NO | YES/NO | Enable detailed debug logging |

### Default Values for Convenience Methods

When using one-line convenience methods like `addPlayerWithURL:name:`, these defaults are automatically applied:

**Default Attributes Added:**
- `videoURL`: The provided video URL
- `setupMethod`: `"one-line-convenience"`
- `adsEnabled`: `YES` if adTagURL provided, `NO` otherwise
- `adTagURL`: Only included if ads are enabled

**Default Behavior:**
- **No AVPlayer Created**: You manage the AVPlayer lifecycle
- **Automatic Ad Detection**: Ads enabled if `adTagURL` is provided
- **Smart Configuration**: Uses global configuration for harvest cycles and batch sizes

## Video Player Integration

### Option 1: Simple Video Player (No Ads)

For basic video playback without advertisements:

#### ViewController Implementation

```objectivec
#import <NewRelicVideoCore.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign) NSInteger trackerId;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Create your AVPlayer
    NSURL *videoURL = [NSURL URLWithString:@"https://example.com/video.mp4"];
    self.player = [AVPlayer playerWithURL:videoURL];

    // 🚀 ONE-LINE SETUP: Add player to New Relic tracking
    self.trackerId = [NRVAVideo addPlayerWithURL:videoURL.absoluteString
                                            name:@"MainVideoPlayer"];

    // Setup your player view
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    playerLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:playerLayer];

    // Start playback
    [self.player play];
}

- (void)dealloc {
    // Clean up tracking when done
    [NRVAVideo releaseTracker:self.trackerId];
}
```

#### Alternative: Manual Configuration

```objectivec
// For more control, use manual configuration
NRVAVideoPlayerConfiguration *config = [[NRVAVideoPlayerConfiguration alloc]
    initWithPlayerName:@"MainVideoPlayer"
    player:self.player
    adEnabled:NO
    customAttributes:@{
        @"videoTitle": @"Sample Video",
        @"category": @"Entertainment"
    }];

self.trackerId = [NRVAVideo addPlayer:config];
```

### Option 2: Video Player with Ads

For video playback with Google IMA advertisements:

#### ViewController Implementation

```objectivec
#import <NewRelicVideoCore.h>
#import <AVFoundation/AVFoundation.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

@interface ViewController () <IMAAdsLoaderDelegate, IMAAdsManagerDelegate>
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) IMAAdsLoader *adsLoader;
@property (nonatomic, strong) IMAAdsManager *adsManager;
@property (nonatomic, assign) NSInteger trackerId;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Create your AVPlayer
    NSURL *videoURL = [NSURL URLWithString:@"https://example.com/video.mp4"];
    self.player = [AVPlayer playerWithURL:videoURL];

    // 🚀 ONE-LINE SETUP: Add player with ads to New Relic tracking
    NSString *adTagURL = @"https://pubads.g.doubleclick.net/gampad/ads?...";
    self.trackerId = [NRVAVideo addPlayerWithURL:videoURL.absoluteString
                                            name:@"MainVideoPlayer"
                                        adTagURL:adTagURL];

    // Setup your player view
    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    playerLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:playerLayer];

    // Setup IMA ads
    [self setupAds];
}

- (void)setupAds {
    self.adsLoader = [[IMAAdsLoader alloc] init];
    self.adsLoader.delegate = self;

    // Load ads
    IMAAdsRequest *request = [[IMAAdsRequest alloc]
        initWithAdTagUrl:@"YOUR_AD_TAG_URL"
        adDisplayContainer:nil
        contentPlayhead:nil
        userContext:nil];

    [self.adsLoader requestAdsWithRequest:request];
}

#pragma mark - IMA Ads Loader Delegate

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;

    [self.adsManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    // 🚀 ONE-LINE AD ERROR TRACKING
    [NRVAVideo handleAdError:@(self.trackerId) error:adErrorData.adError];

    // Continue with content
    [self.player play];
}

#pragma mark - IMA Ads Manager Delegate

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    // 🚀 ONE-LINE AD EVENT TRACKING
    [NRVAVideo handleAdEvent:@(self.trackerId) event:event adsManager:adsManager];

    // Handle specific events
    switch (event.type) {
        case kIMAAdEvent_LOADED:
            [adsManager start];
            break;
        case kIMAAdEvent_ALL_ADS_COMPLETED:
            [self.player play];
            break;
        default:
            break;
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    // 🚀 ONE-LINE AD ERROR TRACKING
    [NRVAVideo handleAdError:@(self.trackerId) error:error];

    // Continue with content
    [self.player play];
}

- (void)dealloc {
    // Clean up tracking when done
    [NRVAVideo releaseTracker:self.trackerId];
}
```

## Advanced Features

### Custom Attributes

Add custom metadata to your video tracking:

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

### User Identification

Associate video sessions with specific users:

```objectivec
[NRVAVideo setUserId:@"user123456"];
```

### Custom Events

Record custom video events:

```objectivec
// Record custom event for specific tracker
[NRVAVideo recordEvent:@"VideoBookmarked"
             trackerId:@(self.trackerId)
            attributes:@{
                @"timestamp": @([[NSDate date] timeIntervalSince1970]),
                @"bookmarkType": @"favorite"
            }];

// Record global custom event
[NRVAVideo recordCustomEvent:@{
    @"action": @"QualityChanged",
    @"newQuality": @"1080p",
    @"previousQuality": @"720p"
}];
```

### Manual Ad Event Control

For advanced ad implementations, you can manually control ad break events:

```objectivec
// Manual ad break control
[NRVAVideo sendAdBreakStart:@(self.trackerId)];
// ... ad playback ...
[NRVAVideo sendAdBreakEnd:@(self.trackerId)];
```

### Tracker Management

```objectivec
// Get content tracker for direct manipulation
id contentTracker = [NRVAVideo contentTracker:@(self.trackerId)];

// Get ad tracker for direct manipulation
id adTracker = [NRVAVideo adTracker:@(self.trackerId)];

// Release tracker by player name
[NRVAVideo releaseTrackerWithPlayerName:@"MainVideoPlayer"];
```

## Configuration Examples

### Production Configuration

```objectivec
NRVAVideoConfiguration *productionConfig = [[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_PRODUCTION_TOKEN"]
    withHarvestCycle:30]  // Less frequent harvesting for production
    withDebugLogging:NO]  // Disable debug logs in production
    build];
```

### Development Configuration

```objectivec
NRVAVideoConfiguration *devConfig = [[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_DEVELOPMENT_TOKEN"]
    withHarvestCycle:5]   // More frequent harvesting for testing
    withDebugLogging:YES] // Enable debug logs for development
    build];
```

### Battery Optimization & Performance Configurations

#### Memory-Optimized Configuration (Recommended for Low-End Devices)

```objectivec
NRVAVideoConfiguration *memoryOptimizedConfig = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_TOKEN"]
    withMemoryOptimization:YES]  // Automatically applies memory-optimized settings
    withDebugLogging:NO]         // Disable debug logs to save battery
    build];
```

**Memory Optimization automatically sets:**
- Harvest cycle: 60 seconds (vs 300 default)
- Live harvest cycle: 15 seconds (vs 30 default)  
- Regular batch size: 32KB (vs 64KB default)
- Live batch size: 16KB (vs 32KB default)
- Max dead letter size: 50 (vs 100 default)

#### Apple TV Configuration

```objectivec
NRVAVideoConfiguration *tvConfig = [[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_TOKEN"]
    forTVOS:YES]         // Automatically applies TV-optimized settings
    withDebugLogging:NO] // Production settings
    build];
```

**TV Optimization automatically sets:**
- Harvest cycle: 180 seconds (3 minutes)
- Live harvest cycle: 10 seconds
- Regular batch size: 128KB
- Live batch size: 64KB

#### Custom Performance Tuning

```objectivec
// High-performance configuration for powerful devices
NRVAVideoConfiguration *highPerfConfig = [[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_TOKEN"]
    withHarvestCycle:120]           // 2 minutes
    withLiveHarvestCycle:5]         // 5 seconds for real-time data
    withRegularBatchSize:128 * 1024] // 128KB batches
    withLiveBatchSize:64 * 1024]    // 64KB live batches
    build];

// Battery-conscious configuration
NRVAVideoConfiguration *batterySaverConfig = [[[[[[NRVAVideoConfiguration builder]
    withApplicationToken:@"YOUR_TOKEN"]
    withHarvestCycle:300]           // 5 minutes (maximum)
    withLiveHarvestCycle:60]        // 1 minute (maximum)
    withRegularBatchSize:32 * 1024] // Smaller 32KB batches
    withLiveBatchSize:16 * 1024]    // Smaller 16KB live batches
    build];
```

## Best Practices

### 1. **Initialization**

- Always initialize in `AppDelegate.didFinishLaunchingWithOptions`
- Use appropriate tokens for different environments
- Enable debug logging during development

### 2. **Player Setup**

- Use one-line convenience methods for simple setups
- Use manual configuration for complex scenarios
- Always release trackers in `dealloc` or appropriate cleanup methods

### 3. **Ad Integration**

- Use convenience methods for automatic ad event tracking
- Handle ad errors gracefully
- Consider manual ad break control for custom ad implementations

### 4. **Performance**

- Set appropriate harvest cycles (30s for production, 5-10s for development)
- Use custom attributes sparingly
- Release trackers when no longer needed

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

2. **Missing ad events**

   - Verify IMA SDK is properly integrated
   - Check that ad delegates are properly implemented
   - Ensure convenience methods are called in correct delegate methods

3. **No tracking data**
   - Verify your New Relic token is correct
   - Check network connectivity
   - Ensure harvest cycle is appropriate

### Debug Logging

When debug logging is enabled, you'll see detailed logs like:

```
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.152): Created content tracker (without player)
NRVideoAgent [DEBUG] (2025-08-11 14:30:45.153): Created IMA ad tracker (Android pattern)
NRVideoAgent (2025-08-11 14:30:45.154): Started tracking for player 'MainVideoPlayer' with tracker ID: 1
```

## Support

For additional support:

- Check the [Advanced Configuration Guide](advanced.md)
- Review the [Data Model Documentation](DATAMODEL.md)
- Contact New Relic support for account-specific issues

---
