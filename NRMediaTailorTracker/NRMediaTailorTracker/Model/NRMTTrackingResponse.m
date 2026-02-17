//
//  NRMTTrackingResponse.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTTrackingResponse.h"

@implementation NRMTTrackingAd

- (nullable instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        _adId = dict[@"adId"] ?: @"";
        _adTitle = dict[@"adTitle"] ?: @"";
        _startTimeInSeconds = [dict[@"startTimeInSeconds"] doubleValue];
        _durationInSeconds = [dict[@"durationInSeconds"] doubleValue];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NRMTTrackingAd: %p, id=%@, title=%@, start=%.2f, duration=%.2f>",
            self, self.adId, self.adTitle, self.startTimeInSeconds, self.durationInSeconds];
}

@end

@implementation NRMTTrackingAvail

- (nullable instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        _availId = dict[@"availId"] ?: @"";
        _durationInSeconds = [dict[@"durationInSeconds"] doubleValue];
        _startTimeInSeconds = [dict[@"startTimeInSeconds"] doubleValue];

        NSArray *adsArray = dict[@"ads"];
        if ([adsArray isKindOfClass:[NSArray class]]) {
            NSMutableArray<NRMTTrackingAd *> *ads = [NSMutableArray array];
            for (NSDictionary *adDict in adsArray) {
                NRMTTrackingAd *ad = [[NRMTTrackingAd alloc] initWithDictionary:adDict];
                if (ad) {
                    [ads addObject:ad];
                }
            }
            _ads = [ads copy];
        } else {
            _ads = @[];
        }
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NRMTTrackingAvail: %p, id=%@, start=%.2f, duration=%.2f, ads=%lu>",
            self, self.availId, self.startTimeInSeconds, self.durationInSeconds, (unsigned long)self.ads.count];
}

@end

@implementation NRMTTrackingResponse

- (nullable instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        if (![dict isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        NSArray *availsArray = dict[@"avails"];
        if ([availsArray isKindOfClass:[NSArray class]]) {
            NSMutableArray<NRMTTrackingAvail *> *avails = [NSMutableArray array];
            for (NSDictionary *availDict in availsArray) {
                NRMTTrackingAvail *avail = [[NRMTTrackingAvail alloc] initWithDictionary:availDict];
                if (avail) {
                    [avails addObject:avail];
                }
            }
            _avails = [avails copy];
        } else {
            _avails = @[];
        }
    }
    return self;
}

+ (nullable instancetype)parseFromData:(NSData *)data error:(NSError **)error {
    if (!data) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"No data to parse"}];
        }
        return nil;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                         options:0
                                                           error:error];
    if (!json) {
        return nil;
    }

    return [[self alloc] initWithDictionary:json];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<NRMTTrackingResponse: %p, avails=%lu>",
            self, (unsigned long)self.avails.count];
}

@end
