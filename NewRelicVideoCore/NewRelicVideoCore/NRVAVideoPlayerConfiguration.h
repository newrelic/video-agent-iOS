//
//  NRVAVideoPlayerConfiguration.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Which ad tracker to create for a player session.
typedef NS_ENUM(NSInteger, NRAdTrackerType) {
    NRAdTrackerTypeCSAI = 0,        ///< Client-side ads (Google IMA / any CSAI framework).
    NRAdTrackerTypeMediaTailor = 1, ///< AWS MediaTailor server-side ad insertion.
};

/**
 * Unified ad configuration — the single place to select and configure the ad
 * tracker for a player session. Mirrors Android `NRAdConfig`. Pass one of the
 * factory results as `adConfig` on `NRVAVideoPlayerConfiguration`; pass nil to
 * disable ad tracking.
 */
@interface NRAdConfig : NSObject

@property (nonatomic, readonly) NRAdTrackerType type;
/// MediaTailor only: custom-CDN ad-segment marker (see `NRTrackerMediaTailor.adSegmentPrefix`). Nil = default AWS paths.
@property (nonatomic, readonly, copy, nullable) NSString *adSegmentPrefix;
/// MediaTailor only: explicit tracking-URL override (see `NRTrackerMediaTailor.trackingUrl`). Nil = derive from manifest.
@property (nonatomic, readonly, copy, nullable) NSString *trackingUrl;

/// Client-side ads (Google IMA). Equivalent to the legacy `adEnabled:YES`.
+ (instancetype)csai;
/// AWS MediaTailor with default AWS ad-segment detection.
+ (instancetype)mediaTailor;
/// MediaTailor on a custom CDN whose ad segments don't use the default AWS paths.
+ (instancetype)mediaTailorWithSegmentPrefix:(nullable NSString *)adSegmentPrefix;
/// MediaTailor with a custom CDN prefix and an explicit tracking URL.
+ (instancetype)mediaTailorWithSegmentPrefix:(nullable NSString *)adSegmentPrefix
                                 trackingUrl:(nullable NSString *)trackingUrl;

@end

/**
 * Adopted by ad tracker classes — usually shipped in their own pod, e.g.
 * `NRTrackerMediaTailor` in `NRMediaTailorTracker` — that need tracker-specific
 * configuration pushed to them once `+[NRVAVideo addPlayer:]` creates them.
 *
 * Declaring this protocol here (in the core, dependency-free framework) lets
 * `NRVAVideo` configure any conforming tracker generically: no per-tracker-type
 * branch, and no risk of a KVC key string silently drifting from a setter
 * selector name, since there is exactly one strongly-typed call.
 */
@protocol NRAdTrackerConfigurable <NSObject>

/// @param adConfig The ad configuration selected for this player session.
/// @param player The player instance from `NRVAVideoPlayerConfiguration`, or nil.
- (void)configureWithAdConfig:(NRAdConfig *)adConfig player:(nullable id)player;

@end

/**
 * Configuration for video player details and attributes
 * Supports AVPlayer and custom player implementations
 */
@interface NRVAVideoPlayerConfiguration : NSObject

@property (nonatomic, readonly) NSString *playerName;
@property (nonatomic, readonly, nullable) id player; // AVPlayer or custom player
@property (nonatomic, readonly) NSDictionary<NSString *, id> *customAttributes;
@property (nonatomic, readonly) BOOL isAdEnabled;
/// The selected ad configuration, or nil when ad tracking is disabled. When the
/// legacy `adEnabled:YES` initializer is used, this is `[NRAdConfig csai]`.
@property (nonatomic, readonly, nullable) NRAdConfig *adConfig;

/**
 * Initialize with player details
 *
 * @param playerName Name identifier for the player
 * @param player The player instance (AVPlayer or custom)
 * @param isAdEnabled Whether ad tracking is enabled
 * @param customAttributes Additional custom attributes for tracking
 */
- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                         adEnabled:(BOOL)isAdEnabled
                  customAttributes:(nullable NSDictionary<NSString *, id> *)customAttributes;

/**
 * Initialize with an explicit ad configuration. Use `NRAdConfig` factories to
 * select IMA (`+csai`) or MediaTailor (`+mediaTailor…`). Pass nil `adConfig`
 * to disable ad tracking.
 */
- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(nullable id)player
                          adConfig:(nullable NRAdConfig *)adConfig
                  customAttributes:(nullable NSDictionary<NSString *, id> *)customAttributes;

/**
 * Convenience initializer without custom attributes
 */
- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player
                         adEnabled:(BOOL)isAdEnabled;

/**
 * Convenience initializer for basic setup
 */
- (instancetype)initWithPlayerName:(NSString *)playerName
                            player:(id)player;

/**
 * Convenience initializer for configuration without player (for convenience methods)
 */
- (instancetype)initWithPlayerName:(NSString *)playerName
                         adEnabled:(BOOL)isAdEnabled
                  customAttributes:(nullable NSDictionary<NSString *, id> *)customAttributes;

@end

NS_ASSUME_NONNULL_END
