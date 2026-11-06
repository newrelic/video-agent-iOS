//
//  NRTrackerIMA.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 02/03/21.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import "NRTrackerIMA.h"
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>

@interface NRTrackerIMA ()

@property (nonatomic, strong) IMAAdEvent *lastEvent;
/// Last ad seen. DAI events such as the ad period/break ones carry no ad, so the getters read this.
@property (nonatomic, strong) IMAAd *lastAd;
@property (nonatomic, strong) IMAAdsManager *adsManager;
@property (nonatomic) NSNumber *quartile;
@property (nonatomic) NSNumber *skipped;
/// YES for Dynamic Ad Insertion: ad breaks come from the stream's own events instead of the ad pod.
@property (nonatomic) BOOL isDAI;

@end

@implementation NRTrackerIMA

- (instancetype)init {
    if (self = [super init]) {
        self.quartile = nil;
        self.skipped = @(0);
    }
    return self;
}

#pragma mark - NRAdTrackerConfigurable

- (void)configureWithAdConfig:(NRAdConfig *)adConfig player:(id)player {
    self.isDAI = (adConfig.type == NRAdTrackerTypeIMADAI);
}

#pragma mark - Ad events

- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager {
    self.lastEvent = event;
    self.adsManager = manager;
    if (event.ad) {
        self.lastAd = event.ad;
    }

    // Break start/end are idempotent in the core, so a client that still calls
    // `sendAdBreakStart`/`sendAdBreakEnd` by hand does not produce duplicates.
    switch (event.type) {
        case kIMAAdEvent_STARTED:
            self.quartile = @(0);
            self.skipped = @(0);
            if (!self.isDAI) {
                [self sendAdBreakStart];
            }
            [self sendRequest];
            [self sendStart];
            break;
        case kIMAAdEvent_SKIPPED:
            self.skipped = @(1);
            [self endAd];
            break;
        case kIMAAdEvent_COMPLETE:
            [self endAd];
            break;
        case kIMAAdEvent_FIRST_QUARTILE:
            self.quartile = @(1);
            [self sendAdQuartile];
            break;
        case kIMAAdEvent_MIDPOINT:
            self.quartile = @(2);
            [self sendAdQuartile];
            break;
        case kIMAAdEvent_THIRD_QUARTILE:
            self.quartile = @(3);
            [self sendAdQuartile];
            break;
        case kIMAAdEvent_PAUSE:
            [self sendPause];
            break;
        case kIMAAdEvent_RESUME:
            [self sendResume];
            break;
        case kIMAAdEvent_TAPPED:
        case kIMAAdEvent_CLICKED:
            [self sendAdClick];
            break;
        case kIMAAdEvent_ALL_ADS_COMPLETED:
            if (!self.isDAI) {
                [self sendAdBreakEnd];
            }
            break;
        // DAI: AD_PERIOD_* fire every time the stream enters or leaves an ad (including
        // replays after a seek), AD_BREAK_* only the first time. Both are safe to map.
        case kIMAAdEvent_AD_BREAK_STARTED:
        case kIMAAdEvent_AD_PERIOD_STARTED:
            if (!self.state.isAdBreak) {
                // A new break must not report the previous break's ad.
                self.lastAd = nil;
            }
            [self sendAdBreakStart];
            break;
        case kIMAAdEvent_AD_BREAK_ENDED:
        case kIMAAdEvent_AD_PERIOD_ENDED:
            [self sendAdBreakEnd];
            break;
        // Known IMA events that are not part of the ad lifecycle we report today.
        case kIMAAdEvent_AD_BREAK_READY:
        case kIMAAdEvent_CUEPOINTS_CHANGED:
        case kIMAAdEvent_ICON_TAPPED:
        case kIMAAdEvent_LOADED:
        case kIMAAdEvent_LOG:
        case kIMAAdEvent_STREAM_LOADED:
        case kIMAAdEvent_STREAM_STARTED:
        default:
            break;
    }

    AV_LOG(@"AdEvent received = %@", event.typeString);
}

/// Ends the current ad, and for client-side ads also the break once its last ad is done.
- (void)endAd {
    [self sendEnd];
    self.quartile = nil;
    if (!self.isDAI && [self isLastAdInPod]) {
        [self sendAdBreakEnd];
    }
}

- (BOOL)isLastAdInPod {
    IMAAdPodInfo *pod = self.lastAd.adPodInfo;
    return pod.adPosition >= pod.totalAds;
}

- (void)adError:(NSString *)message code:(int)code {
    NSError *error = [[NSError alloc] initWithDomain:@"com.newrelic.video.IMA"
                                                code:code
                                            userInfo:@{ NSLocalizedDescriptionKey:message ?: @"Unknown IMA error" }];
    [self sendError:error];
}


/**
 * Forward ad events
 * Simple forwarding to existing adEvent method
 */
- (void)handleAdEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)adsManager {
    [self adEvent:event adsManager:adsManager];
}

/**
 * Forward ad errors  
 * Simple forwarding to existing adError method (no changes to core logic)
 */
- (void)handleAdError:(IMAAdError *)error {
    [self adError:error.message code:(int)error.code];
}

#pragma mark - Attribute getters

- (NSString *)getPlayerName {
    return @"IMA";
}

- (NSString *)getTrackerName {
    return @"IMATracker";
}

- (NSString *)getTrackerSrc {
    return @"IOS";
}

- (NSString *)getTrackerVersion {
    return @"5.1.0";
}

- (NSNumber *)getPlayhead {
    if (self.adsManager) {
        return @(self.adsManager.adPlaybackInfo.currentMediaTime * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getDuration {
    if (self.lastAd) {
        return @(self.lastAd.duration * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getIsAd {
    return @(YES);
}

- (NSNumber *)getRenditionWidth {
    if (self.lastAd) {
        return @(self.lastAd.VASTMediaWidth);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getRenditionHeight {
    if (self.lastAd) {
        return @(self.lastAd.VASTMediaHeight);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSString *)getTitle {
    if (self.lastAd) {
        return self.lastAd.adTitle ?: (NSString *)[NSNull null];
    }
    else {
        return (NSString *)[NSNull null];
    }
}

- (NSNumber *)getBitrate {
    if (self.lastAd) {
        // VASTMediaBitrate returns kbps, convert to bps for consistency with AVPlayer's averageVideoBitrate
        return @(self.lastAd.VASTMediaBitrate * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSString *)getAdPosition {
    if (self.lastAd) {
        switch (self.lastAd.adPodInfo.podIndex) {
            case 0:
                return @"pre";
                break;
            case -1:
                return @"post";
                break;
            default:
                return @"mid";
                break;
        }
    }
    else {
        return (NSString *)[NSNull null];
    }
}

- (NSString *)getAdCreativeId {
    if (self.lastAd) {
        return self.lastAd.creativeID ?: (NSString *)[NSNull null];
    }
    else {
        return (NSString *)[NSNull null];
    }
}

- (NSNumber *)getAdQuartile {
    return self.quartile ? self.quartile : (NSNumber *)[NSNull null];
}

- (NSNumber *)getAdSkipped {
    return self.skipped;
}

//TODO: - (NSString *)getAdPartner

@end
