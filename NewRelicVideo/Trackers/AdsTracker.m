//
//  AdsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 10/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AdsTracker.h"
#import "TrackerAutomat.h"
#import "BackendActions.h"

#define ACTION_FILTER @"AD_"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@interface AdsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *adsAttributeGetters;
@property (nonatomic) int numberOfAds;

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

#pragma mark - Init

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
}

- (void)sendRequest {
    self.numberOfAds ++;
    [super sendRequest];
}

- (void)sendStart {
    [super sendStart];
}

- (void)sendEnd {
    [super sendEnd];
}

- (void)sendPause {
    [super sendPause];
}

- (void)sendResume {
    [super sendResume];
}

- (void)sendSeekStart {
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    [super sendHeartbeat];
}

- (void)sendRenditionChange {
    [super sendRenditionChange];
}

- (void)sendError {
    [super sendError];
}

// Ads specific senders

- (void)sendAdBreakStart {
    self.numberOfAds = 0;
    [self.automat.actions sendAdBreakStart];
}

- (void)sendAdBreakEnd {
    [self.automat.actions sendAdBreakEnd];
}

- (void)sendAdQuartile {
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
