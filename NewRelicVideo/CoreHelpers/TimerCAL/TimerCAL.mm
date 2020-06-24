//
//  TimerCAL.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 30/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TimerCAL.h"
#import "TrackerCore.hpp"
#import "Tracker.h"

@interface TimerCAL ()

@property (nonatomic) NSTimer *timer;
@property (nonatomic, weak) id<TrackerProtocol> tracker;

@end

@implementation TimerCAL

- (instancetype)initWithTracker:(id<TrackerProtocol>)tracker {
    if (self = [super init]) {
        self.tracker = tracker;
    }
    return self;
}

- (void)startTimerInternal:(double)timeInterval {
    
    [self abortTimerInternal];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                                  target:self
                                                selector:@selector(internalTimerHandler:)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)abortTimerInternal {
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = nil;
}

- (void)internalTimerHandler:(NSTimer *)timer {
    if (self.tracker) {
        [self.tracker sendHeartbeat];
    }
}

- (void)startTimer:(double)timeInterval {
    [self startTimerInternal:timeInterval];
}

- (void)abortTimer {
    [self abortTimerInternal];
}

@end
