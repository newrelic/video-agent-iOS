//
//  MTManifestParseResult.m
//  NRMediaTailorTracker
//

#import "MTManifestParseResult.h"

@implementation MTManifestParseResult

- (instancetype)initWithTrackingURL:(NSURL *)trackingURL
                             breaks:(NSArray *)breaks {
    if ((self = [super init])) {
        _trackingURL = [trackingURL copy];
        _breaks = [breaks copy] ?: @[];
    }
    return self;
}

+ (instancetype)empty {
    return [[self alloc] initWithTrackingURL:nil breaks:@[]];
}

@end
