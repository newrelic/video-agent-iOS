//
//  NRVAVideoPlayerConfiguration.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * Configuration for video player details and attributes
 * Supports AVPlayer and custom player implementations
 */
@interface NRVAVideoPlayerConfiguration : NSObject

@property (nonatomic, readonly) NSString *playerName;
@property (nonatomic, readonly) id player; // AVPlayer or custom player
@property (nonatomic, readonly) NSDictionary<NSString *, id> *customAttributes;
@property (nonatomic, readonly) BOOL isAdEnabled;

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
