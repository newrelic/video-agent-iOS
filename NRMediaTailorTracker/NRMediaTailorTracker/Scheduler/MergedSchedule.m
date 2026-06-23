//
//  MergedSchedule.m
//  NRMediaTailorTracker
//

#import "MergedSchedule.h"
#import "MTAdBreak.h"

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

        NSUInteger mismatch = 0;
        for (MTAdBreak *br in _breaks) {
            if (br.podCountMismatch) mismatch++;
        }
        _podCountMismatchCount = mismatch;

        NSUInteger warnings = 0;
        for (MTMergedScheduleError *e in _pendingErrors) {
            if (e.errorCode == MTAdErrorCodeMissingAvailStart) warnings++;
        }
        _dataIntegrityWarningCount = warnings;
    }
    return self;
}

+ (instancetype)empty {
    return [[self alloc] initWithBreaks:@[] pendingErrors:@[]];
}

@end
