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

@end

@implementation VideoTracker

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

- (void)updateAttributes {
    [self setOptions:@{
                       @"trackerName": [self getTrackerName],
                       @"trackerVersion": [self getTrackerVersion],
                       @"playerVersion": [self getPlayerVersion],
                       @"playerName": [self getPlayerName],
                       @"viewId": [self getViewId],
                       @"numberOfVideos": [self getNumberOfVideos],
                       @"coreVersion": [self getCoreVersion],
                       @"viewSession": [self getViewSession],
                       @"numberOfErrors": @(self.numErrors),
                       @"isAd": [self getIsAd],
                       @"contentBitrate": [self getBitrate],
                       @"contentRenditionWidth": [self getRenditionWidth],
                       @"contentRenditionHeight": [self getRenditionHeight],
                       }];
}

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

#pragma mark - Tracker specific attributers, to be overwritten by subclass

- (NSString *)getTrackerName { OVERWRITE_STUB }

- (NSString *)getTrackerVersion { OVERWRITE_STUB }

- (NSString *)getPlayerVersion { OVERWRITE_STUB }

- (NSString *)getPlayerName { OVERWRITE_STUB }

- (NSNumber *)getBitrate { OVERWRITE_STUB }

- (NSNumber *)getRenditionWidth { OVERWRITE_STUB }

- (NSNumber *)getRenditionHeight { OVERWRITE_STUB }

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

// TODO: implement Ads stuff
- (NSNumber *)getIsAd {
    return @(false);
}

#pragma mark - Send requests and set options

- (void)sendRequest {
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
    [self updateAttributes];
    [self.automat transition:TrackerTransitionFrameShown];
}

- (void)sendEnd {
    [self.automat transition:TrackerTransitionVideoFinished];
    [self playNewVideo];
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
    [self updateAttributes];
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
    self.numErrors ++;
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

    [self setOptionKey:@"contentBitrate" value:[self getBitrate]];
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
