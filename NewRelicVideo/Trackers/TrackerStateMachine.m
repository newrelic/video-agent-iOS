//
//  TrackerStateMachine.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TrackerStateMachine.h"

@interface TrackerStateMachine ()

@property (nonatomic) TrackerState state;
@property (nonatomic) TrackerState prevState;

@end

@implementation TrackerStateMachine

- (instancetype)init {
    if (self = [super init]) {
        self.state = TrackerStateStopped;
        self.prevState = TrackerStateStopped;
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

- (void)performTransitionInStateStopped:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStatePaused:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStatePlaying:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStateBuffering:(TrackerTransition)tt {
    // TODO
}

- (void)performTransitionInStateSeeking:(TrackerTransition)tt {
    // TODO
}

@end
