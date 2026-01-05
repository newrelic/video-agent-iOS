//
//  NRMTTrackingResponse.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Represents an individual ad within a tracking avail
 */
@interface NRMTTrackingAd : NSObject

/**
 Ad ID from tracking API
 */
@property (nonatomic, strong) NSString *adId;

/**
 Ad title/creative name
 */
@property (nonatomic, strong) NSString *adTitle;

/**
 Start time in seconds (relative to avail start)
 */
@property (nonatomic, assign) NSTimeInterval startTimeInSeconds;

/**
 Duration in seconds
 */
@property (nonatomic, assign) NSTimeInterval durationInSeconds;

/**
 Initialize from JSON dictionary
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;

@end

/**
 Represents an avail (ad break) from the tracking API
 */
@interface NRMTTrackingAvail : NSObject

/**
 Avail ID from tracking API
 */
@property (nonatomic, strong) NSString *availId;

/**
 Duration of the entire avail in seconds
 */
@property (nonatomic, assign) NSTimeInterval durationInSeconds;

/**
 Start time of the avail in seconds (relative to content timeline)
 Note: This is calculated, not provided by API
 */
@property (nonatomic, assign) NSTimeInterval startTimeInSeconds;

/**
 Array of ads within this avail
 */
@property (nonatomic, strong) NSArray<NRMTTrackingAd *> *ads;

/**
 Initialize from JSON dictionary
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;

@end

/**
 Root response object from AWS MediaTailor Tracking API
 */
@interface NRMTTrackingResponse : NSObject

/**
 Array of avails (ad breaks) returned by tracking API
 */
@property (nonatomic, strong) NSArray<NRMTTrackingAvail *> *avails;

/**
 Initialize from JSON dictionary
 */
- (nullable instancetype)initWithDictionary:(NSDictionary *)dict;

/**
 Parse tracking response from JSON data
 */
+ (nullable instancetype)parseFromData:(NSData *)data error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
