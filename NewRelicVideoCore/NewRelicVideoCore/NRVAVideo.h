//
//  NRVAVideo.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAVideoConfiguration;
@class NRVAVideoPlayerConfiguration;
@class NRVAHarvestManager;
@class NRVAVideoBuilder;
@class IMAAdEvent;
@class IMAAdError;
@class IMAAdsManager;

/**
 * New Relic Video Agent - iOS & tvOS Optimized
 * Singleton pattern with Builder for robust initialization
 * Supports AVPlayer and custom players with automatic device detection
 */
@interface NRVAVideo : NSObject

/**
 * Get the singleton instance
 * @return NRVAVideo instance, or nil if not initialized yet
 */
+ (instancetype)getInstance;

/**
 * Check if NRVAVideo is initialized and ready for use
 */
+ (BOOL)isInitialized;

/**
 * Add a player with configuration
 * @param config Player configuration
 * @return Tracker ID for the player
 */
+ (NSInteger)addPlayer:(NRVAVideoPlayerConfiguration *)config;

/**
 * ONE-LINE CONVENIENCE METHODS - Simplified onboarding for developers
 */

/**
 * Add a simple video player with minimal setup (no ads)
 * @param videoURL The video URL to play
 * @param playerName Unique name for the player
 * @return Tracker ID for the player
 */
+ (NSInteger)addPlayerWithURL:(NSString *)videoURL name:(NSString *)playerName;

/**
 * Add a video player with ads support - ONE LINE SETUP
 * @param videoURL The video URL to play
 * @param playerName Unique name for the player
 * @param adTagURL The IMA ad tag URL (can be nil for no ads)
 * @return Tracker ID for the player
 */
+ (NSInteger)addPlayerWithURL:(NSString *)videoURL name:(NSString *)playerName adTagURL:(NSString *)adTagURL;

/**
 * Add a video player with ads and custom attributes - FULL FEATURED ONE LINE
 * @param videoURL The video URL to play
 * @param playerName Unique name for the player
 * @param adTagURL The IMA ad tag URL (can be nil for no ads)
 * @param attributes Custom attributes dictionary
 * @return Tracker ID for the player
 */
+ (NSInteger)addPlayerWithURL:(NSString *)videoURL name:(NSString *)playerName adTagURL:(NSString *)adTagURL attributes:(NSDictionary *)attributes;

/**
 * Release a tracker by ID
 * @param trackerId The tracker ID to release
 */
+ (void)releaseTracker:(NSInteger)trackerId;

/**
 * Release a tracker by player name
 * @param playerName The player name to release
 */
+ (void)releaseTrackerWithPlayerName:(NSString *)playerName;

/**
 * ANDROID PARITY: Static convenience methods for tracker access
 */

/**
 * Get content tracker by tracker ID (matches Android getContentTracker)
 * @param trackerId The tracker ID
 * @return Content tracker instance or nil if not found
 */
+ (id)contentTracker:(NSNumber *)trackerId;

/**
 * Get ad tracker by tracker ID (matches Android getAdTracker)  
 * @param trackerId The tracker ID
 * @return Ad tracker instance or nil if not found
 */
+ (id)adTracker:(NSNumber *)trackerId;

/**
 * SIMPLIFIED AD EVENT API - No need to get tracker manually!
 */

/**
 * Handle ad event with tracker ID - MUCH SIMPLER!
 * @param trackerId The tracker ID
 * @param event The IMA ad event
 * @param adsManager The IMA ads manager (optional)
 */
+ (void)handleAdEvent:(NSNumber *)trackerId event:(IMAAdEvent *)event adsManager:(IMAAdsManager *)adsManager;

/**
 * Handle ad error with tracker ID - MUCH SIMPLER!
 * @param trackerId The tracker ID  
 * @param error The IMA ad error
 * @param adsManager The IMA ads manager (optional)
 */
+ (void)handleAdError:(NSNumber *)trackerId error:(IMAAdError *)error adsManager:(IMAAdsManager *)adsManager;

/**
 * Handle ad error with tracker ID - OVERLOAD without adsManager
 * @param trackerId The tracker ID
 * @param error The IMA ad error
 */
+ (void)handleAdError:(NSNumber *)trackerId error:(IMAAdError *)error;

/**
 * Send ad break start event - MUCH SIMPLER!
 * @param trackerId The tracker ID
 */
+ (void)sendAdBreakStart:(NSNumber *)trackerId;

/**
 * Send ad break end event - MUCH SIMPLER!
 * @param trackerId The tracker ID
 */
+ (void)sendAdBreakEnd:(NSNumber *)trackerId;

/**
 * ANDROID PARITY: Enhanced logging control
 */

/**
 * Enable/disable logging (matches Android pattern)
 * @param enabled Whether logging should be enabled
 */
+ (void)setLogging:(BOOL)enabled;

/**
 * Create a new builder for setting up NRVAVideo
 * @return Builder instance
 */
+ (NRVAVideoBuilder *)newBuilder;

/**
 * Static convenience method for recording events without needing getInstance
 * @param eventType The event type
 * @param attributes A dictionary of attributes for the event
 */
+ (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Static convenience method for recording events for a specific tracker
 * @param eventType The event type
 * @param trackerId The tracker ID
 * @param attributes A dictionary of attributes for the event
 */
+ (void)recordEvent:(NSString *)eventType trackerId:(NSNumber *)trackerId attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Static convenience method for recording custom video events
 * @param attributes A dictionary of attributes for the event
 */
+ (void)recordCustomEvent:(NSDictionary<NSString *, id> *)attributes;

/**
 * Sets the user ID
 * @param userId The user ID
 */
+ (void)setUserId:(NSString *)userId;

/**
 * Sets an attribute for a specific tracker
 * @param trackerId The tracker ID
 * @param key The attribute key
 * @param value The attribute value
 * @param action The action name to associate with the attribute
 */
+ (void)setAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value action:(NSString *)action;

/**
 * Sets an attribute for a specific tracker
 * @param trackerId The tracker ID
 * @param key The attribute key
 * @param value The attribute value
 */
+ (void)setAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value;

/**
 * Sets an ad attribute for a specific tracker
 * @param trackerId The tracker ID
 * @param key The attribute key
 * @param value The attribute value
 * @param action The action name to associate with the attribute
 */
+ (void)setAdAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value action:(NSString *)action;

/**
 * Sets an ad attribute for a specific tracker
 * @param trackerId The tracker ID
 * @param key The attribute key
 * @param value The attribute value
 */
+ (void)setAdAttribute:(NSInteger)trackerId key:(NSString *)key value:(id)value;

/**
 * Sets a global attribute
 * @param key The attribute key
 * @param value The attribute value
 * @param action The action name to associate with the attribute
 */
+ (void)setGlobalAttribute:(NSString *)key value:(id)value action:(NSString *)action;

/**
 * Sets a global attribute
 * @param key The attribute key
 * @param value The attribute value
 */
+ (void)setGlobalAttribute:(NSString *)key value:(id)value;

/**
 * Creates a content tracker for AVPlayer (internal method)
 * @param player The AVPlayer instance
 * @return The content tracker instance
 */
+ (id)createContentTracker:(id)player;

/**
 * Creates an ad tracker for IMA (internal method)
 * @return The ad tracker instance
 */
+ (id)createAdTracker;

@end

/**
 * Builder pattern for robust NRVAVideo initialization
 */
@interface NRVAVideoBuilder : NSObject

/**
 * Set the video configuration
 * @param config The video configuration
 * @return Builder instance for chaining
 */
- (instancetype)withConfiguration:(NRVAVideoConfiguration *)config;

/**
 * Build and initialize NRVAVideo singleton
 * @return The NRVAVideo instance
 * @throws NSException if required parameters are missing or already initialized
 */
- (NRVAVideo *)build;

@end
