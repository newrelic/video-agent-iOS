//
//  MTTrackingResponse.m
//  NRMediaTailorTracker
//

#import "MTTrackingResponse.h"
#import "MTAvail.h"
#import "MTNonLinearAvail.h"
#import "MTTrackingError.h"

@implementation MTTrackingResponse

- (instancetype)initWithAvails:(NSArray<MTAvail *> *)avails
               nonLinearAvails:(NSArray<MTNonLinearAvail *> *)nonLinearAvails
                     nextToken:(NSString *)nextToken {
    if ((self = [super init])) {
        _avails = [avails copy] ?: @[];
        _nonLinearAvails = [nonLinearAvails copy] ?: @[];
        _nextToken = [nextToken copy];
    }
    return self;
}

+ (instancetype)fromJSONData:(NSData *)data error:(NSError **)error {
    if (data.length == 0) {
        if (error) *error = [NSError errorWithDomain:MTTrackingErrorDomain
                                                 code:MTTrackingErrorCodeInvalidResponse
                                             userInfo:@{NSLocalizedDescriptionKey: @"empty body"}];
        return nil;
    }
    NSError *jsonError = nil;
    id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError) {
        if (error) *error = jsonError;
        return nil;
    }
    if (![parsed isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [NSError errorWithDomain:MTTrackingErrorDomain
                                                 code:MTTrackingErrorCodeParseFailed
                                             userInfo:@{NSLocalizedDescriptionKey: @"top-level not object"}];
        return nil;
    }
    return [self fromDictionary:parsed];
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    NSMutableArray<MTAvail *> *avails = [NSMutableArray array];
    id rawAvails = dict[@"avails"];
    if ([rawAvails isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)rawAvails) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            MTAvail *a = [MTAvail fromDictionary:entry];
            if (a) [avails addObject:a];
        }
    }

    NSMutableArray<MTNonLinearAvail *> *nonLinear = [NSMutableArray array];
    id rawNonLinear = dict[@"nonLinearAvails"];
    if ([rawNonLinear isKindOfClass:[NSArray class]]) {
        for (id entry in (NSArray *)rawNonLinear) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            MTNonLinearAvail *nl = [MTNonLinearAvail fromDictionary:entry];
            if (nl) [nonLinear addObject:nl];
        }
    }

    NSString *nextToken = nil;
    id rawToken = dict[@"nextToken"];
    if ([rawToken isKindOfClass:[NSString class]] && [(NSString *)rawToken length] > 0) {
        nextToken = rawToken;
    }

    return [[self alloc] initWithAvails:avails nonLinearAvails:nonLinear nextToken:nextToken];
}

@end
