//
//  NRMTAdPod.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Represents a single ad creative (pod) within an ad break.

 MediaTailor ad breaks can contain multiple pods (individual ads).
 Each pod is typically separated by DISCONTINUITY markers or MAP URL changes.
 */
@interface NRMTAdPod : NSObject

/**
 Start time of the pod in seconds (relative to content timeline)
 */
@property (nonatomic, assign) NSTimeInterval startTime;

/**
 Duration of the pod in seconds
 */
@property (nonatomic, assign) NSTimeInterval duration;

/**
 End time of the pod in seconds (startTime + duration)
 */
@property (nonatomic, assign) NSTimeInterval endTime;

/**
 Ad creative title (from tracking API)
 */
@property (nonatomic, strong, nullable) NSString *title;

/**
 Ad creative ID (from tracking API)
 */
@property (nonatomic, strong, nullable) NSString *creativeId;

/**
 Start time from tracking API (may differ from manifest timing)
 */
@property (nonatomic, assign) NSTimeInterval trackingStartTime;

/**
 Duration from tracking API (may differ from manifest timing)
 */
@property (nonatomic, assign) NSTimeInterval trackingDuration;

/**
 HLS MAP URL for this pod (used for pod boundary detection)
 */
@property (nonatomic, strong, nullable) NSString *mapUrl;

/**
 Whether AD_START has been fired for this pod
 */
@property (nonatomic, assign) BOOL hasFiredStart;

/**
 Whether first quartile (25%) has been fired for this pod
 */
@property (nonatomic, assign) BOOL hasFiredQ1;

/**
 Whether second quartile (50%) has been fired for this pod
 */
@property (nonatomic, assign) BOOL hasFiredQ2;

/**
 Whether third quartile (75%) has been fired for this pod
 */
@property (nonatomic, assign) BOOL hasFiredQ3;

@end

NS_ASSUME_NONNULL_END
