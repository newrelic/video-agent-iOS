//
//  MergedSchedule.m
//  NRMediaTailorTracker
//

#import "MergedSchedule.h"

@implementation MTMergedScheduleError

- (instancetype)initWithBreak:(MTAdBreak *)adBreak
                    errorCode:(MTAdErrorCode)errorCode
                      message:(NSString *)message {
    if ((self = [super init])) {
        _adBreak = adBreak;
        _errorCode = errorCode;
        _message = [message copy];
    }
    return self;
}

@end

@implementation MergedSchedule

- (instancetype)initWithBreaks:(NSArray<MTAdBreak *> *)breaks
                 pendingErrors:(NSArray<MTMergedScheduleError *> *)pendingErrors {
    if ((self = [super init])) {
        _breaks = [breaks copy] ?: @[];
        _pendingErrors = [pendingErrors copy] ?: @[];
    }
    return self;
}

+ (instancetype)empty {
    return [[self alloc] initWithBreaks:@[] pendingErrors:@[]];
}

@end
