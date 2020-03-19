//
//  TimerCAL.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 30/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TrackerProtocol;

@interface TimerCAL : NSObject

- (instancetype)initWithTracker:(id<TrackerProtocol>)tracker;
- (void)startTimer:(double)timeInterval;
- (void)abortTimer;

@end
