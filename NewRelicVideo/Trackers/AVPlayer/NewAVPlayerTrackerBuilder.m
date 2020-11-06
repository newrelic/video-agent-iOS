//
//  NewAVPlayerTrackerBuilder.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/11/2020.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import "NewAVPlayerTrackerBuilder.h"
#import "NewAVPlayerTracker.h"
#import "NewRelicVideoAgent.h"

@import AVKit;

@implementation NewAVPlayerTrackerBuilder

+ (NSNumber *)startWithPlayer:(id)player {
    if ([player isKindOfClass:[AVPlayer class]]) {
        NSNumber *trackerId = [NewRelicVideoAgent startWithTracker:[[NewAVPlayerTracker alloc] initWithAVPlayer:(AVPlayer *)player]];
        AV_LOG(@"Created AVPlayerTracker");
        return trackerId;
    }
    else if ([player isKindOfClass:[AVPlayerViewController class]]) {
        NSNumber *trackerId = [NewRelicVideoAgent startWithTracker:[[NewAVPlayerTracker alloc] initWithAVPlayerViewController:(AVPlayerViewController *)player]];
        AV_LOG(@"Created AVPlayerViewControllerTracker");
        return trackerId;
    }
    else {
        return nil;
    }
}

@end
