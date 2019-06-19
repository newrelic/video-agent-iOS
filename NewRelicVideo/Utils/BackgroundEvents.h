//
//  BackgroundEvents.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 19/06/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BackgroundEvents : NSObject

+ (instancetype)sharedInstance;
- (void)loadEvents;
- (void)addEvent:(NSMutableDictionary *)attributes;
- (void)flushEvents;
- (void)traverseEvents:(void (^)(NSMutableDictionary *dict))block;

@end
