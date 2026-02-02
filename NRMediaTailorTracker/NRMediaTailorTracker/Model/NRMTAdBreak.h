//
//  NRMTAdBreak.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMediaTailorConstants.h"

@class NRMTAdPod;

NS_ASSUME_NONNULL_BEGIN

/**
 Represents an ad break (avail) in the video timeline.

 An ad break is a continuous period of ad content, which may contain one or more
 individual ad pods (creatives). Detected from HLS CUE-OUT/CUE-IN markers and
 enriched with metadata from the AWS MediaTailor Tracking API.
 */
@interface NRMTAdBreak : NSObject

/**
 Unique identifier for this ad break (e.g., "avail-120.5")
 */
@property (nonatomic, strong) NSString *breakId;

/**
 Start time of the ad break in seconds (relative to content timeline)
 */
@property (nonatomic, assign) NSTimeInterval startTime;

/**
 Duration of the ad break in seconds
 */
@property (nonatomic, assign) NSTimeInterval duration;

/**
 End time of the ad break in seconds (startTime + duration)
 */
@property (nonatomic, assign) NSTimeInterval endTime;

/**
 Ad break title (from tracking API, optional)
 */
@property (nonatomic, strong, nullable) NSString *title;

/**
 Ad creative ID (from tracking API, optional)
 */
@property (nonatomic, strong, nullable) NSString *creativeId;

/**
 Ad position relative to content (pre/mid/post for VOD, unknown for Live)
 */
@property (nonatomic, assign) NRMTAdPosition adPosition;

/**
 Source from which this ad break was detected
 */
@property (nonatomic, assign) NRMTAdSource source;

/**
 Whether this ad break has been confirmed/enriched by the tracking API
 */
@property (nonatomic, assign) BOOL confirmedByTracking;

/**
 Whether AD_BREAK_START has been fired for this break
 */
@property (nonatomic, assign) BOOL hasFiredStart;

/**
 Whether AD_BREAK_END has been fired for this break
 */
@property (nonatomic, assign) BOOL hasFiredEnd;

/**
 Whether AD_START has been fired (for breaks without pods)
 */
@property (nonatomic, assign) BOOL hasFiredAdStart;

/**
 Whether first quartile (25%) has been fired (for breaks without pods)
 */
@property (nonatomic, assign) BOOL hasFiredQ1;

/**
 Whether second quartile (50%) has been fired (for breaks without pods)
 */
@property (nonatomic, assign) BOOL hasFiredQ2;

/**
 Whether third quartile (75%) has been fired (for breaks without pods)
 */
@property (nonatomic, assign) BOOL hasFiredQ3;

/**
 Array of individual ad pods within this break
 Empty if break contains no detected pods (treat as single ad)
 */
@property (nonatomic, strong) NSMutableArray<NRMTAdPod *> *pods;

@end

NS_ASSUME_NONNULL_END
