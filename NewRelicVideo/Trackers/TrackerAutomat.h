//
//  TrackerAutomat.h
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
    TrackerTransitionInitBuffering,
    TrackerTransitionEndBuffering,
    TrackerTransitionVideoFinished,
    TrackerTransitionErrorPlaying,
    TrackerTransitionInitDraggingSlider,
    TrackerTransitionEndDraggingSlider,
    // TODO: Those two underneath not used yet
    TrackerTransitionHeartbeat,
    TrackerTransitionRenditionChanged
};

@interface TrackerAutomat : NSObject

@property (nonatomic, readonly) TrackerState state;

- (void)transition:(TrackerTransition)tt;
- (void)force:(TrackerState)state;

@end
