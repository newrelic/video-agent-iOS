//
//  AdsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 10/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AdsTracker.h"
#import "DictionaryTrans.h"
#import "AdsTrackerCore.hpp"
#import "ValueHolder.hpp"
#import "GettersCAL.h"

//#define ACTION_FILTER @"AD_"

@interface AdsTracker ()
{
    AdsTrackerCore *adsTrackerCore;
}

@end

@implementation AdsTracker

//- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
//    if (!_adsAttributeGetters) {
//        _adsAttributeGetters = @{
//                                 @"numberOfAds": [NSValue valueWithPointer:@selector(getNumberOfAds)],
//                                 @"adId": [NSValue valueWithPointer:@selector(getVideoId)],
//                                 @"adTitle": [NSValue valueWithPointer:@selector(getTitle)],
//                                 @"adBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
//                                 @"adRenditionName": [NSValue valueWithPointer:@selector(getRenditionName)],
//                                 @"adRenditionBitrate": [NSValue valueWithPointer:@selector(getRenditionBitrate)],
//                                 @"adRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
//                                 @"adRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
//                                 @"adDuration": [NSValue valueWithPointer:@selector(getDuration)],
//                                 @"adPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
//                                 @"adLanguage": [NSValue valueWithPointer:@selector(getLanguage)],
//                                 @"adSrc": [NSValue valueWithPointer:@selector(getSrc)],
//                                 @"adIsMuted": [NSValue valueWithPointer:@selector(getIsMuted)],
//                                 @"adCdn": [NSValue valueWithPointer:@selector(getCdn)],
//                                 @"adFps": [NSValue valueWithPointer:@selector(getFps)],
//                                 @"adCreativeId": [NSValue valueWithPointer:@selector(getAdCreativeId)],
//                                 @"adPosition": [NSValue valueWithPointer:@selector(getAdPosition)],
//                                 @"adPartner": [NSValue valueWithPointer:@selector(getAdPartner)],
//                                 }.mutableCopy;
//    }
//    return _adsAttributeGetters;
//}

#pragma mark - Init

- (instancetype)initWithContentsTracker:(ContentsTracker *)tracker {
    if (self = [super init]) {
        adsTrackerCore = new AdsTrackerCore();
        [GettersCAL registerGetter:@"numberOfAds" target:self sel:@selector(getNumberOfAds)];
        [GettersCAL registerGetter:@"trackerName" target:self sel:@selector(getTrackerName)];
        [GettersCAL registerGetter:@"trackerVersion" target:self sel:@selector(getTrackerVersion)];
        [GettersCAL registerGetter:@"playerVersion" target:self sel:@selector(getPlayerVersion)];
        [GettersCAL registerGetter:@"playerName" target:self sel:@selector(getPlayerName)];
        [GettersCAL registerGetter:@"isAd" target:self sel:@selector(getIsAd)];
    }
    return self;
}

- (void)dealloc {
    delete adsTrackerCore;
}

- (TrackerState)state {
    return (TrackerState)adsTrackerCore->state();
}

- (void)reset {
    adsTrackerCore->reset();
}

- (void)setup {
    adsTrackerCore->setup();
}

#pragma mark - Senders

- (void)sendRequest {
    adsTrackerCore->sendRequest();
}

- (void)sendStart {
    adsTrackerCore->sendStart();
}

- (void)sendEnd {
    adsTrackerCore->sendEnd();
}

- (void)sendPause {
    adsTrackerCore->sendPause();
}

- (void)sendResume {
    adsTrackerCore->sendResume();
}

- (void)sendSeekStart {
    adsTrackerCore->sendSeekStart();
}

- (void)sendSeekEnd {
    adsTrackerCore->sendSeekEnd();
}

- (void)sendBufferStart {
    adsTrackerCore->sendBufferStart();
}

- (void)sendBufferEnd {
    adsTrackerCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    adsTrackerCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    adsTrackerCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    adsTrackerCore->sendError(std::string([message UTF8String]));
}

- (void)sendPlayerReady {
    adsTrackerCore->sendPlayerReady();
}

- (void)sendDownload {
    adsTrackerCore->sendDownload();
}

- (void)sendCustomAction:(NSString *)name {
    adsTrackerCore->sendCustomAction(std::string([name UTF8String]));
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    adsTrackerCore->sendCustomAction(std::string([name UTF8String]), fromDictionaryToMap(attr));
}

- (void)setOptions:(NSDictionary *)opts {
    adsTrackerCore->setOptions(fromDictionaryToMap(opts));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    adsTrackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value));
}

- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action {
    adsTrackerCore->setOptions(fromDictionaryToMap(opts), std::string([action UTF8String]));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    adsTrackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value), std::string([action UTF8String]));
}

// Ads specific senders

- (void)sendAdBreakStart {
    adsTrackerCore->sendAdBreakStart();
}

- (void)sendAdBreakEnd {
    adsTrackerCore->sendAdBreakEnd();
}

- (void)sendAdQuartile {
    adsTrackerCore->sendAdQuartile();
}

- (void)sendAdClick {
    adsTrackerCore->sendAdClick();
}

#pragma mark - Getters

- (NSNumber *)getNumberOfAds {
    return @(adsTrackerCore->getNumberOfAds());
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

#pragma mark - Time

- (void)startTimerEvent {
    adsTrackerCore->startTimerEvent();
}

- (void)abortTimerEvent {
    adsTrackerCore->abortTimerEvent();
}

// Timer event handler
- (void)trackerTimeEvent {
    adsTrackerCore->trackerTimeEvent();
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)adsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
