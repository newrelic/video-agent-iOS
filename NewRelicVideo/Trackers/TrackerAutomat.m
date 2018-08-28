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
@property (nonatomic) NSTimeInterval stateStartingTimestamp;

@end

@implementation TrackerAutomat

#pragma mark - Public

- (instancetype)init {
    if (self = [super init]) {
        self.state = TrackerStateStopped;
        self.stateStack = @[].mutableCopy;
        self.actions = [[BackendActions alloc] init];
        self.stateStartingTimestamp = 0;
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
            [self.actions sendHeartbeat];
            return YES;
        }
            
        case TrackerTransitionRenditionChanged: {
            [self.actions sendRenditionChange];
            return YES;
        }
            
        case TrackerTransitionInitDraggingSlider: {
            [self.actions sendSeekStart];
            [self moveStateAndPush:TrackerStateSeeking];
            return YES;
        }
            
        case TrackerTransitionInitBuffering: {
            [self.actions sendBufferStart];
            [self moveStateAndPush:TrackerStateBuffering];
            return YES;
        }
            
        case TrackerTransitionErrorPlaying: {
            [self.actions sendError];
            [self endState];
            return YES;
        }
            
        case TrackerTransitionVideoFinished: {
            [self.actions sendEnd];
            [self endState];
            return YES;
        }
            
        default:
            return NO;
    }
}

- (void)performTransitionInStateStopped:(TrackerTransition)tt {
    if (tt == TrackerTransitionAutoplay || tt == TrackerTransitionClickPlay) {
        self.stateStartingTimestamp  = [self timestamp];
        [self.actions sendRequest];
        [self moveState:TrackerStateStarting];
    }
}

- (void)performTransitionInStateStarting:(TrackerTransition)tt {
    if (tt == TrackerTransitionFrameShown) {
        [self.actions sendStart:self.timestamp - self.stateStartingTimestamp];
        [self moveState:TrackerStatePlaying];
    }
}

- (void)performTransitionInStatePlaying:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPause) {
        [self.actions sendPause];
        [self moveState:TrackerStatePaused];
    }
}

- (void)performTransitionInStatePaused:(TrackerTransition)tt {
    if (tt == TrackerTransitionClickPlay) {
        [self.actions sendResume];
        [self moveState:TrackerStatePlaying];
    }
}

- (void)performTransitionInStateSeeking:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndDraggingSlider) {
        [self.actions sendSeekEnd];
        [self backToState];
    }
}

- (void)performTransitionInStateBuffering:(TrackerTransition)tt {
    if (tt == TrackerTransitionEndBuffering) {
        [self.actions sendBufferEnd];
        [self backToState];
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

- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSince1970];
}

@end
