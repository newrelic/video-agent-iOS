//
//  VideoTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "VideoTracker.h"
#import "TrackerAutomat.h"

@interface VideoTracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@implementation VideoTracker

- (instancetype)init {
    if (self = [super init]) {
        self.automat = [[TrackerAutomat alloc] init];
    }
    return self;
}

#pragma mark - To be overwritten by subclass

- (void)reset {}

- (void)setup {}

#pragma mark - To be called by subclass

- (void)sendRequest {
    [self.automat transition:TrackerTransitionClickPlay];
}

- (void)sendStart {
    [self.automat transition:TrackerTransitionFrameShown];
}

- (void)sendEnd {
    [self.automat transition:TrackerTransitionVideoFinished];
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
}

@end
