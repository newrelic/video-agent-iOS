//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "ContentsTrackerCore.hpp"
#import "DictionaryTrans.h"
#import "ValueHolder.hpp"
#import "GettersCAL.h"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
}
@end

@implementation ContentsTracker

#pragma mark - Private

- (ContentsTrackerCore *)getContentsTrackerCore {
    return contentsTrackerCore;
}

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        contentsTrackerCore = new ContentsTrackerCore();
        
        [GettersCAL registerGetter:@"trackerName" target:self sel:@selector(getTrackerName) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"trackerVersion" target:self sel:@selector(getTrackerVersion) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"playerVersion" target:self sel:@selector(getPlayerVersion) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"playerName" target:self sel:@selector(getPlayerName) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"isAd" target:self sel:@selector(getIsAd) origin:contentsTrackerCore];
        
        [GettersCAL registerGetter:@"contentTitle" target:self sel:@selector(getTitle) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentBitrate" target:self sel:@selector(getBitrate) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentRenditionName" target:self sel:@selector(getRenditionName) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentRenditionBitrate" target:self sel:@selector(getRenditionBitrate) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentRenditionWidth" target:self sel:@selector(getRenditionWidth) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentRenditionHeight" target:self sel:@selector(getRenditionHeight) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentDuration" target:self sel:@selector(getDuration) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentPlayhead" target:self sel:@selector(getPlayhead) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentLanguage" target:self sel:@selector(getLanguage) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentSrc" target:self sel:@selector(getSrc) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentIsMuted" target:self sel:@selector(getIsMuted) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentCdn" target:self sel:@selector(getCdn) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentFps" target:self sel:@selector(getFps) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentPlayrate" target:self sel:@selector(getPlayrate) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentIsLive" target:self sel:@selector(getIsLive) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentIsAutoplayed" target:self sel:@selector(getIsAutoplayed) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentPreload" target:self sel:@selector(getPreload) origin:contentsTrackerCore];
        [GettersCAL registerGetter:@"contentIsFullscreen" target:self sel:@selector(getIsFullscreen) origin:contentsTrackerCore];
    }
    return self;
}

- (void)dealloc {
    delete contentsTrackerCore;
}

- (TrackerState)state {
    return (TrackerState)contentsTrackerCore->state();
}

- (void)reset {
    contentsTrackerCore->reset();
}

- (void)setup {
    contentsTrackerCore->setup();
}

#pragma mark - Senders

- (void)sendRequest {
    contentsTrackerCore->sendRequest();
}

- (void)sendStart {
    contentsTrackerCore->sendStart();
}

- (void)sendEnd {
    contentsTrackerCore->sendEnd();
}

- (void)sendPause {
    contentsTrackerCore->sendPause();
}

- (void)sendResume {
    contentsTrackerCore->sendResume();
}

- (void)sendSeekStart {
    contentsTrackerCore->sendSeekStart();
}

- (void)sendSeekEnd {
    contentsTrackerCore->sendSeekEnd();
}

- (void)sendBufferStart {
    contentsTrackerCore->sendBufferStart();
}

- (void)sendBufferEnd {
    contentsTrackerCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    contentsTrackerCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    contentsTrackerCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    contentsTrackerCore->sendError(std::string([message UTF8String]));
}

- (void)sendPlayerReady {
    contentsTrackerCore->sendPlayerReady();
}

- (void)sendDownload {
    contentsTrackerCore->sendDownload();
}

- (void)sendCustomAction:(NSString *)name {
    contentsTrackerCore->sendCustomAction(std::string([name UTF8String]));
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    contentsTrackerCore->sendCustomAction(std::string([name UTF8String]), fromDictionaryToMap(attr));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    contentsTrackerCore->updateAttribute(std::string([key UTF8String]), fromNSValue((id)value));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    contentsTrackerCore->updateAttribute(std::string([key UTF8String]), fromNSValue((id)value), std::string([action UTF8String]));
}

#pragma mark - Getters

- (NSNumber *)getIsAd {
    return @NO;
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
    contentsTrackerCore->startTimerEvent();
}

- (void)abortTimerEvent {
    contentsTrackerCore->abortTimerEvent();
}

- (void)trackerTimeEvent {
    contentsTrackerCore->trackerTimeEvent();
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)contentsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
