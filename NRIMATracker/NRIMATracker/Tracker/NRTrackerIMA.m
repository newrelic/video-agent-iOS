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

// Strong on purpose: IMA events are transient, and the getters below read the last event's ad
// for as long as the ad plays.
@property (nonatomic, strong) IMAAdEvent *lastEvent;
@property (nonatomic, strong) IMAAdsManager *adsManager;
@property (nonatomic, strong) IMAStreamManager *streamManager;
@property (nonatomic) NSNumber *quartile;
@property (nonatomic) NSNumber *skipped;
@property (nonatomic) BOOL isDAI;
// DAI only: latest ad playback time in seconds, from the stream manager delegate.
@property (nonatomic) NSNumber *daiAdTime;

@end

static NSString *const kNRIMAErrorDomain = @"com.newrelic.video.IMA";
static NSString *const kNRIMAStreamTypeAttribute = @"adStreamType";

@implementation NRTrackerIMA

- (instancetype)init {
    if (self = [super init]) {
        self.quartile = nil;
        self.skipped = @(0);
        self.isDAI = NO;
    }
    return self;
}

#pragma mark - NRAdTrackerConfigurable

- (void)configureWithAdConfig:(NRAdConfig *)adConfig player:(id)player {
    if (adConfig.type == NRAdTrackerTypeDAI) {
        self.isDAI = YES;
        [self setAttribute:kNRIMAStreamTypeAttribute value:@"DAI"];
    }
}

#pragma mark - Client-side ads (IMAAdsManager)

- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager {
    self.adsManager = manager;
    [self processAdEvent:event];
}

#pragma mark - Dynamic Ad Insertion (IMAStreamManager)

- (void)streamAdEvent:(IMAAdEvent *)event streamManager:(IMAStreamManager *)manager {
    self.streamManager = manager;
    [self processAdEvent:event];
}

- (void)handleStreamAdEvent:(IMAAdEvent *)event streamManager:(IMAStreamManager *)manager {
    [self streamAdEvent:event streamManager:manager];
}

- (void)handleStreamAdError:(IMAAdError *)error {
    NSString *message = error.message ?: @"Unknown IMA stream error";
    NSError *nsError = [[NSError alloc] initWithDomain:kNRIMAErrorDomain
                                                  code:(int)error.code
                                              userInfo:@{
        NSLocalizedDescriptionKey: message,
        @"imaErrorType": @(error.type),
        @"imaErrorCode": @(error.code)
    }];
    [self sendError:nsError];
}

- (void)handleStreamAdProgressToTime:(NSTimeInterval)time
                          adDuration:(NSTimeInterval)adDuration
                          adPosition:(NSInteger)adPosition
                            totalAds:(NSInteger)totalAds
                     adBreakDuration:(NSTimeInterval)adBreakDuration {
    self.daiAdTime = @(time);
}

#pragma mark - Shared event handling

- (void)processAdEvent:(IMAAdEvent *)event {
    // DAI break/period events carry no ad; keep the last ad's metadata for the getters.
    if (event.ad || !self.isDAI) {
        self.lastEvent = event;
    }

    switch (event.type) {
        case kIMAAdEvent_STARTED:
            self.quartile = @(0);
            self.skipped = @(0);
            self.daiAdTime = nil;
            [self sendRequest];
            [self sendStart];
            break;
        case kIMAAdEvent_SKIPPED:
            self.skipped = @(1);
            [self sendEnd];
            self.quartile = nil;
            break;
        case kIMAAdEvent_COMPLETE:
            [self sendEnd];
            self.quartile = nil;
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
        case kIMAAdEvent_TAPPED:
        case kIMAAdEvent_CLICKED:
            [self sendAdClick];
            break;
        case kIMAAdEvent_AD_BREAK_STARTED:
            // DAI only: there is no adsManagerDidRequestContentPause/Resume for stitched ads.
            // sendAdBreakStart/End are state guarded, so an app that also calls them is not double counted.
            if (self.isDAI) {
                [self sendAdBreakStart];
            }
            break;
        case kIMAAdEvent_AD_BREAK_ENDED:
            if (self.isDAI) {
                [self sendAdBreakEnd];
            }
            break;
        default:
            break;
    }

    AV_LOG(@"AdEvent received = %@", event.typeString);
}

- (void)adError:(NSString *)message code:(int)code {
    NSError *error = [[NSError alloc] initWithDomain:kNRIMAErrorDomain
                                                code:code
                                            userInfo:@{ NSLocalizedDescriptionKey:message }];
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
    if (self.isDAI) {
        // The content player's playhead is the stitched stream; report ad-relative time instead.
        return self.daiAdTime ? @(self.daiAdTime.doubleValue * 1000) : (NSNumber *)[NSNull null];
    }
    if (self.adsManager) {
        return @(self.adsManager.adPlaybackInfo.currentMediaTime * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getDuration {
    if (self.lastEvent) {
        return @(self.lastEvent.ad.duration * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getIsAd {
    return @(YES);
}

- (NSNumber *)getRenditionWidth {
    if (self.lastEvent) {
        return @(self.lastEvent.ad.VASTMediaWidth);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSNumber *)getRenditionHeight {
    if (self.lastEvent) {
        return @(self.lastEvent.ad.VASTMediaHeight);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSString *)getTitle {
    if (self.lastEvent) {
        return self.lastEvent.ad.adTitle;
    }
    else {
        return (NSString *)[NSNull null];
    }
}

- (NSNumber *)getBitrate {
    if (self.lastEvent) {
        // VASTMediaBitrate returns kbps, convert to bps for consistency with AVPlayer's averageVideoBitrate
        return @(self.lastEvent.ad.VASTMediaBitrate * 1000);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSString *)getAdPosition {
    if (self.lastEvent && self.isDAI) {
        // DAI podIndex is not 0/-1 based (VOD postroll is N+1, live midroll is a break ID),
        // so use the pod's scheduled offset: 0 preroll, -1 postroll.
        NSTimeInterval offset = self.lastEvent.ad.adPodInfo.timeOffset;
        return offset == 0 ? @"pre" : (offset < 0 ? @"post" : @"mid");
    }
    if (self.lastEvent) {
        switch (self.lastEvent.ad.adPodInfo.podIndex) {
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
    if (self.lastEvent) {
        return self.lastEvent.ad.creativeID;
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
