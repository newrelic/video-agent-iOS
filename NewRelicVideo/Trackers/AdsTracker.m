//
//  AdsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 10/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AdsTracker.h"
#import "PlaybackAutomat.h"
#import "BackendActions.h"
#import "EventDefs.h"
#import "ContentsTracker.h"
#import "Tracker_internal.h"
#import "ContentsTracker_internal.h"
#import "TimestampValue.h"

#define ACTION_FILTER @"AD_"

/*
 TODO:
 - Implement AD_QUARTILE's "quartile" attribute. Easy, a simple counter is reset on every AD_REQUEST.
 - Implement AD_CLICK's "url" attribute. Argument to sendAdClick method.
 - Implement AD_END's "skipped" attribute. Argument to sendEnd method (?). Problematic, since we are adding an argument to contents tracker, that doesn't need it.
 */

@interface AdsTracker ()

@property (nonatomic, weak) ContentsTracker *contentsTracker;

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *adsAttributeGetters;
@property (nonatomic) int numberOfAds;

// Time Since
@property (nonatomic) TimestampValue *adRequestedTimestamp;
@property (nonatomic) TimestampValue *lastAdHeartbeatTimestamp;
@property (nonatomic) TimestampValue *adStartedTimestamp;
@property (nonatomic) TimestampValue *adPausedTimestamp;
@property (nonatomic) TimestampValue *adBufferBeginTimestamp;
@property (nonatomic) TimestampValue *adSeekBeginTimestamp;
@property (nonatomic) TimestampValue *adBreakBeginTimestamp;
@property (nonatomic) TimestampValue *lastAdQuartileTimestamp;

@end

@implementation AdsTracker

- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
    if (!_adsAttributeGetters) {
        _adsAttributeGetters = @{
                                 @"numberOfAds": [NSValue valueWithPointer:@selector(getNumberOfAds)],
                                 @"adId": [NSValue valueWithPointer:@selector(getVideoId)],
                                 @"adTitle": [NSValue valueWithPointer:@selector(getTitle)],
                                 @"adBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                                 @"adRenditionName": [NSValue valueWithPointer:@selector(getRenditionName)],
                                 @"adRenditionBitrate": [NSValue valueWithPointer:@selector(getRenditionBitrate)],
                                 @"adRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                                 @"adRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                                 @"adDuration": [NSValue valueWithPointer:@selector(getDuration)],
                                 @"adPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                                 @"adLanguage": [NSValue valueWithPointer:@selector(getLanguage)],
                                 @"adSrc": [NSValue valueWithPointer:@selector(getSrc)],
                                 @"adIsMuted": [NSValue valueWithPointer:@selector(getIsMuted)],
                                 @"adCdn": [NSValue valueWithPointer:@selector(getCdn)],
                                 @"adFps": [NSValue valueWithPointer:@selector(getFps)],
                                 @"adCreativeId": [NSValue valueWithPointer:@selector(getAdCreativeId)],
                                 @"adPosition": [NSValue valueWithPointer:@selector(getAdPosition)],
                                 @"adPartner": [NSValue valueWithPointer:@selector(getAdPartner)],
                                 }.mutableCopy;
    }
    return _adsAttributeGetters;
}

- (void)updateAdsAttributes {
    for (NSString *key in self.contentsAttributeGetters) {
        [self updateAdsAttribute:key];
    }
}

- (void)setAdsOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self setOptionKey:key value:value forAction:ACTION_FILTER];
}

- (void)updateAdsAttribute:(NSString *)attr {
    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.contentsAttributeGetters];
    if (val) [self setOptionKey:attr value:val forAction:ACTION_FILTER];
}

- (void)setAdsTimeKey:(NSString *)key timestamp:(NSTimeInterval)timestamp {
    [self setAdsTimeKey:key timestamp:timestamp filter:ACTION_FILTER];
}

- (void)setAdsTimeKey:(NSString *)key timestamp:(NSTimeInterval)timestamp filter:(NSString *)filter {
    if (timestamp > 0) {
        [self setOptionKey:key value:@(1000.0f * TIMESINCE(timestamp)) forAction:filter];
    }
    else {
        [self setOptionKey:key value:@0 forAction:filter];
    }
}

#pragma mark - Init

- (instancetype)initWithContentsTracker:(ContentsTracker *)tracker {
    if (self = [super init]) {
        self.contentsTracker = tracker;
    }
    return self;
}

- (void)reset {
    [super reset];
    
    self.numberOfAds = 0;
    
    self.adRequestedTimestamp = [TimestampValue build:0];
    self.lastAdHeartbeatTimestamp = [TimestampValue build:0];
    self.adStartedTimestamp = [TimestampValue build:0];
    self.adPausedTimestamp = [TimestampValue build:0];
    self.adBufferBeginTimestamp = [TimestampValue build:0];
    self.adSeekBeginTimestamp = [TimestampValue build:0];
    self.adBreakBeginTimestamp = [TimestampValue build:0];
    self.lastAdQuartileTimestamp = [TimestampValue build:0];
    
    [self updateAdsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateAdsAttributes];
    
    [self setAdsTimeKey:@"timeSinceRequested" timestamp:self.adRequestedTimestamp.timestamp];
    [self setAdsTimeKey:@"timeSinceLastAdHeartbeat" timestamp:self.lastAdHeartbeatTimestamp.timestamp];
    [self setAdsTimeKey:@"timeSinceAdStarted" timestamp:self.adStartedTimestamp.timestamp];
    [self setAdsTimeKey:@"timeSinceAdPaused" timestamp:self.adPausedTimestamp.timestamp filter:AD_RESUME];
    [self setAdsTimeKey:@"timeSinceAdBufferBegin" timestamp:self.adBufferBeginTimestamp.timestamp filter:AD_BUFFER_END];
    [self setAdsTimeKey:@"timeSinceAdSeekBegin" timestamp:self.adSeekBeginTimestamp.timestamp filter:AD_SEEK_END];
    [self setAdsTimeKey:@"timeSinceAdBreakBegin" timestamp:self.adBreakBeginTimestamp.timestamp];
    [self setAdsTimeKey:@"timeSinceLastAdQuartile" timestamp:self.lastAdQuartileTimestamp.timestamp filter:AD_QUARTILE];
}

- (void)sendRequest {
    [self.adRequestedTimestamp setMain:TIMESTAMP];
    self.numberOfAds ++;
    [super sendRequest];
}

- (void)sendStart {
    [self.adStartedTimestamp setMain:TIMESTAMP];
    [super sendStart];
}

- (void)sendEnd {
    if (self.contentsTracker) {
        [self.contentsTracker adHappened:TIMESTAMP];
    }
    
    [super sendEnd];
}

- (void)sendPause {
    [self.adPausedTimestamp setMain:TIMESTAMP];
    [super sendPause];
}

- (void)sendResume {
    [super sendResume];
}

- (void)sendSeekStart {
    [self.adSeekBeginTimestamp setMain:TIMESTAMP];
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    [self.adBufferBeginTimestamp setMain:TIMESTAMP];
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    [self.lastAdHeartbeatTimestamp setMain:TIMESTAMP];
    [super sendHeartbeat];
}

- (void)sendRenditionChange {
    [super sendRenditionChange];
}

- (void)sendError:(NSString *)message {
    [super sendError:message];
}

// Ads specific senders

- (void)sendAdBreakStart {
    self.numberOfAds = 0;
    [self.adBreakBeginTimestamp setMain:TIMESTAMP];
    [self.automat.actions sendAdBreakStart];
}

- (void)sendAdBreakEnd {
    [self.automat.actions sendAdBreakEnd];
}

- (void)sendAdQuartile {
    [self.lastAdQuartileTimestamp setMain:TIMESTAMP];
    [self.automat.actions sendAdQuartile];
}

- (void)sendAdClick {
    [self.automat.actions sendAdClick];
}

#pragma mark - Getters

- (NSNumber *)getNumberOfAds {
    return @(self.numberOfAds);
}

- (NSNumber *)getIsAd {
    return @YES;
}

// TODO: call contents tracker getters, at least for player name and version, it should be the same

- (NSString *)getPlayerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getPlayerVersion {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerVersion {
    OVERWRITE_STUB
    return nil;
}

#pragma mark - Time

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    if (![super setTimestamp:timestamp attributeName:attr]) {
        if ([attr isEqualToString:@"timeSinceRequested"]) {
            [self.adRequestedTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceLastAdHeartbeat"]) {
            [self.lastAdHeartbeatTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceAdStarted"]) {
            [self.adStartedTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceAdPaused"]) {
            [self.adPausedTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceAdBufferBegin"]) {
            [self.adBufferBeginTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceAdSeekBegin"]) {
            [self.adSeekBeginTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceAdBreakBegin"]) {
            [self.adBreakBeginTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceLastAdQuartile"]) {
            [self.lastAdQuartileTimestamp setExternal:timestamp];
        }
        else {
            return NO;
        }
    }
    
    return YES;
}

@end
