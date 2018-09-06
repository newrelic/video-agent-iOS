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
#import "EventDefs.h"
#import <NewRelicAgent/NewRelic.h>

/*
 Opció 1:
 - Agefir metodes send que mirin is isAd i executin el metode que cal al automat.
 - Posar totes les noves propietats necessaries per a Ads i Contents. Tb usant isAd per discriminar.
 - Al temporitzador, tb mirar si isAd per fer o no fer coses (bitrate per exemple).
 
 Opció 2:
 - Crear una classe base VideoTracker comuna amb només el codi i les propietats compartides entre Contents i Ads.
 - Crear dues classes derivades: ContentsTracker i AdsTracker.
 - El tracker Content és el responsable de registrar el AdsTracker "- (void)registerAdsTracker:(AdsTracker *)tracker;"
 -
 
 Opció 3:
 - Una sola classes VideoTracker amb el codi comu i dues classes específiques.
 - Composició. Intenalemtn usem AdsTracker o ContentTracker en funció de les necessitats.
 */

#define OBSERVATION_TIME        2.0f
#define HEARTBEAT_COUNT         (25.0f / OBSERVATION_TIME)

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
@property (nonatomic) NSTimeInterval timeSincePausedTimestamp;
@property (nonatomic) NSTimeInterval timeSinceBufferBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceSeekBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceLastRenditionChangeTimestamp;

// TODO: ADD property, @property (nonatomic) VideoTracker<VideoTrackerProtocol>  *adsTracker;  To be added by contents tracker

@end

@implementation VideoTracker

// TODO : separate the content and ad atributes (and common ones)

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
                        @"isAd": [NSValue valueWithPointer:@selector(getIsAd)],
                        // Content properties
                        @"contentId": [NSValue valueWithPointer:@selector(getVideoId)],
                        @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                        @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                        @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                        @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
                        @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                        @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
                        @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
                        @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
                        @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
                        @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMutted)],
                        @"contentIsAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
                        @"contentIsFullscreen": [NSValue valueWithPointer:@selector(getIsFullscreen)],
                        // TODO: Ad properties
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
 contentTitle*
 contentRenditionName
 contentRenditionBitrate
 contentLanguage*
 contentCdn*
 contentPreload
 */
// TIMING
/*
 timeSinceLastAd
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

// TODO : separate the content and ad atributes (and common ones)

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
    
    if (self.timeSincePausedTimestamp > 0) {
        [self setOptionKey:@"timeSincePaused" value:@(1000.0f * (self.timestamp - self.timeSincePausedTimestamp)) forAction:CONTENT_RESUME];
    }
    else {
        [self setOptionKey:@"timeSincePaused" value:@0 forAction:CONTENT_RESUME];
    }
    
    if (self.timeSinceBufferBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceBufferBegin" value:@(1000.0f * (self.timestamp - self.timeSinceBufferBeginTimestamp)) forAction:CONTENT_BUFFER_END];
    }
    else {
        [self setOptionKey:@"timeSinceBufferBegin" value:@0 forAction:CONTENT_BUFFER_END];
    }
    
    if (self.timeSinceSeekBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceSeekBegin" value:@(1000.0f * (self.timestamp - self.timeSinceSeekBeginTimestamp)) forAction:CONTENT_SEEK_END];
    }
    else {
        [self setOptionKey:@"timeSinceSeekBegin" value:@0 forAction:CONTENT_SEEK_END];
    }
    
    if (self.timeSinceLastRenditionChangeTimestamp > 0) {
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@(1000.0f * (self.timestamp - self.timeSinceLastRenditionChangeTimestamp)) forAction:CONTENT_RENDITION_CHANGE];
    }
    else {
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@0 forAction:CONTENT_RENDITION_CHANGE];
    }
}

// TODO: while Ad, use a different TrackerAutomat

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
    self.timeSincePausedTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionClickPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendSeekStart {
    self.timeSinceSeekBeginTimestamp = self.timestamp;
    [self preSend];
    [self.automat transition:TrackerTransitionInitDraggingSlider];
}

- (void)sendSeekEnd {
    [self preSend];
    [self.automat transition:TrackerTransitionEndDraggingSlider];
}

- (void)sendBufferStart {
    self.timeSinceBufferBeginTimestamp = self.timestamp;
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
    self.timeSinceLastRenditionChangeTimestamp = self.timestamp;
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
