//
//  NRTrackerPair.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import "NRTrackerPair.h"
#import "NRTracker.h"

@interface NRTrackerPair ()

@property (nonatomic) NSArray<NRTracker *> *pair;

@end

@implementation NRTrackerPair

- (instancetype)initWithFirst:(nullable NRTracker *)first second:(nullable NRTracker *)second {
    if (self = [super init]) {
        if (first == nil) {
            first = (NRTracker *)[NSNull null];
        }
        if (second == nil) {
            second = (NRTracker *)[NSNull null];
        }
        self.pair = @[first, second];
    }
    return self;
}

- (NRTracker *)first {
    return self.pair[0];
}

- (NRTracker *)second {
    return self.pair[1];
}

@end
