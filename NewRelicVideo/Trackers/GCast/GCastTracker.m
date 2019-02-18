//
//  GCastTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 18/02/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import "GCastTracker.h"
#import <GoogleCast/GoogleCast.h>

@interface GCastTracker () <GCKRemoteMediaClientListener>

@property (nonatomic) GCKSessionManager *sessionManager;

@end

@implementation GCastTracker

- (instancetype)initWithGoogleCast:(GCKSessionManager *)sessionManager {
    if (self = [super init]) {
        self.sessionManager = sessionManager;
    }
    return self;
}

- (void)reset {
    [super reset];
}

- (void)setup {
    [super setup];
    
    if (self.sessionManager) {
        [self.sessionManager.currentCastSession.remoteMediaClient addListener:self];
    }
}

#pragma mark - GCKRemoteMediaClientListener

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didUpdateMediaStatus:(nullable GCKMediaStatus *)mediaStatus {
    
    AV_LOG(@"remoteMediaClient - didUpdateMediaStatus");
    
    NSString *playerState;
    switch (mediaStatus.playerState) {
        default:
        case GCKMediaPlayerStateUnknown:
            playerState = @"Unknown";
            break;
        case GCKMediaPlayerStateIdle:
            playerState = @"Idle";
            break;
        case GCKMediaPlayerStatePlaying:
            playerState = @"Playing";
            break;
        case GCKMediaPlayerStatePaused:
            playerState = @"Paused";
            break;
        case GCKMediaPlayerStateBuffering:
            playerState = @"Buffering";
            break;
        case GCKMediaPlayerStateLoading:
            playerState = @"Loading";
            break;
    }
    
    AV_LOG(@"    Player State: %@", playerState);
    AV_LOG(@"    Content URL: %@", client.mediaStatus.mediaInformation.contentURL);
    AV_LOG(@"    Stream duration: %f", client.mediaStatus.mediaInformation.streamDuration);
    AV_LOG(@"    Playback Rate: %f", client.mediaStatus.playbackRate);
    AV_LOG(@"    Stream position: %f", client.mediaStatus.streamPosition);
}

@end
