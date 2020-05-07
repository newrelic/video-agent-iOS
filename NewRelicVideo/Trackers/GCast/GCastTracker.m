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
    [self registerGCastListeners];
    [self sendPlayerReady];
}

- (void)registerGCastListeners {
    if (self.sessionManager) {
        [self.sessionManager addListener:self];
        [self.sessionManager.currentCastSession.remoteMediaClient addListener:self];
    }
}

- (void)updateGCastAttributes {
    if (self.sessionManager.currentSession) {
        [self setOptionKey:@"castAppId" value:[self getCastAppId]];
        [self setOptionKey:@"castAppName" value:[self getCastAppName]];
        [self setOptionKey:@"castDeviceStatusText" value:[self getCastDeviceStatusText]];
        [self setOptionKey:@"castSessionId" value:[self getCastSessionId]];
        [self setOptionKey:@"castDeviceId" value:[self getCastDeviceId]];
        [self setOptionKey:@"castDeviceCategory" value:[self getCastDeviceCategory]];
        [self setOptionKey:@"castDeviceVersion" value:[self getCastDeviceVersion]];
        [self setOptionKey:@"castDeviceModelName" value:[self getCastDeviceModelName]];
        [self setOptionKey:@"castDeviceUniqueId" value:[self getCastDeviceUniqueId]];
    }
}

- (void)sendPlayerReady {
    [self updateGCastAttributes];
    [super sendPlayerReady];
}

- (void)sendRequest {
    [self updateGCastAttributes];
    [super sendRequest];
}

- (void)sendStart {
    [self updateGCastAttributes];
    [super sendStart];
}

- (void)sendEnd {
    [self updateGCastAttributes];
    if (self.state == TrackerStateBuffering) {
        [self sendBufferEnd];
    }
    [super sendEnd];
}

- (void)sendPause {
    [self updateGCastAttributes];
    [super sendPause];
}

- (void)sendResume {
    [self updateGCastAttributes];
    [super sendResume];
}

- (void)sendSeekStart {
    [self updateGCastAttributes];
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [self updateGCastAttributes];
    [super sendSeekEnd];
}
 
- (void)sendBufferStart {
    [self updateGCastAttributes];
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [self updateGCastAttributes];
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    [self updateGCastAttributes];
    [super sendHeartbeat];
}

- (void)sendStartCastSession {
    [self updateGCastAttributes];
    [self sendCustomAction:@"CAST_START_SESSION"];
}

- (void)sendEndCastSession {
    [self updateGCastAttributes];
    [self sendCustomAction:@"CAST_END_SESSION"];
}

- (void)setMediaRequestInstance:(GCKRequest *)request {
    if (request != nil) {
        request.delegate = self;
        
    }
}

#pragma mark - GCKSessionManagerListener

- (void)sessionManager:(GCKSessionManager *)sessionManager
       didStartSession:(GCKCastSession *)session {
    AV_LOG(@"DID START SESSION");
    
    [self sendStartCastSession];
    [self registerGCastListeners];
}

- (void)sessionManager:(GCKSessionManager *)sessionManager
         didEndSession:(GCKCastSession *)session
             withError:(nullable NSError *)error {
    AV_LOG(@"DID END SESSION");
    
    if (!error) {
        if (self.state != TrackerStateStopped) {
            [self sendEnd];
        }
    }
    else {
        [self sendError:error];
    }
    
    [self sendEndCastSession];
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
    if (self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.currentQueueItem) {
        return @(self.sessionManager.currentCastSession.remoteMediaClient.mediaStatus.currentQueueItem.autoplay);
    }
    else {
        return nil;
    }
}

- (NSNumber *)getIsFullscreen {
    return @YES;
}

#pragma mark - GCast getters

- (NSString *)getCastAppId {
    return self.sessionManager.currentCastSession.applicationMetadata.applicationID;
}

- (NSString *)getCastAppName {
    return self.sessionManager.currentCastSession.applicationMetadata.applicationName;
}

- (NSString *)getCastDeviceStatusText {
    return self.sessionManager.currentSession.deviceStatusText;
}

- (NSString *)getCastSessionId {
    return self.sessionManager.currentSession.sessionID;
}

- (NSString *)getCastDeviceId {
    return self.sessionManager.currentSession.device.deviceID;
}

- (NSString *)getCastDeviceCategory {
    return self.sessionManager.currentSession.device.category;
}

- (NSString *)getCastDeviceVersion {
    return self.sessionManager.currentSession.device.deviceVersion;
}

- (NSString *)getCastDeviceModelName {
    return self.sessionManager.currentSession.device.modelName;
}

- (NSString *)getCastDeviceUniqueId {
    return self.sessionManager.currentSession.device.uniqueID;
}

@end
