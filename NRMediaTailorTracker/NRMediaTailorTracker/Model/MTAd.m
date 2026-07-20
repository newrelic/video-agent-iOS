//
//  MTAd.m
//  NRMediaTailorTracker
//

#import "MTAd.h"
#import "MTTrackingEvent.h"

@implementation MTAd

- (instancetype)initWithCreativeId:(NSString *)creativeId
                              adId:(NSString *)adId
                           availId:(NSString *)availId
                           adTitle:(NSString *)adTitle
                          adSystem:(NSString *)adSystem
                  creativeSequence:(NSString *)creativeSequence
                          vastAdId:(NSString *)vastAdId
                        skipOffset:(NSString *)skipOffset
                 adProgramDateTime:(NSString *)adProgramDateTime
                       startTimeMs:(NSTimeInterval)startTimeMs
                        durationMs:(NSTimeInterval)durationMs
                    trackingEvents:(NSArray<MTTrackingEvent *> *)trackingEvents {
    if ((self = [super init])) {
        _creativeId = [creativeId copy];
        _adId = [adId copy];
        _availId = [availId copy];
        _adTitle = [adTitle copy];
        _adSystem = [adSystem copy];
        _creativeSequence = [creativeSequence copy];
        _vastAdId = [vastAdId copy];
        _skipOffset = [skipOffset copy];
        _adProgramDateTime = [adProgramDateTime copy];
        _startTimeMs = startTimeMs;
        _durationMs = durationMs;
        _trackingEvents = [trackingEvents copy] ?: @[];
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict availId:(NSString *)availId {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSString *(^str)(id) = ^NSString *(id v) {
        return [v isKindOfClass:[NSString class]] ? (NSString *)v : nil;
    };

    NSString *creativeId = str(dict[@"creativeId"]);
    NSString *adId = str(dict[@"adId"]);
    NSString *adTitle = str(dict[@"adTitle"]);
    NSString *adSystem = str(dict[@"adSystem"]);
    NSString *creativeSequence = str(dict[@"creativeSequence"]);
    NSString *vastAdId = str(dict[@"vastAdId"]);
    NSString *skipOffset = str(dict[@"skipOffset"]);
    NSString *adProgramDateTime = str(dict[@"adProgramDateTime"]);

    NSTimeInterval startMs = 0;
    NSTimeInterval durMs = 0;
    id startSec = dict[@"startTimeInSeconds"];
    id durSec = dict[@"durationInSeconds"];
    if ([startSec isKindOfClass:[NSNumber class]]) startMs = [(NSNumber *)startSec doubleValue] * 1000.0;
    if ([durSec isKindOfClass:[NSNumber class]]) durMs = [(NSNumber *)durSec doubleValue] * 1000.0;

    NSMutableArray<MTTrackingEvent *> *events = [NSMutableArray array];
    id rawEvents = dict[@"trackingEvents"];
    if ([rawEvents isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)rawEvents) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            MTTrackingEvent *ev = [MTTrackingEvent fromDictionary:entry];
            if (ev) [events addObject:ev];
        }
    }

    return [[self alloc] initWithCreativeId:creativeId
                                       adId:adId
                                    availId:availId
                                    adTitle:adTitle
                                   adSystem:adSystem
                           creativeSequence:creativeSequence
                                   vastAdId:vastAdId
                                 skipOffset:skipOffset
                          adProgramDateTime:adProgramDateTime
                                startTimeMs:startMs
                                 durationMs:durMs
                             trackingEvents:events];
}

- (NSString *)primaryKey {
    // Bug B2: creativeId is the canonical identity. Fall back to composite.
    if (self.creativeId.length > 0) {
        return self.creativeId;
    }
    NSString *avail = self.availId.length > 0 ? self.availId : @"";
    NSString *ad = self.adId.length > 0 ? self.adId : @"";
    return [NSString stringWithFormat:@"%@:%@", avail, ad];
}

- (BOOL)isBumper {
    NSString *needle = @"bumper";
    NSStringCompareOptions opt = NSCaseInsensitiveSearch;
    if (self.adSystem && [self.adSystem rangeOfString:needle options:opt].location != NSNotFound) return YES;
    if (self.adTitle && [self.adTitle rangeOfString:needle options:opt].location != NSNotFound) return YES;
    if (self.adId && [self.adId rangeOfString:needle options:opt].location != NSNotFound) return YES;
    return NO;
}

@end
