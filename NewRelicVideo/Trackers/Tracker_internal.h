//
//  Tracker_internal.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 14/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tracker.h"

@interface Tracker ()

- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSDictionary<NSString *, NSValue *> *)attributeGetters;

@end

