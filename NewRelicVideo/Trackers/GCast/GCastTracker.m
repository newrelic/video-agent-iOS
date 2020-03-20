//
//  GCastTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 18/02/2019.
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import "GCastTracker.h"
#import "EventDefs.h"

#import <GoogleCast/GoogleCast.h>

@interface GCastTracker () <GCKRemoteMediaClientListener, GCKSessionManagerListener, GCKRequestDelegate>

@property (nonatomic) GCKSessionManager *sessionManager;
@property (nonatomic) BOOL isAutoPlayed;

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
    self.isAutoPlayed = NO;
}

- (void)setup {
    [super setup];
    [self registerGCastListeners];
    [self sendPlayerReady];
}

- (void)registerGCastListeners {
    if (self.sessionManager) {
        [self.sessionManager addListener:self];
        [self.sessionManager.currentCastSession.remoteMediaClient addListener:self];
    }
}

- (void)sendEnd {
    if (self.state == TrackerStateBuffering) {
        [self sendBufferEnd];
    }
    [super sendEnd];
}

- (void)setMediaRequestInstance:(GCKRequest *)request {
    if (request != nil) {
        request.delegate = self;
        
    }
}

#pragma mark - GCKSessionManagerListener

- (void)sessionManager:(GCKSessionManager *)sessionManager
       didStartSession:(GCKCastSession *)session {
    AV_LOG(@"DID START GCAST SESSION");
    
    [self registerGCastListeners];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
         didEndSession:(GCKCastSession *)session
             withError:(nullable NSError *)error {
    AV_LOG(@"DID END GCAST SESSION");
    
    if (!error) {
        if (self.state != TrackerStateStopped) {
            [self sendEnd];
        }
    }
    else {
        [self sendError:error];
    }
}

- (void)sessionManager:(GCKSessionManager *)sessionManager didResumeSession:(GCKSession *)session {
    AV_LOG(@"DID RESUME GCAST SESSION");
    
    [self registerGCastListeners];
}

#pragma mark - GCKRemoteMediaClientListener

- (void)remoteMediaClient:(GCKRemoteMediaClient *)client didUpdateMediaStatus:(nullable GCKMediaStatus *)mediaStatus {
    
    NSString *playerState;
    
    switch (mediaStatus.playerState) {
        default:
        case GCKMediaPlayerStateUnknown:
            playerState = @"Unknown";
            break;
            
        case GCKMediaPlayerStateIdle:
            playerState = @"Idle";
            if (self.state != TrackerStateStopped) {
                [self sendEnd];
            }
            break;
            
        case GCKMediaPlayerStatePlaying:
            playerState = @"Playing";
            if (self.state == TrackerStateStarting) {
                [self sendStart];
            }
            else if (self.state == TrackerStateBuffering) {
                [self sendBufferEnd];
                if (self.state == TrackerStateStarting) {
                    [self sendStart];
                }
            }
            else if (self.state == TrackerStatePaused) {
                [self sendResume];
            }
            break;
            
        case GCKMediaPlayerStatePaused:
            playerState = @"Paused";
            if (self.state == TrackerStatePlaying) {
                [self sendPause];
            }
            break;
            
        case GCKMediaPlayerStateBuffering:
            playerState = @"Buffering";
            if (self.state != TrackerStateBuffering) {
                [self sendBufferStart];
            }
            break;
            
        case GCKMediaPlayerStateLoading:
            playerState = @"Loading";
            if (self.state == TrackerStateStopped) {
                [self sendRequest];
            }
            break;
    }
    
    AV_LOG(@"----> GCast Player State: %@", playerState);
    
    if (mediaStatus.playerState == GCKMediaPlayerStateIdle) {
        
        NSString *idleReason;
        
        switch (mediaStatus.idleReason) {
            default:
            case GCKMediaPlayerIdleReasonNone:
                idleReason = @"None";
                break;
            case GCKMediaPlayerIdleReasonError:
                idleReason = @"Error";
                break;
            case GCKMediaPlayerIdleReasonFinished:
                idleReason = @"Finished";
                break;
            case GCKMediaPlayerIdleReasonCancelled:
                idleReason = @"Cancelled";
                break;
            case GCKMediaPlayerIdleReasonInterrupted:
                idleReason = @"Interrupted";
                break;
        }
        
        AV_LOG(@"----> GCast Idle Reason: %@", idleReason);
    }
}

#pragma mark - GCKRequestDelegate

- (void)request:(GCKRequest *)request didFailWithError:(GCKError *)error {
    AV_LOG(@"GCKRequestDelegate didFailWithError, error = %@", error);
    [self sendError:error];
}

#pragma mark - ContentsTracker getters

- (NSString *)getTrackerName {
    return @"gcasttracker";
}

- (NSString *)getTrackerVersion {
    return @PRODUCT_VERSION_STR;
}

- (NSString *)getPlayerVersion {
    return kGCKFrameworkVersion;
}

- (NSString *)getPlayerName {
    return @"gcast";
}

- (NSNumber *)getDuration {
    return @(self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.mediaInformation.streamDuration * 1000.0f);
}

- (NSNumber *)getPlayhead {
    return @(self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.streamPosition * 1000.0f);
}

- (NSString *)getSrc {
    return self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.mediaInformation.contentURL.absoluteString;
}

- (NSNumber *)getPlayrate {
    return @(self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.playbackRate);
}

// NOTE: should be handled by a custom tracker, subclassing it
- (NSNumber *)getIsLive {
    return @NO;
}

- (NSNumber *)getIsMuted {
    return @(self.sessionManager.currentCastSession.currentDeviceMuted || self.sessionManager.currentCastSession.currentDeviceVolume == 0.0f);
}

- (NSNumber *)getIsAutoplayed {
    return @(self.isAutoPlayed);
}

- (void)setIsAutoplayed:(NSNumber *)state {
    self.isAutoPlayed = state.boolValue;
}

- (NSNumber *)getIsFullscreen {
    return @YES;
}

@end
