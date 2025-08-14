//
//  NRVAVideo.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideo.h"
#import "NRVAVideoConfiguration.h"
#import "NRVAVideoPlayerConfiguration.h"
#import "NRVAHarvestManager.h"
#import "Utils/NRVALog.h"
#import "NRVAUtils.h"
#import "NewRelicVideoAgent.h"
#import "Tracker/NRTracker.h"
#import <AVFoundation/AVFoundation.h>

// Import IMA types for the convenience methods
#if __has_include(<GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>)
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#endif

// Forward declarations for runtime loading
@class NRTrackerAVPlayer;

@interface NRVAVideo ()

@property (nonatomic, strong) NRVAHarvestManager *harvestManager;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *trackerIds;
@property (nonatomic, assign) NSInteger nextTrackerId;

@end

@implementation NRVAVideo

// Singleton instance
static NRVAVideo *instance = nil;
static dispatch_once_t onceToken;

#pragma mark - Singleton Management

+ (instancetype)getInstance {
    return instance;
}

+ (BOOL)isInitialized {
    return instance != nil;
}

+ (NRVAVideoBuilder *)newBuilder {
    return [[NRVAVideoBuilder alloc] init];
}

#pragma mark - Player Management

+ (NSInteger)addPlayer:(NRVAVideoPlayerConfiguration *)config {
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"NRVAVideo not initialized - cannot add player");
        @throw [NSException exceptionWithName:@"IllegalStateException"
                                       reason:@"NRVAVideo is not initialized. Call [[NRVAVideo newBuilder] withConfiguration:config].build first."
                                     userInfo:nil];
    }
    
    if (!config) {
        NRVA_ERROR_LOG(@"Player configuration cannot be nil");
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Player configuration cannot be nil"
                                     userInfo:nil];
    }
    
    NRVAVideo *videoInstance = [self getInstance];
    
    // Check if there's already a tracker for this player name and clean it up
    @synchronized (videoInstance.trackerIds) {
        NSNumber *existingTrackerId = videoInstance.trackerIds[config.playerName];
        if (existingTrackerId) {
            NRVA_LOG(@"Found existing tracker %@ for player '%@', cleaning up before creating new one", existingTrackerId, config.playerName);
            
            // Release the existing tracker
            [[NewRelicVideoAgent sharedInstance] releaseTracker:existingTrackerId];
            [videoInstance.trackerIds removeObjectForKey:config.playerName];
            NRVA_DEBUG_LOG(@"Released existing tracker %@ for player '%@'", existingTrackerId, config.playerName);
        }
    }
    
    NSInteger trackerId = videoInstance.nextTrackerId++;
    
    // Store new tracker mapping
    @synchronized (videoInstance.trackerIds) {
        videoInstance.trackerIds[config.playerName] = @(trackerId);
    }
    
    // Create content tracker
    id contentTracker = nil;
    if (config.player) {
        contentTracker = [self createContentTracker];
        if (contentTracker) {
            NRVA_DEBUG_LOG(@"Created content tracker for player '%@'", config.playerName);
        } else {
            NRVA_ERROR_LOG(@"Failed to create content tracker for player '%@'", config.playerName);
        }
    } else {
        NRVA_DEBUG_LOG(@"No player instance provided in config for '%@', content tracker not created", config.playerName);
    }
    
    // Create ad tracker
    id adTracker = nil;
    if (config.isAdEnabled) {
        adTracker = [self createAdTracker];
        if (adTracker) {
            NRVA_DEBUG_LOG(@"Created ad tracker for player '%@'", config.playerName);
        } else {
            NRVA_ERROR_LOG(@"Failed to create ad tracker for player '%@'", config.playerName);
        }
    } else {
        NRVA_DEBUG_LOG(@"Ad tracking disabled for player '%@', ad tracker not created", config.playerName);
    }

    // Start tracking with NewRelicVideoAgent 
    if (contentTracker || adTracker) {
        NSNumber *newTrackerId = [[NewRelicVideoAgent sharedInstance] startWithContentTracker:contentTracker adTracker:adTracker];
        
        // Update our trackerId to match the one returned by NewRelicVideoAgent
        trackerId = [newTrackerId integerValue];
        
        // Update tracker mapping with the correct ID
        @synchronized (videoInstance.trackerIds) {
            videoInstance.trackerIds[config.playerName] = newTrackerId;
        }
        
        NRVA_LOG(@"Started tracking for player '%@' with tracker ID: %ld", config.playerName, (long)trackerId);
        
        // Set player instance after tracker initialization
        if (contentTracker && config.player && [contentTracker respondsToSelector:@selector(setPlayer:)]) {
            [contentTracker setPlayer:config.player];
            NRVA_DEBUG_LOG(@"Set player instance on content tracker for '%@'", config.playerName);
        }
    } else {
        NRVA_ERROR_LOG(@"No trackers created for player '%@', tracking not started", config.playerName);
    }
    
    // Set custom attributes directly on the trackers
    if (config.customAttributes && config.customAttributes.count > 0) {
        for (NSString *key in config.customAttributes) {
            [self setAttribute:trackerId key:key value:config.customAttributes[key]];
            NRVA_DEBUG_LOG(@"Set custom attribute for tracker %ld: %@ = %@", (long)trackerId, key, config.customAttributes[key]);
        }
    }
    
    return trackerId;
}

+ (void)releaseTracker:(NSInteger)trackerId {
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"NRVAVideo not initialized - cannot release tracker");
        @throw [NSException exceptionWithName:@"IllegalStateException"
                                       reason:@"NRVAVideo is not initialized."
                                     userInfo:nil];
    }
    
    // Handle invalid tracker IDs gracefully
    if (trackerId <= 0) {
        NRVA_DEBUG_LOG(@"Invalid tracker ID %ld - skipping release", (long)trackerId);
        return;
    }
    
    NRVAVideo *videoInstance = [self getInstance];
    
    // Find and remove from tracker mapping
    @synchronized (videoInstance.trackerIds) {
        NSString *playerName = nil;
        for (NSString *name in videoInstance.trackerIds.allKeys) {
            if ([videoInstance.trackerIds[name] integerValue] == trackerId) {
                playerName = name;
                break;
            }
        }
        
        if (playerName) {
            [videoInstance.trackerIds removeObjectForKey:playerName];
        }
    }
    
    // Use existing NewRelicVideoAgent releaseTracker method
    [[NewRelicVideoAgent sharedInstance] releaseTracker:@(trackerId)];
    
    NRVA_LOG(@"Released tracker with ID: %ld", (long)trackerId);
}

+ (void)releaseTrackerWithPlayerName:(NSString *)playerName {
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"NRVAVideo not initialized - cannot release tracker");
        @throw [NSException exceptionWithName:@"IllegalStateException"
                                       reason:@"NRVAVideo is not initialized."
                                     userInfo:nil];
    }
    
    if (!playerName) {
        NRVA_ERROR_LOG(@"Player name cannot be nil");
        return;
    }
    
    NRVAVideo *videoInstance = [self getInstance];
    NSInteger trackerId = 0;
    
    @synchronized (videoInstance.trackerIds) {
        NSNumber *trackerIdNumber = videoInstance.trackerIds[playerName];
        if (trackerIdNumber) {
            trackerId = [trackerIdNumber integerValue];
        }
    }

    [self releaseTracker:trackerId];
}

#pragma mark - Event Recording

+ (void)recordCustomEvent:(NSString *)action trackerId:(NSNumber * _Nullable)trackerId attributes:(NSDictionary<NSString *, id> *)attributes {
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"recordCustomEvent called before NRVAVideo is fully initialized - event dropped");
        return;
    }
    
    if (!action) {
        NRVA_ERROR_LOG(@"Action parameter is mandatory for custom events");
        return;
    }
    
    if (trackerId) {
        // Tracker-specific event
        NRTracker *contentTracker = [[NewRelicVideoAgent sharedInstance] contentTracker:trackerId];
        if (contentTracker) {
            // Use the tracker's sendEvent method which automatically uses VideoCustomAction eventType
            [contentTracker sendEvent:action attributes:attributes];
            NRVA_DEBUG_LOG(@"📊 Recorded tracker-specific custom event via content tracker %@: action: %@ with enriched attributes", trackerId, action);
        } else {
            NRVA_ERROR_LOG(@"No content tracker found for tracker ID: %@ - dropping custom event: %@", trackerId, action);
        }
    } else {
        // Global event - send to all trackers
        NRVAVideo *videoInstance = [self getInstance];
        
        @synchronized (videoInstance.trackerIds) {
            if (videoInstance.trackerIds.count == 0) {
                NRVA_ERROR_LOG(@"No trackers available - dropping global custom event: %@", action);
                return;
            }
            
            // Send to all trackers
            for (NSNumber *currentTrackerId in videoInstance.trackerIds.allValues) {
                NRTracker *contentTracker = [[NewRelicVideoAgent sharedInstance] contentTracker:currentTrackerId];
                if (contentTracker) {
                    [contentTracker sendEvent:action attributes:attributes];
                    NRVA_DEBUG_LOG(@"📊 Sent global custom event to tracker %@: action: %@ with enriched attributes", currentTrackerId, action);
                }
            }
        }
    }
}

#pragma mark - Attribute Management

+ (void)setUserId:(NSString *)userId {
    if (!userId) {
        NRVA_ERROR_LOG(@"User ID cannot be nil");
        return;
    }
    
    // Use existing NewRelicVideoAgent setUserId function
    [[NewRelicVideoAgent sharedInstance] setUserId:userId];
}

+ (void)setAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value action:(NSString *)action {
    if (!key || !value) {
        NRVA_ERROR_LOG(@"Attribute key and value cannot be nil");
        return;
    }
    
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"NRVAVideo not initialized - cannot set attribute");
        return;
    }
    
    // Get content tracker from existing NewRelicVideoAgent
    NRTracker *contentTracker = [[NewRelicVideoAgent sharedInstance] contentTracker:@(trackerId)];
    if (contentTracker) {
        if (action) {
            [contentTracker setAttribute:key value:value forAction:action];
        } else {
            [contentTracker setAttribute:key value:value];
        }
        NRVA_DEBUG_LOG(@"Set attribute for tracker %ld: %@ = %@", (long)trackerId, key, value);
    } else {
        NRVA_ERROR_LOG(@"No content tracker found for tracker ID: %ld", (long)trackerId);
    }
}

+ (void)setAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value {
    [self setAttribute:trackerId key:key value:value action:nil];
}

+ (void)setAdAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value action:(NSString *)action {
    if (!key || !value) {
        NRVA_ERROR_LOG(@"Ad attribute key and value cannot be nil");
        return;
    }
    
    if (![self isInitialized]) {
        NRVA_ERROR_LOG(@"NRVAVideo not initialized - cannot set ad attribute");
        return;
    }
    
    // Get ad tracker from existing NewRelicVideoAgent
    NRTracker *adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:@(trackerId)];
    if (adTracker) {
        if (action) {
            [adTracker setAttribute:key value:value forAction:action];
        } else {
            [adTracker setAttribute:key value:value];
        }
        NRVA_DEBUG_LOG(@"Set ad attribute for tracker %ld: %@ = %@", (long)trackerId, key, value);
    } else {
        NRVA_ERROR_LOG(@"No ad tracker found for tracker ID: %ld", (long)trackerId);
    }
}

+ (void)setAdAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value {
    [self setAdAttribute:trackerId key:key value:value action:nil];
}

+ (void)setGlobalAttribute:(NSString *)key value:(id)value action:(NSString *)action {
    if (!key || !value) {
        NRVA_ERROR_LOG(@"Global attribute key and value cannot be nil");
        return;
    }
    
    // Use existing NewRelicVideoAgent setGlobalAttribute method
    if (action) {
        [[NewRelicVideoAgent sharedInstance] setGlobalAttribute:key value:value forAction:action];
    } else {
        [[NewRelicVideoAgent sharedInstance] setGlobalAttribute:key value:value];
    }
}

+ (void)setGlobalAttribute:(NSString *)key value:(id)value {
    [self setGlobalAttribute:key value:value action:nil];
}

#pragma mark - Internal Methods (Package Private)

+ (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes {
    // Simple event recording method - no validation, just direct recording
    if ([self isInitialized]) {
        NRVAVideo *videoInstance = [self getInstance];
        [videoInstance.harvestManager recordEvent:eventType attributes:attributes];
        NRVA_DEBUG_LOG(@"📊 Recorded event: %@ with attributes %@", eventType, attributes);
    } else {
        NRVA_ERROR_LOG(@"recordEvent called before NRVAVideo is fully initialized - event dropped: %@", eventType);
    }
}

#pragma mark - Tracker Creation (Internal Methods)

/**
 * Creates a content tracker for AVPlayer
 * Creates tracker without player, then sets player after initialization
 */
+ (id)createContentTracker {
    // Create NRTrackerAVPlayer without player
    // Player will be set after tracker initialization
    Class trackerClass = NSClassFromString(@"NRTrackerAVPlayer");
    if (!trackerClass) {
        NRVA_ERROR_LOG(@"NRTrackerAVPlayer class not found - ensure NRAVPlayerTracker pod is installed");
        return nil;
    }
    
    // Create tracker using default constructor (no player parameter)
    id tracker = [[trackerClass alloc] init];
    if (tracker) {
        NRVA_DEBUG_LOG(@"Created content tracker (without player)");
        return tracker;
    } else {
        NRVA_ERROR_LOG(@"Failed to create NRTrackerAVPlayer instance");
        return nil;
    }
}

/**
 * Creates an ad tracker for IMA
 * Uses dynamic class loading with graceful fallback
 */
+ (id)createAdTracker {
    // Dynamic class loading with graceful fallback
    Class trackerClass = NSClassFromString(@"NRTrackerIMA");
    if (!trackerClass) {
        NRVA_ERROR_LOG(@"NRTrackerIMA class not found - ensure NRIMATracker pod is installed");
        return nil;
    }
    
    // Standard initialization without parameters
    id adTracker = [[trackerClass alloc] init];
    if (adTracker) {
        NRVA_DEBUG_LOG(@"Created IMA ad tracker");
        return adTracker;
    } else {
        NRVA_ERROR_LOG(@"Failed to create NRTrackerIMA instance");
        return nil;
    }
}

#pragma mark - Initialization

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)config {
    self = [super init];
    if (self) {
        _harvestManager = [[NRVAHarvestManager alloc] initWithConfiguration:config];
        _trackerIds = [[NSMutableDictionary alloc] init];
        _nextTrackerId = 1;
        
        // Configure logging using existing NewRelicVideoAgent
        if (config.debugLoggingEnabled) {
            [[NewRelicVideoAgent sharedInstance] setLogging:YES];
        }
        
        // Start harvesting
        [_harvestManager startHarvesting];
        
        NRVA_LOG(@"NRVAVideo initialized successfully with token: %@", config.applicationToken);
    }
    return self;
}

- (void)dealloc {
    [self.harvestManager stopHarvesting];
}

#pragma mark - SIMPLIFIED AD EVENT API

+ (void)handleAdEvent:(NSNumber *)trackerId event:(IMAAdEvent *)event adsManager:(IMAAdsManager *)adsManager {
    // Access ad tracker directly from NewRelicVideoAgent (no helper method needed)
    id adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:trackerId];
    if (adTracker && [adTracker respondsToSelector:@selector(handleAdEvent:adsManager:)]) {
        // Use performSelector to avoid compiler warnings about unknown methods
        NSMethodSignature *methodSignature = [adTracker methodSignatureForSelector:@selector(handleAdEvent:adsManager:)];
        if (methodSignature) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
            [invocation setTarget:adTracker];
            [invocation setSelector:@selector(handleAdEvent:adsManager:)];
            [invocation setArgument:&event atIndex:2];
            [invocation setArgument:&adsManager atIndex:3];
            [invocation invoke];
        }
    }
}

+ (void)handleAdError:(NSNumber *)trackerId error:(IMAAdError *)error adsManager:(IMAAdsManager *)adsManager {
    // Note: NRTrackerIMA.handleAdError only takes one parameter (the error), ignoring adsManager
    id adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:trackerId];
    if (adTracker && [adTracker respondsToSelector:@selector(handleAdError:)]) {
        // Use performSelector to avoid compiler warnings about unknown methods
        [adTracker performSelector:@selector(handleAdError:) withObject:error];
    }
}

+ (void)handleAdError:(NSNumber *)trackerId error:(IMAAdError *)error {
    id adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:trackerId];
    if (adTracker && [adTracker respondsToSelector:@selector(handleAdError:)]) {
        // Use performSelector to avoid compiler warnings about unknown methods
        [adTracker performSelector:@selector(handleAdError:) withObject:error];
    }
}

+ (void)sendAdBreakStart:(NSNumber *)trackerId {
    id adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:trackerId];
    if (adTracker && [adTracker respondsToSelector:@selector(sendAdBreakStart)]) {
        // Use performSelector to avoid compiler warnings about unknown methods
        [adTracker performSelector:@selector(sendAdBreakStart)];
    }
}

+ (void)sendAdBreakEnd:(NSNumber *)trackerId {
    id adTracker = [[NewRelicVideoAgent sharedInstance] adTracker:trackerId];
    if (adTracker && [adTracker respondsToSelector:@selector(sendAdBreakEnd)]) {
        // Use performSelector to avoid compiler warnings about unknown methods
        [adTracker performSelector:@selector(sendAdBreakEnd)];
    }
}

@end

#pragma mark - Builder Implementation

@interface NRVAVideoBuilder ()

@property (nonatomic, strong) NRVAVideoConfiguration *config;

@end

@implementation NRVAVideoBuilder

- (instancetype)withConfiguration:(NRVAVideoConfiguration *)config {
    self.config = config;
    return self;
}

- (NRVAVideo *)build {
    if (!self.config) {
        @throw [NSException exceptionWithName:@"IllegalStateException"
                                       reason:@"Configuration is required - call withConfiguration()"
                                     userInfo:nil];
    }
    
    // Thread-safe initialization
    dispatch_once(&onceToken, ^{
        if (instance == nil) {
            instance = [[NRVAVideo alloc] initWithConfiguration:self.config];
        }
    });
    
    // Check if initialization succeeded
    if (instance == nil) {
        @throw [NSException exceptionWithName:@"RuntimeException"
                                       reason:@"Failed to initialize NRVAVideo instance"
                                     userInfo:nil];
    }
    
    return instance;
}

@end
