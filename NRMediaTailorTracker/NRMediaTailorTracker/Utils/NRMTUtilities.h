//
//  NRMTUtilities.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRMediaTailorConstants.h"

@class NRMTAdBreak;
@class NRMTAdPod;

NS_ASSUME_NONNULL_BEGIN

/**
 Utility functions for MediaTailor ad tracking
 */
@interface NRMTUtilities : NSObject

// MARK: - Detection

/**
 Detects manifest type from URL

 @param url The manifest URL
 @return Manifest type (HLS)
 */
+ (NRMTManifestType)detectManifestTypeFromURL:(NSURL *)url;

/**
 Detects stream type from player duration

 @param duration Duration in seconds (INFINITY for live, finite for VOD)
 @return Stream type (VOD or Live)
 */
+ (NRMTStreamType)detectStreamTypeFromDuration:(NSTimeInterval)duration;

/**
 Checks if URL contains MediaTailor domain pattern

 @param url URL to check
 @return YES if URL contains ".mediatailor."
 */
+ (BOOL)isMediaTailorURL:(NSURL *)url;

// MARK: - URL Extraction

/**
 Extracts tracking URL from sessionized manifest URL

 Converts:
 https://[hash].mediatailor.[region].amazonaws.com/v1/master/[id]/[name]/master.m3u8?aws.sessionId=[session]
 To:
 https://[hash].mediatailor.[region].amazonaws.com/v1/tracking/[session]

 @param manifestURL The manifest URL
 @return Tracking URL, or nil if sessionId not found
 */
+ (nullable NSURL *)extractTrackingURLFromManifestURL:(NSURL *)manifestURL;

// MARK: - Ad Position

/**
 Determines ad position based on schedule index

 @param adBreakIndex Index of ad break in schedule
 @param totalAdBreaks Total number of ad breaks
 @param streamType Stream type (VOD or Live)
 @return Ad position (pre/mid/post for VOD, unknown for Live)
 */
+ (NRMTAdPosition)determineAdPosition:(NSInteger)adBreakIndex
                        totalAdBreaks:(NSInteger)totalAdBreaks
                           streamType:(NRMTStreamType)streamType;

// MARK: - Quartiles

/**
 Calculates quartile thresholds for a duration

 @param duration Duration in seconds
 @return Dictionary with keys @"q1", @"q2", @"q3" (NSNumber values)
 */
+ (NSDictionary<NSString *, NSNumber *> *)calculateQuartilesForDuration:(NSTimeInterval)duration;

/**
 Determines which quartiles should be fired based on progress

 @param progress Current progress in seconds
 @param duration Total duration in seconds
 @param firedFlags Dictionary with keys @"q1", @"q2", @"q3" (NSNumber BOOL values)
 @return Array of quartile numbers to fire (1, 2, or 3)
 */
+ (NSArray<NSNumber *> *)getQuartilesToFireForProgress:(NSTimeInterval)progress
                                               duration:(NSTimeInterval)duration
                                            firedFlags:(NSDictionary<NSString *, NSNumber *> *)firedFlags;

// MARK: - Schedule Management

/**
 Finds active ad break at current playhead time

 @param adSchedule Array of ad breaks
 @param currentTime Current playhead time in seconds
 @return Active ad break, or nil if not in ad
 */
+ (nullable NRMTAdBreak *)findActiveAdBreak:(NSArray<NRMTAdBreak *> *)adSchedule
                                currentTime:(NSTimeInterval)currentTime;

/**
 Finds active pod within ad break at current playhead time

 @param adBreak The ad break to search
 @param currentTime Current playhead time in seconds
 @return Active pod, or nil if no pod active
 */
+ (nullable NRMTAdPod *)findActivePod:(NRMTAdBreak *)adBreak
                          currentTime:(NSTimeInterval)currentTime;

/**
 Validates if ad break duration meets minimum threshold

 @param adBreak Ad break to validate
 @return YES if duration >= NRMT_MIN_AD_DURATION
 */
+ (BOOL)isValidAdBreak:(NRMTAdBreak *)adBreak;

/**
 Finds ad break index in schedule by start time

 @param adSchedule Array of ad breaks
 @param startTime Start time to search for
 @return Index of ad break, or NSNotFound if not found
 */
+ (NSInteger)findAdBreakIndex:(NSArray<NRMTAdBreak *> *)adSchedule
                    startTime:(NSTimeInterval)startTime;

// MARK: - Logging

/**
 Generates timestamp string for logging (HH:MM:SS.mmm format)

 @return Formatted timestamp string
 */
+ (NSString *)getTimestamp;

/**
 Creates log prefix with timestamp

 @return Log prefix string "[MediaTailor - HH:MM:SS.mmm]"
 */
+ (NSString *)logPrefix;

@end

NS_ASSUME_NONNULL_END
