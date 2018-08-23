//
//  TrackerStateMachine.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    TrackerStateStopped = 0,
    TrackerStatePlaying,
    TrackerStatePaused,
    TrackerStateBuffering,
    TrackerStateSeeking
} TrackerState;

typedef enum {
    TrackerTransitionAutoplay = 0,
    TrackerTransitionClickPlay,
    TrackerTransitionClickPause,
    TrackerTransitionClickStop,
    TrackerTransitionBufferEmpty,
    TrackerTransitionBufferFull,
    TrackerTransitionVideoFinished,
    TrackerTransitionErrorPlaying,
    TrackerTransitionInitDraggingSlider,
    TrackerTransitionEndDraggingSlider
} TrackerTransition;

@interface TrackerStateMachine : NSObject

@property (nonatomic, readonly) TrackerState state;

- (void)transition:(TrackerTransition)tt;

@end
