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
    [GettersCAL registerGetter:@"numberOfAds" target:self sel:@selector(getNumberOfAds) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"trackerName" target:self sel:@selector(getTrackerName) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"trackerVersion" target:self sel:@selector(getTrackerVersion) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"playerVersion" target:self sel:@selector(getPlayerVersion) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"playerName" target:self sel:@selector(getPlayerName) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"isAd" target:self sel:@selector(getIsAd) origin:adsTrackerCore];
    
    [GettersCAL registerGetter:@"numberOfAds" target:self sel:@selector(getNumberOfAds) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adId" target:self sel:@selector(getVideoId) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adTitle" target:self sel:@selector(getTitle) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adBitrate" target:self sel:@selector(getBitrate) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adRenditionName" target:self sel:@selector(getRenditionName) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adRenditionBitrate" target:self sel:@selector(getRenditionBitrate) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adRenditionWidth" target:self sel:@selector(getRenditionWidth) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adRenditionHeight" target:self sel:@selector(getRenditionHeight) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adDuration" target:self sel:@selector(getDuration) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adPlayhead" target:self sel:@selector(getPlayhead) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adLanguage" target:self sel:@selector(getLanguage) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adSrc" target:self sel:@selector(getSrc) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adIsMuted" target:self sel:@selector(getIsMuted) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adCdn" target:self sel:@selector(getCdn) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adFps" target:self sel:@selector(getFps) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adCreativeId" target:self sel:@selector(getAdCreativeId) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adPosition" target:self sel:@selector(getAdPosition) origin:adsTrackerCore];
    [GettersCAL registerGetter:@"adPartner" target:self sel:@selector(getAdPartner) origin:adsTrackerCore];
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

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    adsTrackerCore->updateAttribute(std::string([key UTF8String]), fromNSValue((id)value));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    adsTrackerCore->updateAttribute(std::string([key UTF8String]), fromNSValue((id)value), std::string([action UTF8String]));
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
