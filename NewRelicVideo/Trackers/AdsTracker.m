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
@property (nonatomic) NSTimeInterval adRequestedTimestamp;
@property (nonatomic) NSTimeInterval lastAdHeartbeatTimestamp;
@property (nonatomic) NSTimeInterval adStartedTimestamp;
@property (nonatomic) NSTimeInterval adPausedTimestamp;
@property (nonatomic) NSTimeInterval adBufferBeginTimestamp;
@property (nonatomic) NSTimeInterval adSeekBeginTimestamp;
@property (nonatomic) NSTimeInterval adBreakBeginTimestamp;
@property (nonatomic) NSTimeInterval lastAdQuartileTimestamp;

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
    [self updateAdsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateAdsAttributes];
    
    [self setAdsTimeKey:@"timeSinceRequested" timestamp:self.adRequestedTimestamp];
    [self setAdsTimeKey:@"timeSinceLastAdHeartbeat" timestamp:self.lastAdHeartbeatTimestamp];
    [self setAdsTimeKey:@"timeSinceAdStarted" timestamp:self.adStartedTimestamp];
    [self setAdsTimeKey:@"timeSinceAdPaused" timestamp:self.adPausedTimestamp filter:AD_RESUME];
    [self setAdsTimeKey:@"timeSinceAdBufferBegin" timestamp:self.adBufferBeginTimestamp filter:AD_BUFFER_END];
    [self setAdsTimeKey:@"timeSinceAdSeekBegin" timestamp:self.adSeekBeginTimestamp filter:AD_SEEK_END];
    [self setAdsTimeKey:@"timeSinceAdBreakBegin" timestamp:self.adBreakBeginTimestamp];
    [self setAdsTimeKey:@"timeSinceLastAdQuartile" timestamp:self.lastAdQuartileTimestamp filter:AD_QUARTILE];
}

- (void)sendRequest {
    self.adRequestedTimestamp = TIMESTAMP;
    self.numberOfAds ++;
    [super sendRequest];
}

- (void)sendStart {
    self.adStartedTimestamp = TIMESTAMP;
    [super sendStart];
}

- (void)sendEnd {
    if (self.contentsTracker) {
        [self.contentsTracker adHappened:TIMESTAMP];
    }
    
    [super sendEnd];
}

- (void)sendPause {
    self.adPausedTimestamp = TIMESTAMP;
    [super sendPause];
}

- (void)sendResume {
    [super sendResume];
}

- (void)sendSeekStart {
    self.adSeekBeginTimestamp = TIMESTAMP;
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    self.adBufferBeginTimestamp = TIMESTAMP;
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    self.lastAdHeartbeatTimestamp = TIMESTAMP;
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
    self.adBreakBeginTimestamp = TIMESTAMP;
    [self.automat.actions sendAdBreakStart];
}

- (void)sendAdBreakEnd {
    [self.automat.actions sendAdBreakEnd];
}

- (void)sendAdQuartile {
    self.lastAdQuartileTimestamp = TIMESTAMP;
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

@end
