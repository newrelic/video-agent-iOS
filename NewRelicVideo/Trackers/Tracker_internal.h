//
//  Tracker_internal.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 14/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tracker.h"

@class PlaybackAutomat;

@interface Tracker ()

@property (nonatomic) PlaybackAutomat *automat;

- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSMutableDictionary<NSString *, NSValue *> *)attributeGetters;

@end

