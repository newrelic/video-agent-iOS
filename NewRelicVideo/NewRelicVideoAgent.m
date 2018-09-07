//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "AVPlayerTracker.h"
#import "ContentsTracker.h"

// TODO: what if we have multiple players instantiated, what happens with the NSNotifications?
// TODO: right now we don't support multiple player instances being used at the same time. Should we?

@import AVKit;

@interface NewRelicVideoAgent ()

@property (nonatomic) ContentsTracker<ContentsTrackerProtocol> *tracker;

@end

@implementation NewRelicVideoAgent

+ (instancetype)sharedInstance {
    static NewRelicVideoAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NewRelicVideoAgent alloc] init];
    });
    return instance;
}

+ (void)startWithPlayer:(id)player {
    if ([player isKindOfClass:[AVPlayer class]]) {
        [self startWithTracker:[[AVPlayerTracker alloc] initWithAVPlayer:(AVPlayer *)player]];
        AV_LOG(@"Created AVPlayerTracker");
    }
    else if ([player isKindOfClass:[AVPlayerViewController class]]) {
        [self startWithTracker:[[AVPlayerTracker alloc] initWithAVPlayerViewController:(AVPlayerViewController *)player]];
        AV_LOG(@"Created AVPlayerViewControllerTracker");
    }
    else  {
        [[self sharedInstance] setTracker:nil];
        NSLog(@"⚠️ Not recognized player class. ⚠️");
    }
}

+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker {

    [[self sharedInstance] setTracker:tracker];
    
    if ([[self sharedInstance] tracker]) {
        AV_LOG(@"Tracker exist, initialize it");
        [[[self sharedInstance] tracker] reset];
        [[[self sharedInstance] tracker] setup];
    }
    else {
        AV_LOG(@"Tracker is nil!");
    }
}

+ (ContentsTracker<ContentsTrackerProtocol> *)trackerInstance {
    return [[self sharedInstance] tracker];
}

@end
