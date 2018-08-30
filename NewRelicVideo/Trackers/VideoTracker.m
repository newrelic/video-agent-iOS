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

#define OBSERVATION_TIME        2.0f
#define HEARTBEAT_COUNT         (25.0f / OBSERVATION_TIME)

@interface VideoTracker ()

@property (nonatomic) TrackerAutomat *automat;
@property (nonatomic) NSTimer *playerStateObserverTimer;
@property (nonatomic) int heartbeatCounter;

@end

@implementation VideoTracker

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
        [self setOptions:@{
                           @"trackerName": [self getTrackerName],
                           @"trackerVersion": [self getTrackerVersion],
                           @"playerVersion": [self getPlayerVersion],
                           @"playerName": [self getPlayerName]
                           }];
    }
    return self;
}

#pragma mark - Reset and setup, to be overwritten by subclass

- (void)reset {
    self.heartbeatCounter = 0;
}

- (void)setup {}

// TODO: move it to a protocol? the default implementation doesn't work and must be implemented by subclass
// Pros: cleaner
// Cons: mixed strategy, the tracker needs to subclass and implement a protocol, and some of the getters may need a default implementation and other may not.
#pragma mark - Tracker specific attributers, to be overwritten by subclass

- (NSString *)getTrackerName {
    return nil;
}

- (NSString *)getTrackerVersion {
    return nil;
}

- (NSString *)getPlayerVersion {
    return nil;
}

- (NSString *)getPlayerName {
    return nil;
}

#pragma mark - Send requests and set options

- (void)sendRequest {
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
    [self.automat transition:TrackerTransitionFrameShown];
}

- (void)sendEnd {
    [self.automat transition:TrackerTransitionVideoFinished];
}

- (void)sendPause {
    [self.automat transition:TrackerTransitionClickPause];
}

- (void)sendResume {
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendSeekStart {
    [self.automat transition:TrackerTransitionInitDraggingSlider];
}

- (void)sendSeekEnd {
    [self.automat transition:TrackerTransitionEndDraggingSlider];
}

- (void)sendBufferStart {
    [self.automat transition:TrackerTransitionInitBuffering];
}

- (void)sendBufferEnd {
    [self.automat transition:TrackerTransitionEndBuffering];
}

- (void)sendHeartbeat {
    [self.automat transition:TrackerTransitionHeartbeat];
}

- (void)sendRenditionChange {
    [self.automat transition:TrackerTransitionRenditionChanged];
}

- (void)sendError {
    [self.automat transition:TrackerTransitionErrorPlaying];
}

- (void)setOptions:(NSDictionary *)opts {
    self.automat.actions.userOptions = opts.mutableCopy;
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self.automat.actions.userOptions setObject:value forKey:key];
}

#pragma mark - Timer stuff

- (void)startPlayerStateObserverTimer {
    if (self.playerStateObserverTimer) {
        [self abortPlayerStateObserverTimer];
    }
    
    self.playerStateObserverTimer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                                     target:self
                                                                   selector:@selector(playerObserverMethod:)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)abortPlayerStateObserverTimer {
    [self.playerStateObserverTimer invalidate];
    self.playerStateObserverTimer = nil;
}

- (void)playerObserverMethod:(NSTimer *)timer {

    [self timeEvent];
    
    self.heartbeatCounter ++;
    
    if (self.heartbeatCounter >= HEARTBEAT_COUNT) {
        self.heartbeatCounter = 0;
        [self sendHeartbeat];
    }
}

// To be overwritten by subclass
- (void)timeEvent {}

@end
