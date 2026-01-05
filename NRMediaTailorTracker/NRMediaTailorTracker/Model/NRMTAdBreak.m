//
//  NRMTAdBreak.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTAdBreak.h"
#import "NRMTAdPod.h"

@implementation NRMTAdBreak

- (instancetype)init {
    if (self = [super init]) {
        _startTime = 0;
        _duration = 0;
        _endTime = 0;
        _adPosition = NRMTAdPositionUnknown;
        _source = NRMTAdSourceManifestCue;
        _confirmedByTracking = NO;
        _hasFiredStart = NO;
        _hasFiredEnd = NO;
        _hasFiredAdStart = NO;
        _hasFiredQ1 = NO;
        _hasFiredQ2 = NO;
        _hasFiredQ3 = NO;
        _pods = [NSMutableArray array];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NRMTAdBreak: %p, id=%@, startTime=%.2f, duration=%.2f, pods=%lu, confirmed=%@>",
            self, self.breakId, self.startTime, self.duration, (unsigned long)self.pods.count,
            self.confirmedByTracking ? @"YES" : @"NO"];
}

@end
