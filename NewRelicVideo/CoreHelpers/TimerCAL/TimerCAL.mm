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
@property (nonatomic) id<TrackerProtocol> tracker;

@end

@implementation TimerCAL

+ (instancetype)sharedInstance {
    static TimerCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TimerCAL alloc] init];
        sharedInstance.tracker = nil;
    });
    return sharedInstance;
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

- (void)startTimer:(id<TrackerProtocol>)tracker time:(double)timeInterval {
    [TimerCAL sharedInstance].tracker = tracker;
    [[TimerCAL sharedInstance] startTimerInternal:timeInterval];
}

- (void)abortTimer:(id<TrackerProtocol>)tracker {
    [[TimerCAL sharedInstance] abortTimerInternal];
    [TimerCAL sharedInstance].tracker = nil;
}

@end
