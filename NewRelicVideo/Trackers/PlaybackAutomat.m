//
//  PlaybackAutomat.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 21/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "PlaybackAutomat.h"
#import "BackendActions.h"
#import "Stack.h"

typedef NS_ENUM(NSUInteger, TrackerTransition) {
    TrackerTransitionAutoplay = 0,
    TrackerTransitionClickPlay,
    TrackerTransitionClickPause,
    TrackerTransitionClickStop,
    TrackerTransitionFrameShown,
    TrackerTransitionInitBuffering,
    TrackerTransitionEndBuffering,
    TrackerTransitionVideoFinished,
    TrackerTransitionInitDraggingSlider,
    TrackerTransitionEndDraggingSlider,
};

@interface PlaybackAutomat ()

@property (nonatomic) TrackerState state;
@property (nonatomic) BackendActions *actions;
@property (nonatomic) Stack<NSNumber *> *stateStack;

@end

@implementation PlaybackAutomat

- (instancetype)init {
    if (self = [super init]) {
        self.state = TrackerStateStopped;
        self.stateStack = [Stack new];
        self.actions = [[BackendActions alloc] init];
    }
    return self;
}

#pragma mark - Senders

- (void)sendRequest {
    if ([self transition:TrackerTransitionClickPlay]) {
        if (!self.isAd) {
            [self.actions sendRequest];
        }
        else {
            [self.actions sendAdRequest];
        }
    }
}

- (void)sendStart {
    if ([self transition:TrackerTransitionFrameShown]) {
        if (!self.isAd) {
            [self.actions sendStart];
        }
        else {
            [self.actions sendAdStart];
        }
    }
}

- (void)sendEnd {
    if (!self.isAd) {
        [self.actions sendEnd];
    }
    else {
        [self.actions sendAdEnd];
    }
    
    [self.stateStack clear];
    [self moveState:TrackerStateStopped];
}

- (void)sendPause {
    if ([self transition:TrackerTransitionClickPause]) {
        if (!self.isAd) {
            [self.actions sendPause];
        }
        else {
            [self.actions sendAdPause];
        }
    }
}

- (void)sendResume {
    if ([self transition:TrackerTransitionClickPlay]) {
        if (!self.isAd) {
            [self.actions sendResume];
        }
        else {
            [self.actions sendAdResume];
        }
    }
}

- (void)sendSeekStart {
    if (!self.isAd) {
        [self.actions sendSeekStart];
    }
    else {
        [self.actions sendAdSeekStart];
    }
    
    [self moveStateAndPush:TrackerStateSeeking];
}

- (void)sendSeekEnd {
    if ([self transition:TrackerTransitionEndDraggingSlider]) {
        if (!self.isAd) {
            [self.actions sendSeekEnd];
        }
        else {
            [self.actions sendAdSeekEnd];
        }
    }
}

- (void)sendBufferStart {
    if (!self.isAd) {
        [self.actions sendBufferStart];
    }
    else {
        [self.actions sendAdBufferStart];
    }
    
    [self moveStateAndPush:TrackerStateBuffering];
}

- (void)sendBufferEnd {
    if ([self transition:TrackerTransitionEndBuffering]) {
        if (!self.isAd) {
            [self.actions sendBufferEnd];
        }
        else {
            [self.actions sendAdBufferEnd];
        }
    }
}

- (void)sendHeartbeat {
    if (!self.isAd) {
        [self.actions sendHeartbeat];
    }
    else {
        [self.actions sendAdHeartbeat];
    }
}

- (void)sendRenditionChange {
    if (!self.isAd) {
        [self.actions sendRenditionChange];
    }
    else {
        [self.actions sendAdRenditionChange];
    }
}

- (void)sendError:(NSString *)message {
    if (!self.isAd) {
        [self.actions sendError:message];
    }
    else {
        [self.actions sendAdError:message];
    }
}

#pragma mark - Transitions and states

- (BOOL)transition:(TrackerTransition)tt {
    
    AV_LOG(@">>>> TRANSITION %lu", (unsigned long)tt);
    
    switch (self.state) {
        default:
        case TrackerStateStopped: {
            return [self performTransitionInStateStopped:tt];
        }
            
        case TrackerStateStarting: {
            return [self performTransitionInStateStarting:tt];
        }
            
        case TrackerStatePaused: {
            return [self performTransitionInStatePaused:tt];
        }
            
        case TrackerStatePlaying: {
            return [self performTransitionInStatePlaying:tt];
        }
            
        case TrackerStateSeeking: {
            return [self performTransitionInStateSeeking:tt];
        }
            
        case TrackerStateBuffering: {
            return [self performTransitionInStateBuffering:tt];
        }
    }
}

- (BOOL)performTransitionInStateStopped:(TrackerTransition)tt {
    if (tt == TrackerTransitionAutoplay || tt == TrackerTransitionClickPlay) {
        [self moveState:TrackerStateStarting];
        return YES;
    }
    return NO;
}

- (BOOL)performTransitionInStateStarting:(TrackerTransition)tt {
    if (tt == TrackerTransitionFrameShown) {
        [self moveState:TrackerStatePlaying];
        return YES;
    }
    return NO;
}

- (BOOL)performTransitionInStatePlaying:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPause) {
        [self moveState:TrackerStatePaused];
        return YES;
    }
    return NO;
}

- (BOOL)performTransitionInStatePaused:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPlay) {
        [self moveState:TrackerStatePlaying];
        return YES;
    }
    return NO;
}

- (BOOL)performTransitionInStateSeeking:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndDraggingSlider) {
        [self backToState];
        return YES;
    }
    return NO;
}

- (BOOL)performTransitionInStateBuffering:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndBuffering) {
        [self backToState];
        return YES;
    }
    return NO;
}

- (void)moveState:(TrackerState)newState {
    self.state = newState;
}

- (void)moveStateAndPush:(TrackerState)newState {
    [self.stateStack push:@(self.state)];
    self.state = newState;
}

- (void)backToState {
    NSNumber *prevState = [self.stateStack pop];
    if (prevState) {
        self.state = prevState.unsignedIntegerValue;
    }
    else {
        AV_LOG(@"STATE STACK UNDERUN!");
    }
}

@end
