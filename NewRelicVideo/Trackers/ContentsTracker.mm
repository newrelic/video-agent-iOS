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
#import "TimerCAL.h"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
    float heartbeatTime;
    BOOL timerIsActivated;
    BOOL heartbeatEnabled;
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
        
        [self registerGetter:@"trackerName" sel:@selector(getTrackerName)];
        [self registerGetter:@"trackerVersion" sel:@selector(getTrackerVersion)];
        [self registerGetter:@"playerVersion" sel:@selector(getPlayerVersion)];
        [self registerGetter:@"playerName" sel:@selector(getPlayerName)];
        [self registerGetter:@"isAd" sel:@selector(getIsAd)];
        
        [self registerGetter:@"contentTitle" sel:@selector(getTitle)];
        [self registerGetter:@"contentBitrate" sel:@selector(getBitrate)];
        [self registerGetter:@"contentRenditionName" sel:@selector(getRenditionName)];
        [self registerGetter:@"contentRenditionBitrate" sel:@selector(getRenditionBitrate)];
        [self registerGetter:@"contentRenditionWidth" sel:@selector(getRenditionWidth)];
        [self registerGetter:@"contentRenditionHeight" sel:@selector(getRenditionHeight)];
        [self registerGetter:@"contentDuration" sel:@selector(getDuration)];
        [self registerGetter:@"contentPlayhead" sel:@selector(getPlayhead)];
        [self registerGetter:@"contentLanguage" sel:@selector(getLanguage)];
        [self registerGetter:@"contentSrc" sel:@selector(getSrc)];
        [self registerGetter:@"contentIsMuted" sel:@selector(getIsMuted)];
        [self registerGetter:@"contentCdn" sel:@selector(getCdn)];
        [self registerGetter:@"contentFps" sel:@selector(getFps)];
        [self registerGetter:@"contentPlayrate" sel:@selector(getPlayrate)];
        [self registerGetter:@"contentIsLive" sel:@selector(getIsLive)];
        [self registerGetter:@"contentIsAutoplayed" sel:@selector(getIsAutoplayed)];
        [self registerGetter:@"contentPreload" sel:@selector(getPreload)];
        [self registerGetter:@"contentIsFullscreen" sel:@selector(getIsFullscreen)];
    }
    return self;
}

- (void)dealloc {
    delete contentsTrackerCore;
}

- (void)registerGetter:(NSString *)name sel:(SEL)selector {
    [GettersCAL registerGetter:name target:self sel:selector origin:contentsTrackerCore];
}

- (TrackerState)state {
    return (TrackerState)contentsTrackerCore->state();
}

- (void)reset {
    contentsTrackerCore->reset();
}

- (void)setup {
    timerIsActivated = NO;
    heartbeatEnabled = YES;
    heartbeatTime = HEARTBEAT_TIME;
    contentsTrackerCore->setup();
}

#pragma mark - Senders

- (void)sendRequest {
    contentsTrackerCore->sendRequest();
    [self startHbTimer];
}

- (void)sendStart {
    contentsTrackerCore->sendStart();
}

- (void)sendEnd {
    [self stopHbTimer];
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

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)contentsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

- (void)enableHeartbeat {
    heartbeatEnabled = YES;
    [self startHbTimer];
}

- (void)disableHeartbeat {
    heartbeatEnabled = NO;
    [self stopHbTimer];
}

- (void)setHeartbeatTime:(int)seconds {
    seconds = MAX(5, seconds);
    heartbeatTime = (float)seconds;
    
    if (timerIsActivated) {
        [self stopHbTimer];
        [self startHbTimer];
    }
}

// Private

- (void)startHbTimer {
    if (heartbeatEnabled) {
        timerIsActivated = YES;
        [[TimerCAL sharedInstance] startTimer:self time:heartbeatTime];
    }
}

- (void)stopHbTimer {
    timerIsActivated = NO;
    [[TimerCAL sharedInstance] abortTimer:self];
}

@end
