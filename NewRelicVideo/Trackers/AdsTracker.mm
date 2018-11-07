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
    [self registerGetter:@"numberOfAds" sel:@selector(getNumberOfAds)];
    [self registerGetter:@"trackerName" sel:@selector(getTrackerName)];
    [self registerGetter:@"trackerVersion" sel:@selector(getTrackerVersion)];
    [self registerGetter:@"playerVersion" sel:@selector(getPlayerVersion)];
    [self registerGetter:@"playerName" sel:@selector(getPlayerName)];
    [self registerGetter:@"isAd" sel:@selector(getIsAd)];
    
    [self registerGetter:@"numberOfAds" sel:@selector(getNumberOfAds)];
    [self registerGetter:@"adId" sel:@selector(getVideoId)];
    [self registerGetter:@"adTitle" sel:@selector(getTitle)];
    [self registerGetter:@"adBitrate" sel:@selector(getBitrate)];
    [self registerGetter:@"adRenditionName" sel:@selector(getRenditionName)];
    [self registerGetter:@"adRenditionBitrate" sel:@selector(getRenditionBitrate)];
    [self registerGetter:@"adRenditionWidth" sel:@selector(getRenditionWidth)];
    [self registerGetter:@"adRenditionHeight" sel:@selector(getRenditionHeight)];
    [self registerGetter:@"adDuration" sel:@selector(getDuration)];
    [self registerGetter:@"adPlayhead" sel:@selector(getPlayhead)];
    [self registerGetter:@"adLanguage" sel:@selector(getLanguage)];
    [self registerGetter:@"adSrc" sel:@selector(getSrc)];
    [self registerGetter:@"adIsMuted" sel:@selector(getIsMuted)];
    [self registerGetter:@"adCdn" sel:@selector(getCdn)];
    [self registerGetter:@"adFps" sel:@selector(getFps)];
    [self registerGetter:@"adCreativeId" sel:@selector(getAdCreativeId)];
    [self registerGetter:@"adPosition" sel:@selector(getAdPosition)];
    [self registerGetter:@"adPartner" sel:@selector(getAdPartner)];
}

- (void)dealloc {
    delete adsTrackerCore;
}

- (void)registerGetter:(NSString *)name sel:(SEL)selector {
    [GettersCAL registerGetter:name target:self sel:selector origin:adsTrackerCore];
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
