//
//  Tracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <NewRelicAgent/NewRelic.h>
#import "Tracker.h"
#import "PlaybackAutomat.h"
#import "BackendActions.h"
#import "EventDefs.h"
#import "Vars.h"

#define OBSERVATION_TIME        2.0f
#define HEARTBEAT_COUNT         (25.0f / OBSERVATION_TIME)

@interface Tracker ()

@property (nonatomic) PlaybackAutomat *automat;
@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *attributeGetters;
@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int numErrors;
@property (nonatomic) int heartbeatCounter;
@property (nonatomic) NSTimer *playerStateObserverTimer;
@property (nonatomic) NSTimeInterval timeSinceLastRenditionChangeTimestamp;
@property (nonatomic) NSTimeInterval trackerReadyTimestamp;

@end

@implementation Tracker

- (NSMutableDictionary<NSString *, NSValue *> *)attributeGetters {
    if (!_attributeGetters) {
        _attributeGetters = @{
                              // Base Tracker
                              @"viewId": [NSValue valueWithPointer:@selector(getViewId)],
                              @"numberOfVideos": [NSValue valueWithPointer:@selector(getNumberOfVideos)],
                              @"coreVersion": [NSValue valueWithPointer:@selector(getCoreVersion)],
                              @"viewSession": [NSValue valueWithPointer:@selector(getViewSession)],
                              @"numberOfErrors": [NSValue valueWithPointer:@selector(getNumberOfErrors)],
                              // Implemented by tracker subclass, required
                              @"trackerName": [NSValue valueWithPointer:@selector(getTrackerName)],
                              @"trackerVersion": [NSValue valueWithPointer:@selector(getTrackerVersion)],
                              @"playerVersion": [NSValue valueWithPointer:@selector(getPlayerVersion)],
                              @"playerName": [NSValue valueWithPointer:@selector(getPlayerName)],
                              @"isAd": [NSValue valueWithPointer:@selector(getIsAd)],
                              }.mutableCopy;
    }
    return _attributeGetters;
}

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[PlaybackAutomat alloc] init];
        self.automat.isAd = [self isMeAd];
        self.trackerReadyTimestamp = TIMESTAMP;
    }
    return self;
}

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

- (BOOL)isMeAd {
    if ([(id<TrackerProtocol>)self respondsToSelector:@selector(getIsAd)]) {
        NSNumber *n = [(id<TrackerProtocol>)self getIsAd];
        return n.boolValue;
    }
    else {
        return NO;
    }
}

- (void)updateAttribute:(NSString *)attr {
    [self updateAttribute:attr forAction:nil];
}

- (void)updateAttribute:(NSString *)attr forAction:(NSString *)action {
    
    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.attributeGetters];
    
    if (val) {
        if (action) {
            [self setOptionKey:attr value:val forAction:action];
        }
        else {
            [self setOptionKey:attr value:val];
        }
    }
}

- (void)updateBaseAttributes {
    for (NSString *key in self.attributeGetters) {
        [self updateAttribute:key];
    }
}

#pragma mark - Public

- (void)reset {
    self.viewId = @"";
    self.viewIdIndex = 0;
    self.numErrors = 0;
    self.heartbeatCounter = 0;
    [self playNewVideo];
    [self updateBaseAttributes];
}

- (void)setup {}

// TODO: variable names for timestamps are confusing, because we call it "timeSinceStartedTimestamp", we should call it "startedTimestamp", because the timeSince is what we get substracting it from the current timestamp.

- (void)preSend {
    
    [self updateBaseAttributes];
    
    if (self.trackerReadyTimestamp > 0) {
        [self setOptionKey:@"timeSinceTrackerReady" value:@(1000.0f * TIMESINCE(self.trackerReadyTimestamp))];
    }
    else {
        [self setOptionKey:@"timeSinceTrackerReady" value:@0];
    }
    
    if (self.timeSinceLastRenditionChangeTimestamp > 0) {
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@(1000.0f * TIMESINCE(self.timeSinceLastRenditionChangeTimestamp)) forAction:@"_RENDITION_CHANGE"];
    }
    else {
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@0 forAction:@"_RENDITION_CHANGE"];
    }
}

- (void)sendRequest {
    [self preSend];
    [self.automat sendRequest];
    [self startTimerEvent];
}

- (void)sendStart {
    [self preSend];
    [self.automat sendStart];
}

- (void)sendEnd {
    [self preSend];
    [self.automat sendEnd];
    [self playNewVideo];
    [self abortTimerEvent];
}

- (void)sendPause {
    [self preSend];
    [self.automat sendPause];
}

- (void)sendResume {
    [self preSend];
    [self.automat sendResume];
}

- (void)sendSeekStart {
    [self preSend];
    [self.automat sendSeekStart];
}

- (void)sendSeekEnd {
    [self preSend];
    [self.automat sendSeekEnd];
}

- (void)sendBufferStart {
    [self preSend];
    [self.automat sendBufferStart];
}

- (void)sendBufferEnd {
    [self preSend];
    [self.automat sendBufferEnd];
}

- (void)sendHeartbeat {
    [self preSend];
    [self.automat sendHeartbeat];
}

- (void)sendRenditionChange {
    [self preSend];
    [self.automat sendRenditionChange];
    self.timeSinceLastRenditionChangeTimestamp = TIMESTAMP;
}

- (void)sendError:(NSString *)message {
    [self preSend];
    [self.automat sendError:message];
    self.numErrors ++;
}

- (void)sendPlayerReady {
    [self.automat.actions sendPlayerReady];
}

/*
 TODO:
 - Implement DOWNLOAD's "state" attribute. Argument to sendDownload method.
 */

- (void)sendDownload {
    [self.automat.actions sendDownload];
}

- (void)sendCustomAction:(NSString *)name {
    [self.automat.actions sendAction:name attr:nil];
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    [self.automat.actions sendAction:name attr:attr];
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

#pragma mark - Attributes

- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSMutableDictionary<NSString *,NSValue *> *)attributeGetters {
    NSValue *value = attributeGetters[attr];
    SEL selector = [value pointerValue];
    
    if ([self respondsToSelector:selector]) {
        IMP imp = [self methodForSelector:selector];
        id<NSCopying> (*func)(id, SEL) = (void *)imp;
        return func(self, selector);
    }
    else {
        return nil;
    }
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
    
    [self trackerTimeEvent];
    
    self.heartbeatCounter ++;
    
    if (self.heartbeatCounter >= HEARTBEAT_COUNT) {
        self.heartbeatCounter = 0;
        [self sendHeartbeat];
    }
}

// To be overwritten
- (void)trackerTimeEvent {}

@end
