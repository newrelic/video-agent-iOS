//
//  NRMTUtilities.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTUtilities.h"
#import "NRMTAdBreak.h"
#import "NRMTAdPod.h"

@implementation NRMTUtilities

// MARK: - Detection

+ (NRMTManifestType)detectManifestTypeFromURL:(NSURL *)url {
    NSString *urlString = url.absoluteString.lowercaseString;
    if ([urlString containsString:@".m3u8"]) {
        return NRMTManifestTypeHLS;
    }
    return NRMTManifestTypeHLS; // Default
}

+ (NRMTStreamType)detectStreamTypeFromDuration:(NSTimeInterval)duration {
    if (isinf(duration) || duration == 0) {
        return NRMTStreamTypeLive;
    }
    return NRMTStreamTypeVOD;
}

+ (BOOL)isMediaTailorURL:(NSURL *)url {
    return [url.absoluteString containsString:NRMT_DOMAIN_PATTERN];
}

// MARK: - URL Extraction

+ (nullable NSURL *)extractTrackingURLFromManifestURL:(NSURL *)manifestURL {
    if (!manifestURL) {
        return nil;
    }

    NSString *urlString = manifestURL.absoluteString;

    // Extract sessionId from query parameters
    NSURLComponents *components = [NSURLComponents componentsWithURL:manifestURL resolvingAgainstBaseURL:NO];
    NSString *sessionId = nil;

    for (NSURLQueryItem *item in components.queryItems) {
        if ([item.name isEqualToString:@"aws.sessionId"] || [item.name isEqualToString:@"sessionId"]) {
            sessionId = item.value;
            break;
        }
    }

    if (!sessionId) {
        return nil;
    }

    // Build tracking URL: /v1/tracking/[sessionId]
    // Replace /v1/master/ or /v1/session/ with /v1/tracking/
    // Remove /master.m3u8 or /manifest.mpd and query params

    NSString *baseURL = urlString;

    // Remove query parameters
    NSRange queryRange = [baseURL rangeOfString:@"?"];
    if (queryRange.location != NSNotFound) {
        baseURL = [baseURL substringToIndex:queryRange.location];
    }

    // Replace path segments
    baseURL = [baseURL stringByReplacingOccurrencesOfString:@"/v1/master/" withString:@"/v1/tracking/"];
    baseURL = [baseURL stringByReplacingOccurrencesOfString:@"/v1/session/" withString:@"/v1/tracking/"];

    // Remove /master.m3u8 or similar endings
    NSArray *endingsToRemove = @[@"/master.m3u8", @"/manifest.mpd", @".m3u8", @".mpd"];
    for (NSString *ending in endingsToRemove) {
        if ([baseURL hasSuffix:ending]) {
            NSRange range = [baseURL rangeOfString:ending options:NSBackwardsSearch];
            baseURL = [baseURL substringToIndex:range.location];
            break;
        }
    }

    // Append sessionId
    NSString *trackingURLString = [NSString stringWithFormat:@"%@/%@", baseURL, sessionId];

    return [NSURL URLWithString:trackingURLString];
}

// MARK: - Ad Position

+ (NRMTAdPosition)determineAdPosition:(NSInteger)adBreakIndex
                        totalAdBreaks:(NSInteger)totalAdBreaks
                           streamType:(NRMTStreamType)streamType {
    if (streamType == NRMTStreamTypeLive) {
        return NRMTAdPositionUnknown;
    }

    if (totalAdBreaks == 0) {
        return NRMTAdPositionUnknown;
    }

    if (adBreakIndex == 0) {
        return NRMTAdPositionPreRoll;
    } else if (adBreakIndex == totalAdBreaks - 1) {
        return NRMTAdPositionPostRoll;
    } else {
        return NRMTAdPositionMidRoll;
    }
}

// MARK: - Quartiles

+ (NSDictionary<NSString *, NSNumber *> *)calculateQuartilesForDuration:(NSTimeInterval)duration {
    return @{
        @"q1": @(duration * NRMT_QUARTILE_Q1),
        @"q2": @(duration * NRMT_QUARTILE_Q2),
        @"q3": @(duration * NRMT_QUARTILE_Q3)
    };
}

+ (NSArray<NSNumber *> *)getQuartilesToFireForProgress:(NSTimeInterval)progress
                                               duration:(NSTimeInterval)duration
                                            firedFlags:(NSDictionary<NSString *, NSNumber *> *)firedFlags {
    if (duration <= 0) {
        return @[];
    }

    NSMutableArray<NSNumber *> *toFire = [NSMutableArray array];
    NSDictionary *quartiles = [self calculateQuartilesForDuration:duration];

    BOOL q1Fired = [firedFlags[@"q1"] boolValue];
    BOOL q2Fired = [firedFlags[@"q2"] boolValue];
    BOOL q3Fired = [firedFlags[@"q3"] boolValue];

    if (progress >= [quartiles[@"q1"] doubleValue] && !q1Fired) {
        [toFire addObject:@1];
    }
    if (progress >= [quartiles[@"q2"] doubleValue] && !q2Fired) {
        [toFire addObject:@2];
    }
    if (progress >= [quartiles[@"q3"] doubleValue] && !q3Fired) {
        [toFire addObject:@3];
    }

    return [toFire copy];
}

// MARK: - Schedule Management

+ (nullable NRMTAdBreak *)findActiveAdBreak:(NSArray<NRMTAdBreak *> *)adSchedule
                                currentTime:(NSTimeInterval)currentTime {
    for (NRMTAdBreak *adBreak in adSchedule) {
        if (currentTime >= adBreak.startTime && currentTime < adBreak.endTime) {
            return adBreak;
        }
    }
    return nil;
}

+ (nullable NRMTAdPod *)findActivePod:(NRMTAdBreak *)adBreak
                          currentTime:(NSTimeInterval)currentTime {
    if (!adBreak || !adBreak.pods || adBreak.pods.count == 0) {
        return nil;
    }

    for (NRMTAdPod *pod in adBreak.pods) {
        if (currentTime >= pod.startTime && currentTime < pod.endTime) {
            return pod;
        }
    }
    return nil;
}

+ (BOOL)isValidAdBreak:(NRMTAdBreak *)adBreak {
    return adBreak.duration >= NRMT_MIN_AD_DURATION;
}

+ (NSInteger)findAdBreakIndex:(NSArray<NRMTAdBreak *> *)adSchedule
                    startTime:(NSTimeInterval)startTime {
    for (NSInteger i = 0; i < adSchedule.count; i++) {
        NRMTAdBreak *adBreak = adSchedule[i];
        if (fabs(adBreak.startTime - startTime) < NRMT_AD_TIMING_TOLERANCE) {
            return i;
        }
    }
    return NSNotFound;
}

// MARK: - Logging

+ (NSString *)getTimestamp {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    return [formatter stringFromDate:[NSDate date]];
}

+ (NSString *)logPrefix {
    return [NSString stringWithFormat:@"%@ %@", NRMT_LOG_PREFIX, [self getTimestamp]];
}

@end
