//
//  MTTrackingEvent.m
//  NRMediaTailorTracker
//

#import "MTTrackingEvent.h"
#import "MTStringHelpers.h"

@implementation MTTrackingEvent

- (instancetype)initWithEventType:(NSString *)eventType
                          eventId:(NSString *)eventId
              relativeToAdStartMs:(NSTimeInterval)relativeToAdStartMs
                       beaconUrls:(NSArray<NSURL *> *)beaconUrls
             eventProgramDateTime:(NSString *)eventProgramDateTime {
    if ((self = [super init])) {
        _eventType = [eventType copy];
        _eventId = [eventId copy];
        _relativeToAdStartMs = relativeToAdStartMs;
        _beaconUrls = [beaconUrls copy] ?: @[];
        _eventProgramDateTime = [eventProgramDateTime copy];
    }
    return self;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSString *eventType = MTStringOrNil(dict, @"eventType");
    NSString *eventId = MTStringOrNil(dict, @"eventId");
    NSString *eventProgramDateTime = MTStringOrNil(dict, @"eventProgramDateTime");

    // `startTimeInSeconds` here is RELATIVE TO AD START (not manifest time).
    NSTimeInterval relativeMs = 0;
    id seconds = dict[@"startTimeInSeconds"];
    if ([seconds isKindOfClass:[NSNumber class]]) {
        relativeMs = [(NSNumber *)seconds doubleValue] * 1000.0;
    }

    NSMutableArray<NSURL *> *urls = [NSMutableArray array];
    id beaconUrlsRaw = dict[@"beaconUrls"];
    if ([beaconUrlsRaw isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)beaconUrlsRaw) {
            if ([entry isKindOfClass:[NSString class]]) {
                NSURL *u = [NSURL URLWithString:entry];
                if (u) [urls addObject:u];
            }
        }
    }

    return [[self alloc] initWithEventType:eventType
                                   eventId:eventId
                       relativeToAdStartMs:relativeMs
                                beaconUrls:urls
                      eventProgramDateTime:eventProgramDateTime];
}

@end
