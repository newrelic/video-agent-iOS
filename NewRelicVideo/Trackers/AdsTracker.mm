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
#import "ContentsTrackerCore.hpp"
#import "ContentsTracker.h"

@interface ContentsTracker ()

- (ContentsTrackerCore *)getContentsTrackerCore;

@end

@interface AdsTracker ()
{
    AdsTrackerCore *adsTrackerCore;
}
@end

@implementation AdsTracker

#pragma mark - Init

- (instancetype)initWithContentsTracker:(ContentsTracker *)tracker {
    if (self = [super init]) {
        adsTrackerCore = new AdsTrackerCore([tracker getContentsTrackerCore]);
        [self setupGetters];
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        adsTrackerCore = new AdsTrackerCore();
        [self setupGetters];
    }
    return self;
}

- (void)setupGetters {
    [GettersCAL registerGetter:@"numberOfAds" target:self sel:@selector(getNumberOfAds)];
    [GettersCAL registerGetter:@"trackerName" target:self sel:@selector(getTrackerName)];
    [GettersCAL registerGetter:@"trackerVersion" target:self sel:@selector(getTrackerVersion)];
    [GettersCAL registerGetter:@"playerVersion" target:self sel:@selector(getPlayerVersion)];
    [GettersCAL registerGetter:@"playerName" target:self sel:@selector(getPlayerName)];
    [GettersCAL registerGetter:@"isAd" target:self sel:@selector(getIsAd)];
    
    [GettersCAL registerGetter:@"numberOfAds" target:self sel:@selector(getNumberOfAds)];
    [GettersCAL registerGetter:@"adId" target:self sel:@selector(getVideoId)];
    [GettersCAL registerGetter:@"adTitle" target:self sel:@selector(getTitle)];
    [GettersCAL registerGetter:@"adBitrate" target:self sel:@selector(getBitrate)];
    [GettersCAL registerGetter:@"adRenditionName" target:self sel:@selector(getRenditionName)];
    [GettersCAL registerGetter:@"adRenditionBitrate" target:self sel:@selector(getRenditionBitrate)];
    [GettersCAL registerGetter:@"adRenditionWidth" target:self sel:@selector(getRenditionWidth)];
    [GettersCAL registerGetter:@"adRenditionHeight" target:self sel:@selector(getRenditionHeight)];
    [GettersCAL registerGetter:@"adDuration" target:self sel:@selector(getDuration)];
    [GettersCAL registerGetter:@"adPlayhead" target:self sel:@selector(getPlayhead)];
    [GettersCAL registerGetter:@"adLanguage" target:self sel:@selector(getLanguage)];
    [GettersCAL registerGetter:@"adSrc" target:self sel:@selector(getSrc)];
    [GettersCAL registerGetter:@"adIsMuted" target:self sel:@selector(getIsMuted)];
    [GettersCAL registerGetter:@"adCdn" target:self sel:@selector(getCdn)];
    [GettersCAL registerGetter:@"adFps" target:self sel:@selector(getFps)];
    [GettersCAL registerGetter:@"adCreativeId" target:self sel:@selector(getAdCreativeId)];
    [GettersCAL registerGetter:@"adPosition" target:self sel:@selector(getAdPosition)];
    [GettersCAL registerGetter:@"adPartner" target:self sel:@selector(getAdPartner)];
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

- (void)trackerTimeEvent {
    adsTrackerCore->trackerTimeEvent();
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)adsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
