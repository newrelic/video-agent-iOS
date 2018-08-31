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
@property (nonatomic) NSTimer *playerStateObserverTimer;
@property (nonatomic) int heartbeatCounter;
@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int numErrors;
@property (nonatomic) NSDictionary<NSString *, NSValue *> *attributes;

@end

@implementation VideoTracker

- (NSDictionary<NSString *,NSValue *> *)attributes {
    if (!_attributes) {
        _attributes = @{
                        @"trackerName": [NSValue valueWithPointer:@selector(getTrackerName)],
                        @"trackerVersion": [NSValue valueWithPointer:@selector(getTrackerVersion)],
                        @"playerVersion": [NSValue valueWithPointer:@selector(getPlayerVersion)],
                        @"playerName": [NSValue valueWithPointer:@selector(getPlayerName)],
                        @"viewId": [NSValue valueWithPointer:@selector(getViewId)],
                        @"numberOfVideos": [NSValue valueWithPointer:@selector(getNumberOfVideos)],
                        @"coreVersion": [NSValue valueWithPointer:@selector(getCoreVersion)],
                        @"viewSession": [NSValue valueWithPointer:@selector(getViewSession)],
                        @"numberOfErrors": [NSValue valueWithPointer:@selector(getNumberOfErrors)],
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
                        };
    }
    return _attributes;
}

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
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
    NSValue *value = self.attributes[attr];
    SEL selector = [value pointerValue];
    
    if ([self respondsToSelector:selector]) {
        IMP imp = [self methodForSelector:selector];
        id<NSCopying> (*func)(id, SEL) = (void *)imp;
        
        [self setOptionKey:attr value:func(self, selector)];
    }
}

- (void)updateAttributes {
    for (NSString *key in self.attributes) {
        [self updateAttribute:key];
    }
}

// ATTRIBUTES YET TO IMPLEMENT FOR "CONTENT":
// GENERAL ATTRS
/*
 contentId
 contentTitle*
 contentRenditionName
 contentRenditionBitrate
 contentLanguage*
 contentIsFullscreen
 contentIsMuted
 contentCdn*
 contentIsAutoplayed
 contentPreload
 */
// SPECIAL ATTRS
/*
 shift, only for RENDITION_CHANGE event
 */
// PLAY TIME
/*
 totalPlaytime
 playtimeSinceLastEvent
 */
// TIMING
/*
 timeSinceTrackerReady
 timeSinceRequested
 timeSinceLastHeartbeat*
 timeSinceStarted
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
    [self playNewVideo];
    [self updateAttributes];
}

- (void)setup {}

#pragma mark - Base Tracker attributers

- (NSString *)getViewId {
    return self.viewId;
}

- (NSNumber *)getNumberOfVideos {
    return @(self.viewIdIndex);
}

- (NSString *)getCoreVersion {
    return [Vars stringFromPlist:@"CFBundleShortVersionString"];
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
}

- (void)sendRequest {
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
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
    [dic setObject:value forKey:key];
}

#pragma mark - Timer stuff

- (void)startTimerEvent {
    if (self.playerStateObserverTimer) {
        [self abortTimerEvent];
    }
    
    self.playerStateObserverTimer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                                     target:self
                                                                   selector:@selector(playerObserverMethod:)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)abortTimerEvent {
    [self.playerStateObserverTimer invalidate];
    self.playerStateObserverTimer = nil;
}

- (void)playerObserverMethod:(NSTimer *)timer {

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
