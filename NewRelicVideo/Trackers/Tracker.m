//
//  Tracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <NewRelicAgent/NewRelic.h>
#import "Tracker.h"
#import "TrackerAutomat.h"
#import "BackendActions.h"
#import "EventDefs.h"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;
@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int numErrors;
@property (nonatomic) NSTimeInterval timeSinceLastRenditionChangeTimestamp;

@end

@implementation Tracker

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
        self.automat.isAd = [self isMeAd];
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

- (BOOL)isMeAd {
    if ([(id<TrackerProtocol>)self respondsToSelector:@selector(getIsAd)]) {
        NSNumber *n = [(id<TrackerProtocol>)self getIsAd];
        return n.boolValue;
    }
    else {
        return NO;
    }
}

#pragma mark - Public

- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSince1970];
}

- (void)reset {
    self.viewId = @"";
    self.viewIdIndex = 0;
    self.numErrors = 0;
    [self playNewVideo];
//    [self updateAttributes];
}

- (void)setup {}

- (void)preSend {
    // TODO: update attributes
    
    if (self.timeSinceLastRenditionChangeTimestamp > 0) {
        NSString *action = [self isMeAd] ? AD_RENDITION_CHANGE : CONTENT_RENDITION_CHANGE;
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@(1000.0f * (self.timestamp - self.timeSinceLastRenditionChangeTimestamp)) forAction:action];
    }
    else {
        NSString *action = [self isMeAd] ? AD_RENDITION_CHANGE : CONTENT_RENDITION_CHANGE;
        [self setOptionKey:@"timeSinceLastRenditionChange" value:@0 forAction:action];
    }
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

@end
