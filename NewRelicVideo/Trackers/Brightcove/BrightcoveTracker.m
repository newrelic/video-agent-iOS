//
//  BrightcoveTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 01/05/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import "BrightcoveTracker.h"

@interface BrightcoveTracker ()

@property (nonatomic) id<BCOVPlaybackController> playbackController;

@end

@implementation BrightcoveTracker

- (instancetype)initWithBrightcove:(id<BCOVPlaybackController>)playbackController {
    if (self = [super init]) {
        self.playbackController = playbackController;
        self.playbackController.delegate = self;
    }
    return self;
}


#pragma mark BCOVPlaybackControllerDelegate Methods

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session {
    AV_LOG(@"Advanced to new session.");
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress {
    AV_LOG(@"Progress: %0.2f seconds", progress);
}

- (void)playbackController:(id<BCOVPlaybackController>)controller didCompletePlaylist:(id<NSFastEnumeration>)playlist {
    AV_LOG(@"didCompletePlaylist");
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent {
    AV_LOG(@"didReceiveLifecycleEvent = %@", lifecycleEvent);
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didPassCuePoints:(NSDictionary *)cuePointInfo {
    AV_LOG(@"didPassCuePoints = %@", cuePointInfo);
}

@end
