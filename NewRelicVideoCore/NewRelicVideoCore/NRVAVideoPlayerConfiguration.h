//
//  NRVAVideoPlayerConfiguration.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Discriminates which concrete NRVideoTracker subclass createContentTracker should instantiate.
 * NRVAVideo.addPlayer: identifies AVPlayer/THEOplayer instances by class automatically — this only needs
 * to be set explicitly as a fallback for a custom/wrapped player class that can't be identified that way
 * (or a player type not yet known to that check). NRPlayerTypeAVPlayer is 0 so existing configs
 * (constructed before this enum existed) default to it without any change to their call sites.
 */
typedef NS_ENUM(NSInteger, NRPlayerType) {
    NRPlayerTypeAVPlayer NS_SWIFT_NAME(avPlayer),
    NRPlayerTypeTHEOplayer NS_SWIFT_NAME(theOplayer),
};

/**
 * Configuration for video player details and attributes
 * Supports AVPlayer and custom player implementations
 */
@interface NRVAVideoPlayerConfiguration : NSObject

@property (nonatomic, readonly) NSString *playerName;
@property (nonatomic, readonly) id player; // AVPlayer or custom player
@property (nonatomic, readonly) NSDictionary<NSString *, id> *customAttributes;
@property (nonatomic, readonly) BOOL isAdEnabled;
// Optional override — addPlayer: identifies a real AVPlayer/THEOplayer instance by class on its own; set
// this explicitly only if player is a custom/wrapped type that check can't identify.
@property (nonatomic) NRPlayerType playerType;

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
                  customAttributes:(NSDictionary<NSString *, id> *)customAttributes;

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
                  customAttributes:(NSDictionary<NSString *, id> *)customAttributes;

@end
