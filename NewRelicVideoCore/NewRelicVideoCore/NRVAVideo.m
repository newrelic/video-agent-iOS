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
#import "NRVALog.h"
#import "NRVAUtils.h"
#import "NewRelicVideoAgent.h"
#import "Tracker/NRTracker.h"
#import <AVFoundation/AVFoundation.h>

// Forward declarations for runtime loading
@class NRTrackerAVPlayer;
@class NRTrackerIMA;

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
    NSInteger trackerId = videoInstance.nextTrackerId++;
    
    // Store tracker mapping
    @synchronized (videoInstance.trackerIds) {
        videoInstance.trackerIds[config.playerName] = @(trackerId);
    }
    
    // Create content tracker (equivalent to Android's createContentTracker)
    id contentTracker = nil;
    if (config.player) {
        contentTracker = [self createContentTracker:config.player];
        if (contentTracker) {
            NRVA_DEBUG_LOG(@"Created content tracker for player '%@'", config.playerName);
        } else {
            NRVA_ERROR_LOG(@"Failed to create content tracker for player '%@'", config.playerName);
        }
    } else {
        NRVA_DEBUG_LOG(@"No player instance provided in config for '%@', content tracker not created", config.playerName);
    }
    
    // Create ad tracker (equivalent to Android's createAdTracker)
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
    
    // Start tracking with NewRelicVideoAgent (equivalent to Android's NewRelicVideoAgent.start())
    if (contentTracker || adTracker) {
        [[NewRelicVideoAgent sharedInstance] startWithContentTracker:contentTracker adTracker:adTracker];
        NRVA_LOG(@"Started tracking for player '%@' with tracker ID: %ld", config.playerName, (long)trackerId);
        
        // Set player instance on the content tracker if available
        if (contentTracker && [contentTracker respondsToSelector:@selector(setPlayer:)]) {
            [contentTracker setPlayer:config.player];
            NRVA_DEBUG_LOG(@"Set player instance on content tracker for '%@'", config.playerName);
        }
    } else {
        NRVA_ERROR_LOG(@"No trackers created for player '%@', tracking not started", config.playerName);
    }
    
    // Set custom attributes directly on the trackers (matching Android behavior)
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
            [videoInstance.trackerIds removeObjectForKey:playerName];
        }
    }
    
    if (trackerId > 0) {
        // Use existing NewRelicVideoAgent releaseTracker method
        [[NewRelicVideoAgent sharedInstance] releaseTracker:@(trackerId)];
        NRVA_LOG(@"Released tracker '%@' with ID: %ld", playerName, (long)trackerId);
    } else {
        NRVA_ERROR_LOG(@"No tracker found for player name: %@", playerName);
    }
}

#pragma mark - Event Recording

+ (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes {
    if ([self isInitialized]) {
        NRVAVideo *videoInstance = [self getInstance];
        [videoInstance.harvestManager recordEvent:eventType attributes:attributes];
    } else {
        NRVA_ERROR_LOG(@"recordEvent called before NRVAVideo is fully initialized - event dropped: %@", eventType);
    }
}

+ (void)recordCustomEvent:(NSDictionary<NSString *, id> *)attributes {
    [self recordEvent:@"VideoCustomAction" attributes:attributes];
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

#pragma mark - Tracker Creation (Internal Methods)

/**
 * Creates a content tracker for AVPlayer (equivalent to Android's createContentTracker)
 * Uses runtime class loading to avoid circular dependencies
 */
+ (id)createContentTracker:(id)player {
    if (!player) {
        NRVA_ERROR_LOG(@"Player cannot be nil when creating content tracker");
        return nil;
    }
    
    if (![player isKindOfClass:[AVPlayer class]]) {
        NRVA_ERROR_LOG(@"Player must be an AVPlayer instance for content tracking");
        return nil;
    }
    
    // Use runtime class loading to avoid circular dependency
    Class trackerClass = NSClassFromString(@"NRTrackerAVPlayer");
    if (!trackerClass) {
        NRVA_ERROR_LOG(@"NRTrackerAVPlayer class not found - ensure NRAVPlayerTracker pod is installed");
        return nil;
    }
    
    // Create instance using runtime method invocation
    SEL initSelector = @selector(initWithAVPlayer:);
    if ([trackerClass instancesRespondToSelector:initSelector]) {
        id trackerInstance = [[trackerClass alloc] init];
        trackerInstance = [trackerInstance performSelector:initSelector withObject:player];
        NRVA_DEBUG_LOG(@"Created content tracker using runtime instantiation for AVPlayer: %@", player);
        return trackerInstance;
    } else {
        NRVA_ERROR_LOG(@"NRTrackerAVPlayer does not respond to initWithAVPlayer: selector");
        return nil;
    }
}

/**
 * Creates an ad tracker for IMA (equivalent to Android's createAdTracker)
 * Uses runtime class loading to avoid circular dependencies
 */
+ (id)createAdTracker {
    // Use runtime class loading to avoid circular dependency
    Class trackerClass = NSClassFromString(@"NRTrackerIMA");
    if (!trackerClass) {
        NRVA_ERROR_LOG(@"NRTrackerIMA class not found - ensure NRIMATracker pod is installed");
        return nil;
    }
    
    id adTracker = [[trackerClass alloc] init];
    NRVA_DEBUG_LOG(@"Created ad tracker using runtime instantiation");
    return adTracker;
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
