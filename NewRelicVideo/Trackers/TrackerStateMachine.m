//
//  TrackerStateMachine.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TrackerStateMachine.h"
#import "NSMutableArray+Stack.h"
#import "BackendActions.h"

@interface TrackerStateMachine ()

// Public (readonly)
@property (nonatomic) TrackerState state;

// Private
@property (nonatomic) BackendActions *actions;
@property (nonatomic) NSMutableArray<NSNumber *> *stateStack;
@property (nonatomic) NSString *videoId;
@property (nonatomic) NSTimeInterval stateStartingTimestamp;

@end

@implementation TrackerStateMachine

#pragma mark - Public

- (instancetype)init {
    if (self = [super init]) {
        self.state = TrackerStateStopped;
        self.stateStack = @[].mutableCopy;
        self.actions = [[BackendActions alloc] init];
        self.stateStartingTimestamp = 0;
        self.videoId = @"";
    }
    return self;
}

- (void)transition:(TrackerTransition)tt {
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
            
        case TrackerStateBuffering: {
            [self performTransitionInStateBuffering:tt];
            break;
        }
            
        case TrackerStateSeeking: {
            [self performTransitionInStateSeeking:tt];
            break;
        }
    }
}

#pragma mark - State handlers

- (void)performTransitionInStateStopped:(TrackerTransition)tt {
    if (tt == TrackerTransitionAutoplay || tt == TrackerTransitionClickPlay) {
        self.stateStartingTimestamp  = [self timestamp];
        // TODO: generate VIDEO ID and pass it to BackendActions instance
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
    // TODO
}

- (void)performTransitionInStatePaused:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStateBuffering:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStateSeeking:(TrackerTransition)tt {
    // TODO
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
}

- (NSTimeInterval)timestamp {
    return [[NSDate date] timeIntervalSince1970];
}

@end
