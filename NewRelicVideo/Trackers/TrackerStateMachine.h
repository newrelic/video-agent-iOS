//
//  TrackerStateMachine.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, TrackerState) {
    TrackerStateStopped = 0,
    TrackerStateStarting,
    TrackerStatePlaying,
    TrackerStatePaused,
    TrackerStateBuffering,
    TrackerStateSeeking
};

typedef NS_ENUM(NSUInteger, TrackerTransition) {
    TrackerTransitionAutoplay = 0,
    TrackerTransitionClickPlay,
    TrackerTransitionClickPause,
    TrackerTransitionClickStop,
    TrackerTransitionFrameShown,
    TrackerTransitionBufferEmpty,
    TrackerTransitionBufferFull,
    TrackerTransitionVideoFinished,
    TrackerTransitionErrorPlaying,
    TrackerTransitionInitDraggingSlider,
    TrackerTransitionEndDraggingSlider,
    TrackerTransitionHeartbeat,
    TrackerTransitionRenditionChanged
};

@interface TrackerStateMachine : NSObject

@property (nonatomic, readonly) TrackerState state;

- (void)transition:(TrackerTransition)tt;

@end
