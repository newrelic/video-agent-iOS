//
//  BrightcoveTrackerBuilder.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 01/05/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import "BrightcoveTrackerBuilder.h"
#import "NewRelicVideoAgent.h"
#import "BrightcoveTracker.h"

@import BrightcovePlayerSDK;

@implementation BrightcoveTrackerBuilder

+ (BOOL)startWithPlayer:(id)player {
    if ([player conformsToProtocol:@protocol(BCOVPlaybackController)]) {
        [NewRelicVideoAgent startWithTracker:[[BrightcoveTracker alloc] initWithBrightcove:player]];
        AV_LOG(@"Created BrightcoveTracker");
        return YES;
    }
    return NO;
}

@end
