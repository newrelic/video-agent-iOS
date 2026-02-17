//
//  NRTrackerMediaTailor.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

NS_ASSUME_NONNULL_BEGIN

/**
 AWS MediaTailor Ad Tracker

 Tracks Server-Side Ad Insertion (SSAI) ads from AWS MediaTailor HLS streams.

 Features:
 - Client-side ad detection from HLS CUE-OUT/CUE-IN markers
 - Pod-level tracking (multiple ads per break)
 - VOD and Live stream support
 - Tracking API metadata enrichment
 - Quartile tracking (25%, 50%, 75%)
 - Ad position detection (pre/mid/post for VOD)

 Usage:
 @code
 NSURL *url = [NSURL URLWithString:@"https://[hash].mediatailor..."];
 AVPlayer *player = [AVPlayer playerWithURL:url];

 NSDictionary *options = @{
     @"enableManifestParsing": @YES,
     @"liveManifestPollInterval": @6.0,
     @"liveTrackingPollInterval": @12.0,
     @"trackingAPITimeout": @8.0
 };

 NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc]
     initWithAVPlayer:player options:options];
 @endcode
 */
@interface NRTrackerMediaTailor : NRVideoTracker

/**
 Checks if tracker should be used for this player's current source.

 @param player The AVPlayer instance
 @return YES if URL contains ".mediatailor.", NO otherwise
 */
+ (BOOL)isUsing:(AVPlayer *)player;

/**
 Initializes tracker with AVPlayer and optional configuration.

 @param player The AVPlayer instance
 @param options Configuration dictionary (optional)
        Keys:
        - enableManifestParsing (NSNumber BOOL, default YES)
        - liveManifestPollInterval (NSNumber double, default 5.0)
        - liveTrackingPollInterval (NSNumber double, default 10.0)
        - trackingAPITimeout (NSNumber double, default 5.0)
 */
- (instancetype)initWithAVPlayer:(AVPlayer *)player
                         options:(nullable NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
