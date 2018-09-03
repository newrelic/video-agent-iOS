//
//  VideoTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "VideoTracker.h"
#import "TrackerAutomat.h"
#import "BackendActions.h"
#import "Vars.h"
#import <NewRelicAgent/NewRelic.h>

// TODO: implement Ads stuff

#define OBSERVATION_TIME        2.0f
#define HEARTBEAT_COUNT         (25.0f / OBSERVATION_TIME)
#define OVERWRITE_STUB          @throw([NSException exceptionWithName:NSGenericException reason:[NSStringFromSelector(_cmd) stringByAppendingString:@": Selector must be overwritten by subclass"] userInfo:nil]);\
                                return nil;

@interface VideoTracker ()

@property (nonatomic) TrackerAutomat *automat;
@property (nonatomic) NSDictionary<NSString *, NSValue *> *attributeGetters;
@property (nonatomic) NSTimer *playerStateObserverTimer;
@property (nonatomic) int heartbeatCounter;
@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int numErrors;
@property (nonatomic) NSTimeInterval requestTimestamp;
@property (nonatomic) NSTimeInterval trackerReadyTimestamp;
@property (nonatomic) NSTimeInterval heartbeatTimestamp;
@property (nonatomic) NSTimeInterval totalPlaytime;
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval timeSinceStartedTimestamp;

@end

@implementation VideoTracker

- (NSDictionary<NSString *,NSValue *> *)attributeGetters {
    if (!_attributeGetters) {
        _attributeGetters = @{
                        // Base
                        @"viewId": [NSValue valueWithPointer:@selector(getViewId)],
                        @"numberOfVideos": [NSValue valueWithPointer:@selector(getNumberOfVideos)],
                        @"coreVersion": [NSValue valueWithPointer:@selector(getCoreVersion)],
                        @"viewSession": [NSValue valueWithPointer:@selector(getViewSession)],
                        @"numberOfErrors": [NSValue valueWithPointer:@selector(getNumberOfErrors)],
                        // Implemented by tracker subclass
                        @"trackerName": [NSValue valueWithPointer:@selector(getTrackerName)],
                        @"trackerVersion": [NSValue valueWithPointer:@selector(getTrackerVersion)],
                        @"playerVersion": [NSValue valueWithPointer:@selector(getPlayerVersion)],
                        @"playerName": [NSValue valueWithPointer:@selector(getPlayerName)],
                        @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                        @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                        @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                        @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
                        @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                        @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
                        @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
                        @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
                        @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
                        @"isAd": [NSValue valueWithPointer:@selector(getIsAd)],
                        @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMutted)],
                        @"isAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
                        };
    }
    return _attributeGetters;
}

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
        self.trackerReadyTimestamp = self.timestamp;
    }
    return self;
}

#pragma mark - Utils

- (void)playNewVideo {
    if ([NewRelicAgent currentSessionId]) {
        self.viewId = [[NewRelicAgent currentSessionId] stringByAppendingFormat:@"-%d", self.viewIdIndex];
        self.viewIdIndex ++;
        self.numErrors = 0;
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
}

- (void)updateAttribute:(NSString *)attr {
    NSValue *value = self.attributeGetters[attr];
    SEL selector = [value pointerValue];
    
    if ([self respondsToSelector:selector]) {
        IMP imp = [self methodForSelector:selector];
        id<NSCopying> (*func)(id, SEL) = (void *)imp;
        
        [self setOptionKey:attr value:func(self, selector)];
    }
}

- (void)updateAttributes {
    for (NSString *key in self.attributeGetters) {
        [self updateAttribute:key];
    }
}

- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSince1970];
}

// ATTRIBUTES YET TO IMPLEMENT FOR "CONTENT":
// GENERAL ATTRS
/*
 contentId (?)
 contentTitle*
 contentRenditionName
 contentRenditionBitrate
 contentLanguage*
 contentIsFullscreen
 contentCdn*
 contentPreload
 */
// TIMING
/*
 timeSincePaused, only RESUME
 timeSinceBufferBegin, only BUFFER_END
 timeSinceSeekBegin, only SEEK_END
 timeSinceLastAd
 timeSinceLastRenditionChange, only RENDITION_CHANGE
 */

#pragma mark - Reset and setup, to be overwritten by subclass

- (void)reset {
    self.heartbeatCounter = 0;
    self.viewId = @"";
    self.viewIdIndex = 0;
    self.numErrors = 0;
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
    self.playtimeSinceLastEventTimestamp = 0;
    self.timeSinceStartedTimestamp = 0;
    [self playNewVideo];
    [self updateAttributes];
}

- (void)setup {}

#pragma mark - Base Tracker attributes

- (NSString *)getViewId {
    return self.viewId;
}

- (NSNumber *)getNumberOfVideos {
    return @(self.viewIdIndex);
}

- (NSString *)getCoreVersion {
    return [Vars string:@"CFBundleShortVersionString"];
}

- (NSString *)getViewSession {
    return [NewRelicAgent currentSessionId];
}

- (NSNumber *)getNumberOfErrors {
    return @(self.numErrors);
}

#pragma mark - Send requests and set options

- (void)preSend {
    [self updateAttributes];
    
    [self setOptionKey:@"timeSinceTrackerReady" value:@(1000.0f * (self.timestamp - self.trackerReadyTimestamp))];
    [self setOptionKey:@"timeSinceRequested" value:@(1000.0f * (self.timestamp - self.requestTimestamp))];
    
    if (self.heartbeatTimestamp > 0) {
        [self setOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (self.timestamp - self.heartbeatTimestamp))];
    }
    else {
        [self setOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (self.timestamp - self.requestTimestamp))];
    }
    
    if (self.automat.state == TrackerStatePlaying) {
        
        self.totalPlaytimeTimestamp = self.timestamp;
    }
    [self setOptionKey:@"totalPlaytime" value:@(1000.0f * self.totalPlaytime)];
    
    if (self.playtimeSinceLastEventTimestamp == 0) {
        self.playtimeSinceLastEventTimestamp = self.timestamp;
    }
    [self setOptionKey:@"playtimeSinceLastEvent" value:@(1000.0f * (self.timestamp - self.playtimeSinceLastEventTimestamp))];
    self.playtimeSinceLastEventTimestamp = self.timestamp;
    
    if (self.timeSinceStartedTimestamp > 0) {
        [self setOptionKey:@"timeSinceStarted" value:@(1000.0f * (self.timestamp - self.timeSinceStartedTimestamp))];
    }
    else {
        [self setOptionKey:@"timeSinceStarted" value:@0];
    }
}

- (void)sendRequest {
    self.totalPlaytime = 0;
    self.requestTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
    if (self.automat.state == TrackerStateStarting) {
        self.timeSinceStartedTimestamp = self.timestamp;
    }
    self.totalPlaytimeTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionFrameShown];
}

- (void)sendEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionVideoFinished];
    [self playNewVideo];
}

- (void)sendPause {
    [self preSend];
    [self.automat transition:TrackerTransitionClickPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendSeekStart {
    [self preSend];
    [self.automat transition:TrackerTransitionInitDraggingSlider];
}

- (void)sendSeekEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionEndDraggingSlider];
}

- (void)sendBufferStart {
    [self preSend];
    [self.automat transition:TrackerTransitionInitBuffering];
}

- (void)sendBufferEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionEndBuffering];
}

- (void)sendHeartbeat {
    self.heartbeatTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionHeartbeat];
}

- (void)sendRenditionChange {
    [self preSend];
    [self.automat transition:TrackerTransitionRenditionChanged];
}

- (void)sendError {
    [self preSend];
    [self.automat transition:TrackerTransitionErrorPlaying];
    self.numErrors ++;
}

- (void)setOptions:(NSDictionary *)opts {
    self.automat.actions.generalOptions = opts.mutableCopy;
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self.automat.actions.generalOptions setObject:value forKey:key];
}

- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action {
    [self.automat.actions.actionOptions setObject:opts.mutableCopy forKey:action];
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    NSMutableDictionary *dic = [self.automat.actions.actionOptions objectForKey:action];
    if (!dic) {
        dic = @{}.mutableCopy;
        [self.automat.actions.actionOptions setObject:dic forKey:action];
    }
    [dic setObject:value forKey:key];
}

#pragma mark - Timer stuff

- (void)startTimerEvent {
    if (self.playerStateObserverTimer) {
        [self abortTimerEvent];
    }
    
    self.playerStateObserverTimer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                                     target:self
                                                                   selector:@selector(internalTimerHandler:)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)abortTimerEvent {
    [self.playerStateObserverTimer invalidate];
    self.playerStateObserverTimer = nil;
}

- (void)internalTimerHandler:(NSTimer *)timer {
    
    [self updateAttribute:@"contentBitrate"];
    
    if ([(id<VideoTrackerProtocol>)self respondsToSelector:@selector(timeEvent)]) {
        [(id<VideoTrackerProtocol>)self timeEvent];
    }
    
    self.heartbeatCounter ++;
    
    if (self.heartbeatCounter >= HEARTBEAT_COUNT) {
        self.heartbeatCounter = 0;
        [self sendHeartbeat];
    }
}

@end
