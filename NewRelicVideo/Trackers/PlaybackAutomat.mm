//
//  PlaybackAutomat.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 25/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "PlaybackAutomat.h"
#import "PlaybackAutomatCore.hpp"
#import "BackendActionsCore.hpp"
#import "BackendActions.h"

@interface PlaybackAutomat ()
{
    PlaybackAutomatCore *playbackAutomatCore;
}
@end

@implementation PlaybackAutomat

- (instancetype)init {
    if (self = [super init]) {
        playbackAutomatCore = new PlaybackAutomatCore();
        _actions = [[BackendActions alloc] initWithCoreRef:playbackAutomatCore->getActions()];
    }
    return self;
}

- (void)dealloc {
    delete playbackAutomatCore;
}

- (void)setState:(TrackerState)val {
    playbackAutomatCore->state = (CoreTrackerState)val;
}

- (TrackerState)getState {
    return (TrackerState)playbackAutomatCore->state;
}

- (void)setIsAdd:(BOOL)val {
    playbackAutomatCore->isAd = (bool)val;
}

- (BOOL)getIsAdd {
    return (BOOL)playbackAutomatCore->isAd;
}

- (void)sendRequest {
    playbackAutomatCore->sendRequest();
}

- (void)sendStart {
    playbackAutomatCore->sendStart();
}

- (void)sendEnd {
    playbackAutomatCore->sendEnd();
}

- (void)sendPause {
    playbackAutomatCore->sendPause();
}

- (void)sendResume {
    playbackAutomatCore->sendResume();
}

- (void)sendSeekStart {
    playbackAutomatCore->sendSeekStart();
}

- (void)sendSeekEnd {
    playbackAutomatCore->sendSeekEnd();
}

- (void)sendBufferStart {
    playbackAutomatCore->sendBufferStart();
}

- (void)sendBufferEnd {
    playbackAutomatCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    playbackAutomatCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    playbackAutomatCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    playbackAutomatCore->sendError(std::string([message UTF8String]));
}

@end
