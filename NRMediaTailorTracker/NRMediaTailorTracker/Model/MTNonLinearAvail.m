//
//  MTNonLinearAvail.m
//  NRMediaTailorTracker
//

#import "MTNonLinearAvail.h"

@implementation MTNonLinearAvail

- (instancetype)initWithAvailId:(NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                     durationMs:(NSTimeInterval)durationMs
                     rawPayload:(NSDictionary<NSString *, id> *)rawPayload {
    if ((self = [super init])) {
        _availId = [availId copy];
        _startTimeMs = startTimeMs;
        _durationMs = durationMs;
        _rawPayload = [rawPayload copy] ?: @{};
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSString *availId = [dict[@"availId"] isKindOfClass:[NSString class]] ? dict[@"availId"] : nil;

    NSTimeInterval startMs = 0;
    NSTimeInterval durMs = 0;
    if ([dict[@"startTimeInSeconds"] isKindOfClass:[NSNumber class]]) {
        startMs = [dict[@"startTimeInSeconds"] doubleValue] * 1000.0;
    }
    if ([dict[@"durationInSeconds"] isKindOfClass:[NSNumber class]]) {
        durMs = [dict[@"durationInSeconds"] doubleValue] * 1000.0;
    }

    return [[self alloc] initWithAvailId:availId
                             startTimeMs:startMs
                              durationMs:durMs
                              rawPayload:dict];
}

@end
