//
//  TimerCAL.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 30/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TimerCAL.h"
#import "TrackerCore.hpp"

@interface TimerCAL ()

@property (nonatomic) NSTimer *timer;
@property (nonatomic) TrackerCore *trackerCore;

@end

@implementation TimerCAL

+ (instancetype)sharedInstance {
    static TimerCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TimerCAL alloc] init];
        sharedInstance.trackerCore = NULL;
    });
    return sharedInstance;
}

- (void)startTimerInternal {
    if (self.timer) {
        [self abortTimerInternal];
    }
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                  target:self
                                                selector:@selector(internalTimerHandler:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)abortTimerInternal {
    
}

- (void)internalTimerHandler:(NSTimer *)timer {
    if (self.trackerCore) {
        self.trackerCore->trackerTimeEvent();
    }
}

void startTimer(TrackerCore *trackerCore) {
    [TimerCAL sharedInstance].trackerCore = trackerCore;
    [[TimerCAL sharedInstance] startTimerInternal];
}

void abortTimer() {
    [[TimerCAL sharedInstance] abortTimerInternal];
    [TimerCAL sharedInstance].trackerCore = NULL;
}

@end
