//
//  TrackerAutomat.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TrackerAutomat.h"
#import "NSMutableArray+Stack.h"
#import "BackendActions.h"

@interface TrackerAutomat ()

@property (nonatomic) TrackerState state;
@property (nonatomic) BackendActions *actions;
@property (nonatomic) NSMutableArray<NSNumber *> *stateStack;

@end

@implementation TrackerAutomat

#pragma mark - Public

- (instancetype)init {
    if (self = [super init]) {
        self.state = TrackerStateStopped;
        self.stateStack = @[].mutableCopy;
        self.actions = [[BackendActions alloc] init];
    }
    return self;
}

- (void)transition:(TrackerTransition)tt {
    
    AV_LOG(@">>>> TRANSITION %lu", (unsigned long)tt);
    
    if (![self handleStateIndependantTransition:tt]) {
        switch (self.state) {
            default:
            case TrackerStateStopped: {
                [self performTransitionInStateStopped:tt];
                break;
            }
                
            case TrackerStateStarting: {
                [self performTransitionInStateStarting:tt];
                break;
            }
                
            case TrackerStatePaused: {
                [self performTransitionInStatePaused:tt];
                break;
            }
                
            case TrackerStatePlaying: {
                [self performTransitionInStatePlaying:tt];
                break;
            }
            
            case TrackerStateSeeking: {
                [self performTransitionInStateSeeking:tt];
                break;
            }
                
            case TrackerStateBuffering: {
                [self performTransitionInStateBuffering:tt];
                break;
            }
        }
    }
}

- (void)force:(TrackerState)state {
    [self.stateStack removeAllObjects];
    [self moveState:state];
}

#pragma mark - State handlers

// Handle transitions that can happen at any time, independently of current state
- (BOOL)handleStateIndependantTransition:(TrackerTransition)tt {
    switch (tt) {
        case TrackerTransitionHeartbeat: {
            [self sendHeartbeat];
            return YES;
        }
            
        case TrackerTransitionRenditionChanged: {
            [self sendRenditionChange];
            return YES;
        }
            
        case TrackerTransitionInitDraggingSlider: {
            [self sendSeekStart];
            [self moveStateAndPush:TrackerStateSeeking];
            return YES;
        }
            
        case TrackerTransitionInitBuffering: {
            [self sendBufferStart];
            [self moveStateAndPush:TrackerStateBuffering];
            return YES;
        }
            
        case TrackerTransitionErrorPlaying: {
            [self sendError];
            return YES;
        }
        
        // NOTE: this should happend only while playing or seeking, but the event is too important and strange things could happen in the state machine (specially with AVPlayer).
        case TrackerTransitionVideoFinished: {
            [self sendEnd];
            [self endState];
            return YES;
        }
            
        default:
            return NO;
    }
}

- (void)performTransitionInStateStopped:(TrackerTransition)tt {
    if (tt == TrackerTransitionAutoplay || tt == TrackerTransitionClickPlay) {
        [self sendRequest];
        [self moveState:TrackerStateStarting];
    }
}

- (void)performTransitionInStateStarting:(TrackerTransition)tt {
    if (tt == TrackerTransitionFrameShown) {
        [self sendStart];
        [self moveState:TrackerStatePlaying];
    }
}

- (void)performTransitionInStatePlaying:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPause) {
        [self sendPause];
        [self moveState:TrackerStatePaused];
    }
}

- (void)performTransitionInStatePaused:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPlay) {
        [self sendResume];
        [self moveState:TrackerStatePlaying];
    }
}

- (void)performTransitionInStateSeeking:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndDraggingSlider) {
        [self sendSeekEnd];
        [self backToState];
    }
}

- (void)performTransitionInStateBuffering:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndBuffering) {
        [self sendBufferEnd];
        [self backToState];
    }
}

#pragma mark - Senders

- (void)sendRequest {
    if (!self.isAd) {
        [self.actions sendRequest];
    }
    else {
        [self.actions sendAdRequest];
    }
}

- (void)sendStart {
    if (!self.isAd) {
        [self.actions sendStart];
    }
    else {
        [self.actions sendAdStart];
    }
}

- (void)sendEnd {
    if (!self.isAd) {
        [self.actions sendEnd];
    }
    else {
        [self.actions sendAdEnd];
    }
}

- (void)sendPause {
    if (!self.isAd) {
        [self.actions sendPause];
    }
    else {
        [self.actions sendAdPause];
    }
}

- (void)sendResume {
    if (!self.isAd) {
        [self.actions sendResume];
    }
    else {
        [self.actions sendAdResume];
    }
}

- (void)sendSeekStart {
    if (!self.isAd) {
        [self.actions sendSeekStart];
    }
    else {
        [self.actions sendAdSeekStart];
    }
}

- (void)sendSeekEnd {
    if (!self.isAd) {
        [self.actions sendSeekEnd];
    }
    else {
        [self.actions sendAdSeekEnd];
    }
}

- (void)sendBufferStart {
    if (!self.isAd) {
        [self.actions sendBufferStart];
    }
    else {
        [self.actions sendAdBufferStart];
    }
}

- (void)sendBufferEnd {
    if (!self.isAd) {
        [self.actions sendBufferEnd];
    }
    else {
        [self.actions sendAdBufferEnd];
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

- (void)sendError {
    if (!self.isAd) {
        [self.actions sendError:nil];
    }
    else {
        [self.actions sendAdError:nil];
    }
}

#pragma mark - Utils

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

- (void)endState {
    [self.stateStack removeAllObjects];
    [self moveState:TrackerStateStopped];
}

@end
