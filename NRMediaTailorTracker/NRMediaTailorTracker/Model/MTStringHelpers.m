//
//  MTStringHelpers.m
//  NRMediaTailorTracker
//

#import "MTStringHelpers.h"

NSString * _Nullable MTStringOrNil(NSDictionary * _Nullable dict, NSString *key) {
    id value = dict[key];
    return [value isKindOfClass:[NSString class]] ? (NSString *)value : nil;
}
