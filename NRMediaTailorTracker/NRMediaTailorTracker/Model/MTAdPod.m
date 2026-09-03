//
//  MTAdPod.m
//  NRMediaTailorTracker
//

#import "MTAdPod.h"

@implementation MTAdPod

- (instancetype)initWithStartTimeMs:(NSTimeInterval)startTimeMs
                         durationMs:(NSTimeInterval)durationMs {
    if ((self = [super init])) {
        _startTimeMs = startTimeMs;
        _durationMs = durationMs;
    }
    return self;
}

- (NSTimeInterval)endTimeMs {
    return self.startTimeMs + self.durationMs;
}

- (BOOL)containsPositionMs:(NSTimeInterval)positionMs {
    return positionMs >= self.startTimeMs && positionMs < self.endTimeMs;
}

@end
