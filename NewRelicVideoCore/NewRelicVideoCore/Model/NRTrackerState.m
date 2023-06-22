//
//  NRTrackerState.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 14/12/2020.
//

#import "NRTrackerState.h"

@interface NRTrackerState ()

@property (nonatomic) BOOL isPlayerReady;
@property (nonatomic) BOOL isRequested;
@property (nonatomic) BOOL isStarted;
@property (nonatomic) BOOL isPlaying;
@property (nonatomic) BOOL isPaused;
@property (nonatomic) BOOL isSeeking;
@property (nonatomic) BOOL isUserSeeking;
@property (nonatomic) BOOL isBuffering;
@property (nonatomic) BOOL isAd;
@property (nonatomic) BOOL isAdBreak;

@end

@implementation NRTrackerState

- (instancetype)init {
    if (self = [super init]) {
        [self reset];
    }
    return self;
}

- (void)reset {
    self.isPlayerReady = NO;
    self.isRequested = NO;
    self.isStarted = NO;
    self.isPlaying = NO;
    self.isPaused = NO;
    self.isSeeking = NO;
    self.isUserSeeking = NO;
    self.isBuffering = NO;
    self.isAd = NO;
    self.isAdBreak = NO;
}

- (void)startSeekingEvent {
    self.isUserSeeking = true;
}

- (BOOL)goPlayerReady {
    if (!self.isPlayerReady) {
        self.isPlayerReady = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goRequest {
    if (!self.isRequested) {
        self.isRequested = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goStart {
    if (self.isRequested && !self.isStarted) {
        self.isStarted = true;
        self.isPlaying = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goEnd {
    if (self.isRequested) {
        self.isRequested = NO;
        self.isStarted = NO;
        self.isPlaying = NO;
        self.isPaused = NO;
        self.isSeeking = NO;
        self.isUserSeeking = NO;
        self.isBuffering = NO;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goPause {
    if (self.isStarted && !self.isPaused) {
        self.isPaused = true;
        self.isPlaying = false;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goResume {
    if (self.isStarted && self.isPaused) {
        self.isPaused = false;
        self.isPlaying = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goBufferStart {
    if (self.isRequested && !self.isBuffering) {
        self.isBuffering = true;
        self.isPlaying = false;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goBufferEnd {
    if (self.isRequested && self.isBuffering) {
        self.isBuffering = false;
        self.isPlaying = true;
        return true;
    } else {
        return false;
    }
}

- (BOOL)goSeekStart {
    if (self.isStarted && !self.isSeeking) {
        self.isSeeking = true;
        self.isPlaying = false;
        return true;
    } else {
        return false;
    }
}

- (BOOL)goSeekEnd {
    if (self.isStarted && self.isSeeking) {
        self.isSeeking = false;
        self.isUserSeeking = false;
        self.isPlaying = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goAdBreakStart {
    if (!self.isAdBreak) {
        self.isAdBreak = true;
        return true;
    }
    else {
        return false;
    }
}

- (BOOL)goAdBreakEnd {
    if (self.isAdBreak) {
        self.isRequested = false;
        self.isAdBreak = false;
        return true;
    } else {
        return false;
    }
}

@end
