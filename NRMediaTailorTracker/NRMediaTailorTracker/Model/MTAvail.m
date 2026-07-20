//
//  MTAvail.m
//  NRMediaTailorTracker
//

#import "MTAvail.h"
#import "MTAd.h"

@implementation MTAvail

- (instancetype)initWithAvailId:(NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                   hasStartTime:(BOOL)hasStartTime
                     durationMs:(NSTimeInterval)durationMs
           availProgramDateTime:(NSString *)availProgramDateTime
                            ads:(NSArray<MTAd *> *)ads {
    if ((self = [super init])) {
        _availId = [availId copy];
        _startTimeMs = startTimeMs;
        _hasStartTime = hasStartTime;
        _durationMs = durationMs;
        _availProgramDateTime = [availProgramDateTime copy];
        _ads = [ads copy] ?: @[];
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSString *availId = [dict[@"availId"] isKindOfClass:[NSString class]] ? dict[@"availId"] : nil;
    NSString *availPdt = [dict[@"availProgramDateTime"] isKindOfClass:[NSString class]]
                             ? dict[@"availProgramDateTime"]
                             : nil;

    // Bug A8: track whether the JSON actually provided a start time so the
    // merger can emit MISSING_AVAIL_START instead of silently inferring.
    BOOL hasStart = [dict[@"startTimeInSeconds"] isKindOfClass:[NSNumber class]];
    NSTimeInterval startMs = hasStart ? [dict[@"startTimeInSeconds"] doubleValue] * 1000.0 : 0;

    NSTimeInterval durMs = 0;
    if ([dict[@"durationInSeconds"] isKindOfClass:[NSNumber class]]) {
        durMs = [dict[@"durationInSeconds"] doubleValue] * 1000.0;
    }

    NSMutableArray<MTAd *> *ads = [NSMutableArray array];
    id rawAds = dict[@"ads"];
    if ([rawAds isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)rawAds) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            MTAd *ad = [MTAd fromDictionary:entry availId:availId];
            if (ad) [ads addObject:ad];
        }
    }

    return [[self alloc] initWithAvailId:availId
                             startTimeMs:startMs
                            hasStartTime:hasStart
                              durationMs:durMs
                    availProgramDateTime:availPdt
                                     ads:ads];
}

- (BOOL)isNoFill {
    return self.ads.count == 0;
}

@end
