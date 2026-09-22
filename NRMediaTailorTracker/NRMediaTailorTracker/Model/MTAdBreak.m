//
//  MTAdBreak.m
//  NRMediaTailorTracker
//

#import "MTAdBreak.h"
#import "MTAdPod.h"

@implementation MTAdBreak

- (instancetype)initWithAvailId:(NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                     durationMs:(NSTimeInterval)durationMs {
    if ((self = [super init])) {
        _availId = [availId copy];
        _startTimeMs = startTimeMs;
        _durationMs = durationMs;
        _pods = [NSMutableArray array];
    }
    return self;
}

- (NSTimeInterval)endTimeMs {
    return self.startTimeMs + self.durationMs;
}

- (BOOL)containsPositionMs:(NSTimeInterval)positionMs {
    return positionMs >= self.startTimeMs && positionMs < self.endTimeMs;
}

- (MTAdPod *)activePodForPositionMs:(NSTimeInterval)positionMs {
    for (MTAdPod *pod in self.pods) {
        if ([pod containsPositionMs:positionMs]) return pod;
    }
    return nil;
}

@end
