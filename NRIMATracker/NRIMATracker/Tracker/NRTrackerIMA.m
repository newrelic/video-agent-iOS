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

@property (nonatomic, weak) IMAAdEvent *lastEvent;
@property (nonatomic, weak) IMAAdsManager *adsManager;
@property (nonatomic) NSNumber *quartile;

@end

@implementation NRTrackerIMA

- (instancetype)init {
    if (self = [super init]) {
        self.quartile = nil;
    }
    return self;
}

- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager {
    self.lastEvent = event;
    self.adsManager = manager;
    
    if ([event.typeString isEqual:@"Started"]) {
        self.quartile = @(0);
        [self sendRequest];
        [self sendStart];
    }
    else if ([event.typeString isEqual:@"Complete"]) {
        [self sendEnd];
        self.quartile = nil;
    }
    else if ([event.typeString isEqual:@"First Quartile"]) {
        self.quartile = @(1);
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Midpoint"]) {
        self.quartile = @(2);
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Third Quartile"]) {
        self.quartile = @(3);
        [self sendAdQuartile];
    }
    else if ([event.typeString isEqual:@"Tapped"] || [event.typeString isEqual:@"Clicked"]) {
        [self sendAdClick];
    }
    
    AV_LOG(@"AdEvent received = %@", event.typeString);
}

- (void)adError:(NSString *)message code:(int)code {
    NSError *error = [[NSError alloc] initWithDomain:@"com.newrelic.video.IMA"
                                                code:code
                                            userInfo:@{ NSLocalizedDescriptionKey:message }];
    [self sendError:error];
}

#pragma mark - Attribute getters

- (NSString *)getPlayerName {
    return @"IMA";
}

- (NSString *)getTrackerName {
    return @"IMATracker";
}

- (NSString *)getTrackerVersion {
    return @"2.0.2";
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
        return @(self.lastEvent.ad.VASTMediaBitrate);
    }
    else {
        return (NSNumber *)[NSNull null];
    }
}

- (NSString *)getAdPosition {
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

//TODO: - (NSString *)getAdPartner

@end
