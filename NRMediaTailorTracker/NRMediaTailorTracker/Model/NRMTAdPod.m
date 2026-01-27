//
//  NRMTAdPod.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTAdPod.h"

@implementation NRMTAdPod

- (instancetype)init {
    if (self = [super init]) {
        _startTime = 0;
        _duration = 0;
        _endTime = 0;
        _trackingStartTime = 0;
        _trackingDuration = 0;
        _hasFiredStart = NO;
        _hasFiredQ1 = NO;
        _hasFiredQ2 = NO;
        _hasFiredQ3 = NO;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NRMTAdPod: %p, startTime=%.2f, duration=%.2f, title=%@, creativeId=%@>",
            self, self.startTime, self.duration, self.title ?: @"nil", self.creativeId ?: @"nil"];
}

@end
