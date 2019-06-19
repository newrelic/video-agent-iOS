//
//  BackgroundEvents.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 19/06/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import "BackgroundEvents.h"
#import "Vars.h"

#define PLIST_FILE  @"backgroundEvents"

@interface BackgroundEvents ()

@property (nonatomic) NSMutableArray<NSMutableDictionary *> *backgroundEvents;

@end

@implementation BackgroundEvents

+ (instancetype)sharedInstance {
    static BackgroundEvents *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BackgroundEvents alloc] init];
        instance.backgroundEvents = @[].mutableCopy;
    });
    return instance;
}

- (void)loadEvents {
    self.backgroundEvents = [Vars readPlist:PLIST_FILE];
}

- (void)addEvent:(NSMutableDictionary *)attributes {
    [self.backgroundEvents addObject:attributes];
    [Vars writeArray:self.backgroundEvents toPlist:PLIST_FILE];
}

- (void)flushEvents {
    [self.backgroundEvents removeAllObjects];
    [Vars removePlist:PLIST_FILE];
}

- (void)traverseEvents:(void (^)(NSMutableDictionary *dict))block {
    for (NSMutableDictionary *attributes in self.backgroundEvents) {
        block(attributes);
    }
}

- (NSString *)description {
    return [@"<BackgroundEvents> attributes = %@" stringByAppendingFormat:@"%@", self.backgroundEvents];
}

@end
