//
//  NRTrackerMediaTailor.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRTrackerMediaTailor.h"
#import "NRMediaTailorConstants.h"
#import "NRMTUtilities.h"
#import "NRMTManifestParser.h"
#import "NRMTNetworkManager.h"
#import "NRMTAdBreak.h"
#import "NRMTAdPod.h"
#import "NRMTTrackingResponse.h"

@interface NRTrackerMediaTailor ()

// Configuration
@property (nonatomic, strong) NSDictionary *config;

// Stream properties
@property (nonatomic, assign) NRMTStreamType streamType;
@property (nonatomic, assign) NRMTManifestType manifestType;
@property (nonatomic, strong) NSURL *mediaTailorEndpoint;
@property (nonatomic, strong, nullable) NSURL *trackingUrl;

// Ad tracking state
@property (nonatomic, strong) NSMutableArray<NRMTAdBreak *> *adSchedule;
@property (nonatomic, strong, nullable) NRMTAdBreak *currentAdBreak;
@property (nonatomic, strong, nullable) NRMTAdPod *currentAdPod;
@property (nonatomic, assign) BOOL hasEndedContent;

// Network state
@property (nonatomic, assign) BOOL isDisposed;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *trackingTask;
@property (nonatomic, strong, nullable) NSURLSessionDataTask *manifestTask;
@property (nonatomic, assign) BOOL isFetchingTracking;
@property (nonatomic, assign) BOOL isFetchingManifest;

// Tracking API state
@property (nonatomic, assign) BOOL hasAttemptedTrackingFetch;
@property (nonatomic, assign) NSInteger trackingFetchRetries;
@property (nonatomic, assign) NSInteger maxTrackingRetries;

// Live polling
@property (nonatomic, strong, nullable) NSTimer *manifestPollTimer;
@property (nonatomic, strong, nullable) NSTimer *trackingPollTimer;

// Manifest cache
@property (nonatomic, strong, nullable) NSString *lastMediaPlaylistText;
@property (nonatomic, assign) NSTimeInterval manifestTargetDuration;

// AVPlayer references
@property (nonatomic, strong) AVPlayer *player;  // strong to prevent deallocation during init
@property (nonatomic, strong, nullable) id timeObserver;

// Initialization tracking
@property (nonatomic, assign) BOOL hasInitialized;
@property (nonatomic, assign) BOOL isSettingPlayer;
@property (nonatomic, assign) BOOL isManifestParsed;  // Track if first manifest has been parsed

// Pre-fetch support
@property (nonatomic, strong, nullable) NRMTManifestParserResult *preFetchedResult;
@property (nonatomic, assign) BOOL isPreFetching;

@end

@implementation NRTrackerMediaTailor

// MARK: - Class Methods

+ (BOOL)isUsing:(AVPlayer *)player {
    if (!player) {
        NSLog(@"%@ isUsing: called with nil player", [NRMTUtilities logPrefix]);
        return NO;
    }

    NSLog(@"%@ isUsing: checking player, currentItem = %@", [NRMTUtilities logPrefix], player.currentItem ? @"EXISTS" : @"NIL");

    if (!player.currentItem) {
        NSLog(@"%@ isUsing: player has no currentItem yet, cannot detect MediaTailor", [NRMTUtilities logPrefix]);
        return NO;
    }

    AVAsset *asset = player.currentItem.asset;
    if (![asset isKindOfClass:[AVURLAsset class]]) {
        NSLog(@"%@ isUsing: asset is not AVURLAsset (class: %@)", [NRMTUtilities logPrefix], [asset class]);
        return NO;
    }

    NSURL *url = [(AVURLAsset *)asset URL];
    BOOL isMediaTailor = [NRMTUtilities isMediaTailorURL:url];
    NSLog(@"%@ isUsing: URL = %@, isMediaTailor = %@", [NRMTUtilities logPrefix], url, isMediaTailor ? @"YES" : @"NO");

    return isMediaTailor;
}

// MARK: - Initialization

- (instancetype)init {
    if (self = [super init]) {
        // Set default config
        _config = @{
            @"enableManifestParsing": @YES,
            @"liveManifestPollInterval": @(NRMT_DEFAULT_LIVE_MANIFEST_POLL_INTERVAL),
            @"liveTrackingPollInterval": @(NRMT_DEFAULT_LIVE_TRACKING_POLL_INTERVAL),
            @"trackingAPITimeout": @(NRMT_DEFAULT_TRACKING_API_TIMEOUT)
        };

        // Initialize state
        _adSchedule = [NSMutableArray array];
        _maxTrackingRetries = 1;
        _streamType = NRMTStreamTypeVOD; // Will be detected later
        _hasEndedContent = NO;
        _manifestType = NRMTManifestTypeHLS; // Default to HLS
        _hasInitialized = NO;
        _isSettingPlayer = NO;

        NSLog(@"%@ MediaTailorAdsTracker initialized (will set player later)", [NRMTUtilities logPrefix]);
    }
    return self;
}

- (instancetype)initWithAVPlayer:(AVPlayer *)player
                         options:(nullable NSDictionary *)options {
    if (self = [super init]) {
        // Merge config with defaults
        NSMutableDictionary *defaultConfig = [@{
            @"enableManifestParsing": @YES,
            @"liveManifestPollInterval": @(NRMT_DEFAULT_LIVE_MANIFEST_POLL_INTERVAL),
            @"liveTrackingPollInterval": @(NRMT_DEFAULT_LIVE_TRACKING_POLL_INTERVAL),
            @"trackingAPITimeout": @(NRMT_DEFAULT_TRACKING_API_TIMEOUT)
        } mutableCopy];

        if (options) {
            [defaultConfig addEntriesFromDictionary:options];
        }

        _config = [defaultConfig copy];

        // Initialize state
        _player = player;
        _adSchedule = [NSMutableArray array];
        _maxTrackingRetries = 1;
        _streamType = NRMTStreamTypeVOD; // Will be detected later
        _hasEndedContent = NO;
        _hasInitialized = NO;
        _isSettingPlayer = NO;

        // Detect manifest type from URL
        AVAsset *asset = player.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)asset URL];
            _mediaTailorEndpoint = url;
            _manifestType = [NRMTUtilities detectManifestTypeFromURL:url];
        }

        NSLog(@"%@ MediaTailorAdsTracker initialized", [NRMTUtilities logPrefix]);
        NSLog(@"%@ Manifest type: HLS", [NRMTUtilities logPrefix]);

        // Set player
        [self setPlayer:player];
    }
    return self;
}

// MARK: - NRVideoTracker Overrides

- (void)setPlayer:(id)player {
    NSLog(@"%@ setPlayer called with player: %@, player class: %@", [NRMTUtilities logPrefix], player ? @"YES" : @"NO", [player class]);

    if (!player) {
        NSLog(@"%@ WARNING: setPlayer called with nil player", [NRMTUtilities logPrefix]);
        return;
    }

    // Guard against recursive calls
    if (self.isSettingPlayer) {
        NSLog(@"%@ Preventing recursive setPlayer call - already setting player", [NRMTUtilities logPrefix]);
        return;
    }

    self.isSettingPlayer = YES;

    NSLog(@"%@ BEFORE assignment: player param = %@, _player = %@", [NRMTUtilities logPrefix], player ? @"NOT NIL" : @"NIL", _player ? @"NOT NIL" : @"NIL");
    _player = player;  // Direct ivar access to bypass method name conflict
    NSLog(@"%@ AFTER assignment: player param = %@, _player = %@", [NRMTUtilities logPrefix], player ? @"NOT NIL" : @"NIL", _player ? @"NOT NIL" : @"NIL");

    AVPlayer *avPlayer = (AVPlayer *)player;

    // Detect manifest type and endpoint from URL if available
    if (avPlayer && avPlayer.currentItem && !self.mediaTailorEndpoint) {
        AVAsset *asset = avPlayer.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)asset URL];
            self.mediaTailorEndpoint = url;
            self.manifestType = [NRMTUtilities detectManifestTypeFromURL:url];
            NSLog(@"%@ Detected MediaTailor endpoint: %@", [NRMTUtilities logPrefix], url);
            NSLog(@"%@ Manifest type: HLS", [NRMTUtilities logPrefix]);

            // 🚀 Trigger automatic pre-fetch to eliminate delay
            [self preFetchManifest];
        } else {
            NSLog(@"%@ WARNING: player.currentItem.asset is not AVURLAsset", [NRMTUtilities logPrefix]);
        }
    } else if (avPlayer && !avPlayer.currentItem) {
        NSLog(@"%@ No currentItem yet, will detect URL when player is ready", [NRMTUtilities logPrefix]);
    }

    NSLog(@"%@ Before registerListeners, _player = %@", [NRMTUtilities logPrefix], _player ? @"NOT NIL" : @"NIL");
    [self registerListeners];
    NSLog(@"%@ After registerListeners, _player = %@", [NRMTUtilities logPrefix], _player ? @"NOT NIL" : @"NIL");
    [self observePlayerMetadata];
    NSLog(@"%@ After observePlayerMetadata, _player = %@", [NRMTUtilities logPrefix], _player ? @"NOT NIL" : @"NIL");

    // NOTE: We DO NOT call [super setPlayer:player] because base NRVideoTracker.setPlayer
    // immediately sends PLAYER_READY event. MediaTailor needs to control when PLAYER_READY
    // is sent (after manifest parsing completes). The state transition goPlayerReady is
    // handled in initializeTracking after we parse the first manifest.

    self.isSettingPlayer = NO;

    NSLog(@"%@ setPlayer completed", [NRMTUtilities logPrefix]);
}

- (void)registerListeners {
    // DO NOT call [super registerListeners] - MediaTailor has custom tracking logic
    // Calling super would add duplicate KVO observers from base NRVideoTracker

    if (!self.player) {
        return;
    }

    NSLog(@"%@ Registering listeners", [NRMTUtilities logPrefix]);

    // Add periodic time observer for tracking
    __weak typeof(self) weakSelf = self;
    self.timeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2)
                                                                   queue:NULL
                                                              usingBlock:^(CMTime time) {
        [weakSelf onTimeUpdate];
    }];

    // Observe player events
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidPlayToEndTime:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.player.currentItem];
}

- (void)unregisterListeners {
    [super unregisterListeners];

    NSLog(@"%@ Unregistering listeners", [NRMTUtilities logPrefix]);

    // Remove time observer
    if (self.timeObserver && self.player) {
        [self.player removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }

    // Remove KVO observers safely (wrapped in try-catch to avoid crashes if not observing)
    if (self.player) {
        @try {
            [self.player removeObserver:self forKeyPath:@"currentItem"];
        } @catch (NSException *exception) {
            // Observer wasn't added, ignore
        }
    }

    if (self.player && self.player.currentItem) {
        @try {
            [self.player.currentItem removeObserver:self forKeyPath:@"status"];
        } @catch (NSException *exception) {
            // Observer wasn't added, ignore
        }
    }

    // Remove notifications
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // Stop polling
    [self stopLivePolling];
}

- (void)dispose {
    NSLog(@"%@ Disposing tracker", [NRMTUtilities logPrefix]);

    self.isDisposed = YES;

    // Cancel in-flight requests
    [self.trackingTask cancel];
    [self.manifestTask cancel];

    [self stopLivePolling];
    [self unregisterListeners];
    [super dispose];
}

// MARK: - Attribute Getters (Override base tracker)

- (NSString *)getTrackerName {
    return @"aws-media-tailor";
}

- (NSString *)getPlayerVersion {
    return @"MediaTailor";
}

- (NSString *)getTitle {
    if (self.currentAdPod) {
        return self.currentAdPod.title ?: (self.currentAdBreak.breakId ?: @"unknown");
    }
    if (self.currentAdBreak) {
        return self.currentAdBreak.title ?: (self.currentAdBreak.breakId ?: @"unknown");
    }
    return @"unknown";
}

- (NSString *)getVideoId {
    if (self.currentAdPod) {
        return self.currentAdPod.creativeId ?: (self.currentAdPod.title ?: (self.currentAdBreak.breakId ?: @"unknown"));
    }
    if (self.currentAdBreak) {
        return self.currentAdBreak.creativeId ?: (self.currentAdBreak.breakId ?: @"unknown");
    }
    return @"unknown";
}

- (NSString *)getSrc {
    // Return tracking URL or manifest endpoint
    if (self.trackingUrl) {
        return self.trackingUrl.absoluteString;
    }
    if (self.mediaTailorEndpoint) {
        return self.mediaTailorEndpoint.absoluteString;
    }
    return @"unknown";
}

- (NSNumber *)getDuration {
    NSTimeInterval duration = 0;
    if (self.currentAdPod) {
        duration = self.currentAdPod.duration;
    } else if (self.currentAdBreak) {
        duration = self.currentAdBreak.duration;
    } else {
        return (NSNumber *)[NSNull null];
    }
    return @(duration * 1000); // Convert to milliseconds
}

- (NSString *)getAdPosition {
    if (self.currentAdBreak) {
        switch (self.currentAdBreak.adPosition) {
            case NRMTAdPositionPreRoll:
                return @"pre";
            case NRMTAdPositionMidRoll:
                return @"mid";
            case NRMTAdPositionPostRoll:
                return @"post";
            default:
                return (NSString *)[NSNull null];
        }
    }
    return [super getAdPosition];
}

// MARK: - Initialization Flow

- (void)observePlayerMetadata {
    if (!self.player) {
        NSLog(@"%@ WARNING: observePlayerMetadata called with nil player", [NRMTUtilities logPrefix]);
        return;
    }

    // If currentItem doesn't exist yet, observe the player's currentItem property
    if (!self.player.currentItem) {
        NSLog(@"%@ No currentItem yet, observing player.currentItem", [NRMTUtilities logPrefix]);
        [self.player addObserver:self
                      forKeyPath:@"currentItem"
                         options:NSKeyValueObservingOptionNew
                         context:NULL];
        return;
    }

    NSLog(@"%@ CurrentItem exists, status: %ld", [NRMTUtilities logPrefix], (long)self.player.currentItem.status);

    // Wait for metadata to be loaded
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
        NSLog(@"%@ Player item already ready, initializing tracking immediately", [NRMTUtilities logPrefix]);
        [self initializeTracking];
    } else {
        NSLog(@"%@ Player item not ready yet (status: %ld), observing status", [NRMTUtilities logPrefix], (long)self.player.currentItem.status);
        // Observe status changes
        [self.player.currentItem addObserver:self
                                  forKeyPath:@"status"
                                     options:NSKeyValueObservingOptionNew
                                     context:NULL];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"currentItem"]) {
        // Player's currentItem changed (from nil to an actual item)
        NSLog(@"%@ Player currentItem changed", [NRMTUtilities logPrefix]);
        [self.player removeObserver:self forKeyPath:@"currentItem"];

        // Now that currentItem exists, try to extract URL if we don't have it yet
        if (!self.mediaTailorEndpoint && self.player.currentItem) {
            AVAsset *asset = self.player.currentItem.asset;
            if ([asset isKindOfClass:[AVURLAsset class]]) {
                NSURL *url = [(AVURLAsset *)asset URL];
                self.mediaTailorEndpoint = url;
                self.manifestType = [NRMTUtilities detectManifestTypeFromURL:url];
                NSLog(@"%@ Detected MediaTailor endpoint after currentItem loaded: %@", [NRMTUtilities logPrefix], url);
            }
        }

        // Continue observing metadata
        [self observePlayerMetadata];
    } else if ([keyPath isEqualToString:@"status"]) {
        // Player item status changed
        NSLog(@"%@ Player item status changed to: %ld", [NRMTUtilities logPrefix], (long)self.player.currentItem.status);
        if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay) {
            [self.player.currentItem removeObserver:self forKeyPath:@"status"];
            NSLog(@"%@ Player item ready - calling initializeTracking", [NRMTUtilities logPrefix]);
            [self initializeTracking];
        } else if (self.player.currentItem.status == AVPlayerItemStatusFailed) {
            NSLog(@"%@ ERROR: Player item failed with error: %@", [NRMTUtilities logPrefix], self.player.currentItem.error.localizedDescription);
            [self.player.currentItem removeObserver:self forKeyPath:@"status"];
        }
    }
}

// MARK: - Pre-fetch Support

- (void)preFetchManifest {
    if (self.isPreFetching || self.preFetchedResult) {
        NSLog(@"%@ Pre-fetch already in progress or completed, skipping", [NRMTUtilities logPrefix]);
        return;
    }

    if (!self.mediaTailorEndpoint) {
        NSLog(@"%@ Cannot pre-fetch: no MediaTailor endpoint URL", [NRMTUtilities logPrefix]);
        return;
    }

    self.isPreFetching = YES;

    NSString *manifestURL = self.mediaTailorEndpoint.absoluteString;
    NSURL *trackingURL = [NRMTUtilities extractTrackingURLFromManifestURL:self.mediaTailorEndpoint];
    NSString *trackingURLString = trackingURL ? trackingURL.absoluteString : nil;

    NSLog(@"%@ 🚀 Pre-fetching manifest to eliminate delay...", [NRMTUtilities logPrefix]);
    NSLog(@"%@ 📍 Manifest URL: %@", [NRMTUtilities logPrefix], manifestURL);
    if (trackingURLString) {
        NSLog(@"%@ 📍 Tracking URL: %@", [NRMTUtilities logPrefix], trackingURLString);
    }

    __weak typeof(self) weakSelf = self;
    [NRMTManifestParser parseManifestAtURL:manifestURL
                               trackingURL:trackingURLString
                                completion:^(NRMTManifestParserResult *result, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        strongSelf.isPreFetching = NO;

        if (error) {
            NSLog(@"%@ ⚠️ Pre-fetch failed: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            NSLog(@"%@ Will fall back to normal manifest fetch in initializeTracking", [NRMTUtilities logPrefix]);
            return;
        }

        NSLog(@"%@ ✅ Pre-fetch completed: %ld ad break(s), VOD=%@",
              [NRMTUtilities logPrefix], (long)result.adBreaks.count, result.isVOD ? @"YES" : @"NO");

        for (NRMTAdBreak *adBreak in result.adBreaks) {
            NSLog(@"%@    - Ad break: %.2fs to %.2fs (duration: %.2fs)",
                  [NRMTUtilities logPrefix], adBreak.startTime, adBreak.endTime, adBreak.duration);
        }

        // Store pre-fetched result
        strongSelf.preFetchedResult = result;

        // If initializeTracking was already called and is waiting, process the result now
        if (strongSelf.hasInitialized && !strongSelf.isManifestParsed) {
            NSLog(@"%@ Pre-fetch completed after initializeTracking was called - applying now", [NRMTUtilities logPrefix]);
            [strongSelf applyPreFetchedResult];
        }
    }];
}

- (void)applyPreFetchedResult {
    if (!self.preFetchedResult) {
        NSLog(@"%@ No pre-fetched result to apply", [NRMTUtilities logPrefix]);
        return;
    }

    NSLog(@"%@ 🚀 Applying pre-fetched ad schedule", [NRMTUtilities logPrefix]);

    NRMTManifestParserResult *result = self.preFetchedResult;

    // Convert NRMTAdBreak objects from parser to tracker's internal format
    NSMutableArray *parsedAdBreaks = [NSMutableArray array];
    for (NRMTAdBreak *parserAdBreak in result.adBreaks) {
        NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
        adBreak.startTime = parserAdBreak.startTime;
        adBreak.duration = parserAdBreak.duration;
        adBreak.endTime = parserAdBreak.endTime;
        adBreak.pods = [NSMutableArray arrayWithObject:[[NRMTAdPod alloc] init]];
        [parsedAdBreaks addObject:adBreak];
    }

    self.adSchedule = parsedAdBreaks;

    // Set stream type from pre-fetched data
    self.streamType = result.isVOD ? NRMTStreamTypeVOD : NRMTStreamTypeLive;
    self.manifestTargetDuration = result.targetDuration;

    // Set tracking URL from pre-fetched data
    if (result.trackingURL) {
        self.trackingUrl = [NSURL URLWithString:result.trackingURL];
    }

    NSLog(@"%@ ✅ Pre-fetched ad schedule applied: %ld ad break(s)", [NRMTUtilities logPrefix], (long)self.adSchedule.count);

    // Mark manifest as parsed and send PLAYER_READY immediately
    self.isManifestParsed = YES;
    [self sendStart];

    // Still fetch tracking API for metadata enrichment (async, won't delay events)
    if (self.trackingUrl) {
        [self fetchTrackingMetadata];
    }
}

- (void)initializeTracking {
    // Ensure we have the MediaTailor endpoint URL
    if (!self.mediaTailorEndpoint && self.player && self.player.currentItem) {
        AVAsset *asset = self.player.currentItem.asset;
        if ([asset isKindOfClass:[AVURLAsset class]]) {
            NSURL *url = [(AVURLAsset *)asset URL];
            self.mediaTailorEndpoint = url;
            self.manifestType = [NRMTUtilities detectManifestTypeFromURL:url];
            NSLog(@"%@ Detected MediaTailor endpoint during initialization: %@", [NRMTUtilities logPrefix], url);
        } else {
            NSLog(@"%@ ERROR: Cannot detect MediaTailor URL - asset is not AVURLAsset", [NRMTUtilities logPrefix]);
            return;
        }
    }

    if (!self.mediaTailorEndpoint) {
        NSLog(@"%@ ERROR: Cannot initialize tracking without MediaTailor endpoint URL", [NRMTUtilities logPrefix]);
        return;
    }

    self.hasInitialized = YES;

    // 🚀 CHECK FOR PRE-FETCHED AD SCHEDULE (from automatic pre-fetch)
    if (self.preFetchedResult) {
        NSLog(@"%@ 🚀 Using pre-fetched ad schedule - ZERO DELAY!", [NRMTUtilities logPrefix]);
        [self applyPreFetchedResult];
        return; // Skip normal manifest fetch flow
    }

    // Check if pre-fetch is still in progress
    if (self.isPreFetching) {
        NSLog(@"%@ ⏳ Pre-fetch in progress, waiting for completion...", [NRMTUtilities logPrefix]);
        // Pre-fetch will call applyPreFetchedResult when done (see preFetchManifest completion handler)
        return;
    }

    // No pre-fetch available or failed - fall back to normal flow
    NSLog(@"%@ No pre-fetched data available, using normal manifest fetch", [NRMTUtilities logPrefix]);

    // Detect stream type from duration
    NSTimeInterval duration = CMTimeGetSeconds(self.player.currentItem.duration);
    self.streamType = [NRMTUtilities detectStreamTypeFromDuration:duration];

    NSLog(@"%@ Stream type: %@", [NRMTUtilities logPrefix],
          self.streamType == NRMTStreamTypeVOD ? @"VOD" : @"LIVE");
    NSLog(@"%@ Initializing HLS %@ tracking", [NRMTUtilities logPrefix],
          self.streamType == NRMTStreamTypeVOD ? @"VOD" : @"LIVE");

    // Extract tracking URL
    self.trackingUrl = [NRMTUtilities extractTrackingURLFromManifestURL:self.mediaTailorEndpoint];
    if (self.trackingUrl) {
        NSLog(@"%@ Tracking URL: %@", [NRMTUtilities logPrefix], self.trackingUrl.absoluteString);
    } else {
        NSLog(@"%@ No sessionId found - tracking API unavailable", [NRMTUtilities logPrefix]);
    }

    // Set up tracking based on stream type
    if (self.streamType == NRMTStreamTypeVOD) {
        [self setupVODTracking];
    } else {
        [self setupLiveTracking];
    }
}

// MARK: - VOD/Live Setup

- (void)setupVODTracking {
    NSLog(@"%@ VOD mode: Single manifest parse", [NRMTUtilities logPrefix]);
    [self fetchAndParseManifest];
}

- (void)setupLiveTracking {
    NSLog(@"%@ Live mode: Continuous polling", [NRMTUtilities logPrefix]);

    // Initial fetch
    [self fetchAndParseManifest];

    // Start polling timers
    NSTimeInterval manifestInterval = [self.config[@"liveManifestPollInterval"] doubleValue];
    NSTimeInterval trackingInterval = [self.config[@"liveTrackingPollInterval"] doubleValue];

    self.manifestPollTimer = [NSTimer scheduledTimerWithTimeInterval:manifestInterval
                                                              target:self
                                                            selector:@selector(pollManifest:)
                                                            userInfo:nil
                                                             repeats:YES];

    self.trackingPollTimer = [NSTimer scheduledTimerWithTimeInterval:trackingInterval
                                                              target:self
                                                            selector:@selector(pollTracking:)
                                                            userInfo:nil
                                                             repeats:YES];

    NSLog(@"%@ Live polling started (manifest: %.1fs, tracking: %.1fs)",
          [NRMTUtilities logPrefix], manifestInterval, trackingInterval);
}

- (void)stopLivePolling {
    if (self.manifestPollTimer) {
        [self.manifestPollTimer invalidate];
        self.manifestPollTimer = nil;
    }

    if (self.trackingPollTimer) {
        [self.trackingPollTimer invalidate];
        self.trackingPollTimer = nil;
    }

    NSLog(@"%@ Polling stopped", [NRMTUtilities logPrefix]);
}

// MARK: - Manifest Fetching

- (void)fetchAndParseManifest {
    if (self.isDisposed || self.isFetchingManifest) {
        return;
    }

    BOOL enableParsing = [self.config[@"enableManifestParsing"] boolValue];
    if (!enableParsing) {
        NSLog(@"%@ Manifest parsing disabled", [NRMTUtilities logPrefix]);
        return;
    }

    self.isFetchingManifest = YES;

    NSLog(@"%@ Fetching manifest", [NRMTUtilities logPrefix]);

    __weak typeof(self) weakSelf = self;
    self.manifestTask = [NRMTNetworkManager fetchHLSMasterManifest:self.mediaTailorEndpoint
                                                        completion:^(NSString *masterText, NSURL *mediaURL, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.isDisposed) {
            return;
        }

        strongSelf.isFetchingManifest = NO;

        if (error) {
            NSLog(@"%@ Manifest fetch error: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            return;
        }

        if (!mediaURL) {
            NSLog(@"%@ No media playlist URL found", [NRMTUtilities logPrefix]);
            return;
        }

        // Fetch media playlist
        [strongSelf fetchMediaPlaylist:mediaURL];
    }];
}

- (void)fetchMediaPlaylist:(NSURL *)url {
    __weak typeof(self) weakSelf = self;
    [NRMTNetworkManager fetchHLSMediaPlaylist:url completion:^(NSString *manifestText, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.isDisposed) {
            return;
        }

        if (error) {
            NSLog(@"%@ Media playlist fetch error: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            return;
        }

        [strongSelf parseManifest:manifestText];
    }];
}

- (void)parseManifest:(NSString *)manifestText {
    if (!manifestText || [manifestText isEqualToString:self.lastMediaPlaylistText]) {
        return;
    }

    self.lastMediaPlaylistText = manifestText;

    // Extract target duration for live polling optimization
    if (self.manifestTargetDuration == 0) {
        self.manifestTargetDuration = [NRMTManifestParser extractTargetDuration:manifestText];
        if (self.manifestTargetDuration > 0) {
            NSLog(@"%@ Target duration: %.1fs", [NRMTUtilities logPrefix], self.manifestTargetDuration);
            [self updateLivePollingIntervals];
        }
    }

    // Parse for ads
    NSArray<NRMTAdBreak *> *newAds = [NRMTManifestParser parseHLSManifestForAds:manifestText];

    if (newAds.count > 0) {
        NSLog(@"%@ Detected %lu ad break(s)", [NRMTUtilities logPrefix], (unsigned long)newAds.count);
        [self mergeNewAds:newAds];
    }

    // Mark manifest as parsed - this allows onTimeUpdate to start processing
    if (!self.isManifestParsed) {
        self.isManifestParsed = YES;
        NSLog(@"%@ ✅ Manifest parsed - ad tracking ready (playhead will now be monitored)", [NRMTUtilities logPrefix]);
    }

    // Send PLAYER_READY event only once after first manifest parse
    if (!self.hasInitialized) {
        self.hasInitialized = YES;
        NSLog(@"%@ Sending PLAYER_READY event", [NRMTUtilities logPrefix]);
        [self sendVideoEvent:PLAYER_READY];
    }
}

- (void)pollManifest:(NSTimer *)timer {
    [self fetchAndParseManifest];
}

- (void)updateLivePollingIntervals {
    if (self.manifestTargetDuration == 0 || self.streamType != NRMTStreamTypeLive) {
        return;
    }

    NSLog(@"%@ Updating polling intervals to target duration: %.1fs",
          [NRMTUtilities logPrefix], self.manifestTargetDuration);

    // Restart timers with target duration
    [self.manifestPollTimer invalidate];
    [self.trackingPollTimer invalidate];

    self.manifestPollTimer = [NSTimer scheduledTimerWithTimeInterval:self.manifestTargetDuration
                                                              target:self
                                                            selector:@selector(pollManifest:)
                                                            userInfo:nil
                                                             repeats:YES];

    self.trackingPollTimer = [NSTimer scheduledTimerWithTimeInterval:self.manifestTargetDuration
                                                              target:self
                                                            selector:@selector(pollTracking:)
                                                            userInfo:nil
                                                             repeats:YES];
}

// MARK: - Schedule Management

- (void)mergeNewAds:(NSArray<NRMTAdBreak *> *)newAds {
    // Deduplicate by rounded start time
    NSMutableDictionary<NSNumber *, NRMTAdBreak *> *scheduleMap = [NSMutableDictionary dictionary];

    // Add existing ads
    for (NRMTAdBreak *ad in self.adSchedule) {
        NSNumber *key = @(round(ad.startTime));
        scheduleMap[key] = ad;
    }

    // Merge new ads
    for (NRMTAdBreak *newAd in newAds) {
        NSNumber *key = @(round(newAd.startTime));
        NRMTAdBreak *existing = scheduleMap[key];

        if (!existing) {
            [self.adSchedule addObject:newAd];
            scheduleMap[key] = newAd;
        } else if (!existing.confirmedByTracking && newAd.confirmedByTracking) {
            // Update existing with tracking data
            existing.title = newAd.title;
            existing.creativeId = newAd.creativeId;
            existing.confirmedByTracking = newAd.confirmedByTracking;
            existing.pods = newAd.pods;
        }
    }

    // Sort by start time
    [self.adSchedule sortUsingComparator:^NSComparisonResult(NRMTAdBreak *a, NRMTAdBreak *b) {
        return [@(a.startTime) compare:@(b.startTime)];
    }];

    NSLog(@"%@ Ad schedule: %lu ad break(s)", [NRMTUtilities logPrefix], (unsigned long)self.adSchedule.count);

    // VOD: Fetch tracking metadata after first manifest parse
    if (self.streamType == NRMTStreamTypeVOD && self.trackingUrl && !self.hasAttemptedTrackingFetch) {
        self.hasAttemptedTrackingFetch = YES;
        [self fetchTrackingMetadata];
    }
}

// MARK: - Tracking API

- (void)fetchTrackingMetadata {
    if (self.isDisposed || !self.trackingUrl || self.isFetchingTracking) {
        return;
    }

    self.isFetchingTracking = YES;

    NSLog(@"%@ Fetching tracking metadata", [NRMTUtilities logPrefix]);

    NSTimeInterval timeout = [self.config[@"trackingAPITimeout"] doubleValue];

    __weak typeof(self) weakSelf = self;
    self.trackingTask = [NRMTNetworkManager fetchTrackingMetadata:self.trackingUrl
                                                          timeout:timeout
                                                       completion:^(NRMTTrackingResponse *response, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.isDisposed) {
            return;
        }

        strongSelf.isFetchingTracking = NO;

        if (error) {
            NSLog(@"%@ Tracking API error: %@", [NRMTUtilities logPrefix], error.localizedDescription);

            // Retry once
            if (strongSelf.trackingFetchRetries < strongSelf.maxTrackingRetries) {
                strongSelf.trackingFetchRetries++;
                NSLog(@"%@ Retrying tracking fetch (%ld/%ld)", [NRMTUtilities logPrefix],
                      (long)strongSelf.trackingFetchRetries, (long)strongSelf.maxTrackingRetries);
                [strongSelf fetchTrackingMetadata];
            } else {
                NSLog(@"%@ Max retries reached, continuing with manifest data", [NRMTUtilities logPrefix]);
            }
            return;
        }

        if (response.avails.count > 0) {
            NSLog(@"%@ Enriching with %lu avail(s)", [NRMTUtilities logPrefix], (unsigned long)response.avails.count);
            [strongSelf enrichWithTrackingMetadata:response.avails];
            strongSelf.trackingFetchRetries = 0;
        } else {
            NSLog(@"%@ Tracking API returned 0 avails", [NRMTUtilities logPrefix]);
        }
    }];
}

- (void)pollTracking:(NSTimer *)timer {
    [self fetchTrackingMetadata];
}

- (void)enrichWithTrackingMetadata:(NSArray<NRMTTrackingAvail *> *)avails {
    // Match avails to ad breaks by start time
    for (NRMTTrackingAvail *avail in avails) {
        NSInteger index = [NRMTUtilities findAdBreakIndex:self.adSchedule startTime:avail.startTimeInSeconds];

        if (index != NSNotFound) {
            // Update existing ad break
            NRMTAdBreak *adBreak = self.adSchedule[index];
            adBreak.confirmedByTracking = YES;
            adBreak.source = NRMTAdSourceManifestAndTracking;

            // Enrich with tracking ads (pods)
            if (avail.ads.count > 0) {
                [adBreak.pods removeAllObjects];
                for (NRMTTrackingAd *trackingAd in avail.ads) {
                    NRMTAdPod *pod = [[NRMTAdPod alloc] init];
                    pod.title = trackingAd.adTitle;
                    pod.creativeId = trackingAd.adId;
                    pod.startTime = adBreak.startTime + trackingAd.startTimeInSeconds;
                    pod.duration = trackingAd.durationInSeconds;
                    pod.endTime = pod.startTime + pod.duration;
                    [adBreak.pods addObject:pod];
                }
            }
        } else {
            // Add new ad break from tracking API
            NRMTAdBreak *adBreak = [[NRMTAdBreak alloc] init];
            adBreak.breakId = avail.availId;
            adBreak.startTime = avail.startTimeInSeconds;
            adBreak.duration = avail.durationInSeconds;
            adBreak.endTime = adBreak.startTime + adBreak.duration;
            adBreak.source = NRMTAdSourceTrackingAPI;
            adBreak.confirmedByTracking = YES;

            // Add pods from tracking ads
            for (NRMTTrackingAd *trackingAd in avail.ads) {
                NRMTAdPod *pod = [[NRMTAdPod alloc] init];
                pod.title = trackingAd.adTitle;
                pod.creativeId = trackingAd.adId;
                pod.startTime = adBreak.startTime + trackingAd.startTimeInSeconds;
                pod.duration = trackingAd.durationInSeconds;
                pod.endTime = pod.startTime + pod.duration;
                [adBreak.pods addObject:pod];
            }

            [self.adSchedule addObject:adBreak];
        }
    }

    // Re-sort schedule
    [self.adSchedule sortUsingComparator:^NSComparisonResult(NRMTAdBreak *a, NRMTAdBreak *b) {
        return [@(a.startTime) compare:@(b.startTime)];
    }];

    NSLog(@"%@ Enrichment complete: %lu ad break(s)", [NRMTUtilities logPrefix], (unsigned long)self.adSchedule.count);
}

// MARK: - Time Update & Event Tracking

- (void)onTimeUpdate {
    if (self.isDisposed || !self.player) {
        return;
    }

    // Don't process time updates until manifest is parsed and ad schedule is ready
    if (!self.isManifestParsed) {
        return;
    }

    NSTimeInterval currentTime = CMTimeGetSeconds(self.player.currentTime);
    if (isnan(currentTime) || currentTime < 0) {
        return;
    }

    // Log playhead position during ad breaks
    static NSTimeInterval lastLoggedTime = -1;
    if (self.currentAdBreak && (lastLoggedTime < 0 || (currentTime - lastLoggedTime) >= 1.0)) {
        NSLog(@"%@ ⏱️ Playhead: %.2fs (in ad break)", [NRMTUtilities logPrefix], currentTime);
        lastLoggedTime = currentTime;
    }

    NRMTAdBreak *activeAdBreak = [NRMTUtilities findActiveAdBreak:self.adSchedule currentTime:currentTime];

    if (activeAdBreak) {
        // === INSIDE AD BREAK ===
        [self handleInsideAdBreak:activeAdBreak currentTime:currentTime];
    } else if (self.currentAdBreak) {
        // === EXITING AD BREAK ===
        NSLog(@"%@ ⏱️ Exiting ad break at playhead: %.2fs (break endTime was %.2fs)",
              [NRMTUtilities logPrefix], currentTime, self.currentAdBreak.endTime);
        [self handleExitingAdBreak];
    }
}

- (void)handleInsideAdBreak:(NRMTAdBreak *)activeAdBreak currentTime:(NSTimeInterval)currentTime {
    // Fire AD_BREAK_START once
    if (!activeAdBreak.hasFiredStart) {
        self.currentAdBreak = activeAdBreak;
        [self.state setIsAd:YES];

        NSLog(@"%@ setIsAd(true) - Entering ad break at playhead %.2fs", [NRMTUtilities logPrefix], currentTime);

        // Calculate ad position
        NSInteger adBreakIndex = [self.adSchedule indexOfObject:activeAdBreak];
        NRMTAdPosition adPosition = [NRMTUtilities determineAdPosition:adBreakIndex
                                                        totalAdBreaks:self.adSchedule.count
                                                           streamType:self.streamType];
        activeAdBreak.adPosition = adPosition;

        NSLog(@"%@ → AD_BREAK_START (startTime=%.2f, endTime=%.2f, duration=%.2f, pods=%lu, position=%@)",
              [NRMTUtilities logPrefix], activeAdBreak.startTime, activeAdBreak.endTime, activeAdBreak.duration,
              (unsigned long)activeAdBreak.pods.count, [self getAdPosition]);

        [self sendAdBreakStart];
        activeAdBreak.hasFiredStart = YES;
    }

    // Check for pod-level tracking
    if (activeAdBreak.pods.count > 0) {
        [self handlePodTracking:activeAdBreak currentTime:currentTime];
    } else {
        [self handleNoPodTracking:activeAdBreak currentTime:currentTime];
    }
}

- (void)handlePodTracking:(NRMTAdBreak *)activeAdBreak currentTime:(NSTimeInterval)currentTime {
    NRMTAdPod *activePod = [NRMTUtilities findActivePod:activeAdBreak currentTime:currentTime];

    if (activePod) {
        // Entering new pod
        if (!self.currentAdPod || self.currentAdPod != activePod) {
            // End previous pod
            if (self.currentAdPod) {
                NSLog(@"%@ → AD_END (pod transition)", [NRMTUtilities logPrefix]);
                [self sendEnd];
            }

            // Start new pod
            self.currentAdPod = activePod;

            NSLog(@"%@ → AD_REQUEST", [NRMTUtilities logPrefix]);
            [self sendRequest];

            NSLog(@"%@ → AD_START (new pod, startTime=%.2f, duration=%.2f, position=%@, currentPlayhead=%.2f, progress=%.2f)",
                  [NRMTUtilities logPrefix], activePod.startTime, activePod.duration, [self getAdPosition], currentTime, currentTime - activePod.startTime);
            [self sendStart];
            activePod.hasFiredStart = YES;
        }

        // Track quartiles for pod
        NSTimeInterval podProgress = currentTime - activePod.startTime;
        [self trackQuartiles:activePod progress:podProgress];
    }
}

- (void)handleNoPodTracking:(NRMTAdBreak *)activeAdBreak currentTime:(NSTimeInterval)currentTime {
    // No pods - treat entire break as single ad
    if (!activeAdBreak.hasFiredAdStart) {
        NSLog(@"%@ → AD_REQUEST", [NRMTUtilities logPrefix]);
        [self sendRequest];

        NSLog(@"%@ → AD_START (no pods, startTime=%.2f, duration=%.2f, position=%@)",
              [NRMTUtilities logPrefix], activeAdBreak.startTime, activeAdBreak.duration, [self getAdPosition]);
        [self sendStart];
        activeAdBreak.hasFiredAdStart = YES;
    }

    // Track quartiles for entire break
    NSTimeInterval adProgress = currentTime - activeAdBreak.startTime;
    [self trackQuartilesForBreak:activeAdBreak progress:adProgress];
}

- (void)handleExitingAdBreak {
    // End last pod
    if (self.currentAdPod) {
        NSLog(@"%@ → AD_END (final pod)", [NRMTUtilities logPrefix]);
        [self sendEnd];
        self.currentAdPod = nil;
    }

    // End ad break
    if (!self.currentAdBreak.hasFiredEnd) {
        NSLog(@"%@ → AD_BREAK_END", [NRMTUtilities logPrefix]);
        [self sendAdBreakEnd];
        self.currentAdBreak.hasFiredEnd = YES;
    }

    self.currentAdBreak = nil;
    [self.state setIsAd:NO];
    NSLog(@"%@ setIsAd(false) - Exiting ad break", [NRMTUtilities logPrefix]);

    // Check if video ended after last ad break
    BOOL isEnded = CMTimeCompare(self.player.currentTime, self.player.currentItem.duration) >= 0;
    if (isEnded && !self.hasEndedContent) {
        NSLog(@"%@ → CONTENT_END (after last ad)", [NRMTUtilities logPrefix]);
        [self sendEnd];
        self.hasEndedContent = YES;
    }
}

// MARK: - Quartile Tracking

- (void)trackQuartiles:(NRMTAdPod *)pod progress:(NSTimeInterval)progress {
    NSDictionary *firedFlags = @{
        @"q1": @(pod.hasFiredQ1),
        @"q2": @(pod.hasFiredQ2),
        @"q3": @(pod.hasFiredQ3)
    };

    NSArray<NSNumber *> *quartilesToFire = [NRMTUtilities getQuartilesToFireForProgress:progress
                                                                                duration:pod.duration
                                                                             firedFlags:firedFlags];

    for (NSNumber *quartile in quartilesToFire) {
        NSInteger q = [quartile integerValue];
        NSLog(@"%@ → AD_QUARTILE %ld%%", [NRMTUtilities logPrefix], (long)(q * 25));
        [self sendAdQuartile];

        if (q == 1) pod.hasFiredQ1 = YES;
        else if (q == 2) pod.hasFiredQ2 = YES;
        else if (q == 3) pod.hasFiredQ3 = YES;
    }
}

- (void)trackQuartilesForBreak:(NRMTAdBreak *)adBreak progress:(NSTimeInterval)progress {
    NSDictionary *firedFlags = @{
        @"q1": @(adBreak.hasFiredQ1),
        @"q2": @(adBreak.hasFiredQ2),
        @"q3": @(adBreak.hasFiredQ3)
    };

    NSArray<NSNumber *> *quartilesToFire = [NRMTUtilities getQuartilesToFireForProgress:progress
                                                                                duration:adBreak.duration
                                                                             firedFlags:firedFlags];

    for (NSNumber *quartile in quartilesToFire) {
        NSInteger q = [quartile integerValue];
        NSLog(@"%@ → AD_QUARTILE %ld%%", [NRMTUtilities logPrefix], (long)(q * 25));
        [self sendAdQuartile];

        if (q == 1) adBreak.hasFiredQ1 = YES;
        else if (q == 2) adBreak.hasFiredQ2 = YES;
        else if (q == 3) adBreak.hasFiredQ3 = YES;
    }
}

// MARK: - Player Events

- (void)playerItemDidPlayToEndTime:(NSNotification *)notification {
    if (!self.hasEndedContent) {
        NSLog(@"%@ → CONTENT_END", [NRMTUtilities logPrefix]);
        [self sendEnd];
        self.hasEndedContent = YES;
    }
}

@end
