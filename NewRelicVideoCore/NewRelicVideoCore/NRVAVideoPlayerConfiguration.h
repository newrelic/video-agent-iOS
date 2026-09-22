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
 * Discriminates which concrete NRVideoTracker subclass createContentTracker should instantiate.
 *
 * Setting this explicitly is the recommended path — it's the only way to identify a custom/wrapped
 * player object (e.g. `class CompanyPlayer { let theoplayer: THEOplayer }`), since no amount of class
 * inspection can distinguish "this object contains a THEOplayer" from "this object is a THEOplayer".
 * addPlayer: also identifies a real AVPlayer/THEOplayer instance by class automatically as a safety net
 * for a caller who forgot to set this — but that detection depends on runtime class-name matching
 * (NSClassFromString against THEOplayer's Swift-runtime name, since NewRelicVideoCore never links
 * THEOplayerSDK directly), which is inherently more fragile than an explicit, caller-declared value:
 * it can't see through a wrapper object, and it would need updating if THEOplayer's SDK ever changes its
 * module name.
 *
 * NRPlayerTypeUnspecified is 0 — the value this property reads back as if a caller never touches it —
 * so that case is distinguishable from an explicit choice using this enum alone, no separate tracking
 * needed. It's only ever consulted when class-based detection also fails (a real AVPlayer/THEOplayer
 * instance is always identified by class before this is ever read), in which case addPlayer: does not
 * start tracking rather than silently guessing AVPlayer.
 */
typedef NS_ENUM(NSInteger, NRPlayerType) {
    NRPlayerTypeUnspecified NS_SWIFT_NAME(unspecified),
    NRPlayerTypeAVPlayer NS_SWIFT_NAME(avPlayer),
    NRPlayerTypeTHEOplayer NS_SWIFT_NAME(theOplayer),
};

/**
 * Configuration for video player details and attributes
 * Supports AVPlayer and custom player implementations
 */
@interface NRVAVideoPlayerConfiguration : NSObject

@property (nonatomic, readonly) NSString *playerName;
@property (nonatomic, readonly, nullable) id player; // AVPlayer or custom player
@property (nonatomic, readonly) NSDictionary<NSString *, id> *customAttributes;
@property (nonatomic, readonly) BOOL isAdEnabled;
// Recommended: set this explicitly (see the NRPlayerType doc comment above for why). Left unset
// (NRPlayerTypeUnspecified), addPlayer: falls back to identifying player's class automatically — and if
// that also fails (e.g. player is a custom/wrapped object), tracking will not start at all rather than
// silently misidentifying it.
@property (nonatomic) NRPlayerType playerType;
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
