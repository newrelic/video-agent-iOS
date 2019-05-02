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
@property (nonatomic) id<BCOVPlaybackSession> playbackSession;

@end

@implementation BrightcoveTracker

- (instancetype)initWithBrightcove:(id<BCOVPlaybackController>)playbackController {
    if (self = [super init]) {
        self.playbackController = playbackController;
        self.playbackController.delegate = self;
    }
    return self;
}

- (void)reset {
    [super reset];
}

- (void)setup {
    [super setup];
    [self sendPlayerReady];
}

- (void)updateSession:(id<BCOVPlaybackSession>)session {
    self.playbackSession = session;
}

- (void)updatePlayerState:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEven {
    
    if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventEnd]) {
        [self sendEnd];
        return;
    }
    
    switch (self.state) {
        case TrackerStateStopped: {
            if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPlaybackBufferEmpty]) {
                [self sendBufferStart];
            }
            break;
        }
            
        case TrackerStateStarting: {
            
            break;
        }
            
        case TrackerStatePlaying: {
            if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPause]) {
                [self sendPause];
            }
            
            break;
        }
            
        case TrackerStatePaused: {
            if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPlay]) {
                [self sendResume];
            }
            break;
        }
            
        case TrackerStateBuffering: {
            if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventReady]) {
                [self sendBufferEnd];
            }
            else if ([lifecycleEven.eventType isEqualToString:kBCOVPlaybackSessionLifecycleEventPlay]) {
                [self sendBufferEnd];
                [self sendRequest];
            }
            
            break;
        }
            
        case TrackerStateSeeking: {
            
            break;
        }
            
        default:
            break;
    }
}

- (AVPlayer *)player {
    return self.playbackSession.player;
}

#pragma mark BCOVPlaybackControllerDelegate Methods

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session {
    AV_LOG(@"didAdvanceToPlaybackSession");
    [self updateSession:session];
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress {
    //AV_LOG(@"didProgressTo = %0.2f seconds", progress);
    [self updateSession:session];
    
    if (self.state == TrackerStateStarting) {
        [self sendStart];
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller didCompletePlaylist:(id<NSFastEnumeration>)playlist {
    AV_LOG(@"didCompletePlaylist");
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent {
    AV_LOG(@"didReceiveLifecycleEvent = %@", lifecycleEvent);
    [self updateSession:session];
    [self updatePlayerState:lifecycleEvent];
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didPassCuePoints:(NSDictionary *)cuePointInfo {
    AV_LOG(@"didPassCuePoints = %@", cuePointInfo);
    [self updateSession:session];
}

- (void)playbackSession:(id<BCOVPlaybackSession>)session didChangeDuration:(NSTimeInterval)duration {
    AV_LOG(@"didChangeDuration = %0.2f seconds", duration);
    [self updateSession:session];
}

#pragma mark - ContentsTracker getters

- (NSString *)getTrackerName {
    return @"brightcovetracker";
}

- (NSString *)getTrackerVersion {
    return @PRODUCT_VERSION_STR;
}

- (NSString *)getPlayerVersion {
    return BCOVPlayerSDKManager.version;
}

- (NSString *)getPlayerName {
    return @"brightcove";
}

- (NSNumber *)getBitrate {
    AVPlayerItemAccessLogEvent *event = [self.player.currentItem.accessLog.events lastObject];
    return @(event.indicatedBitrate);
}

- (NSNumber *)getRenditionWidth {
    return @(self.player.currentItem.presentationSize.width);
}

- (NSNumber *)getRenditionHeight {
    return @(self.player.currentItem.presentationSize.height);
}

- (NSNumber *)getDuration {
    Float64 duration = CMTimeGetSeconds(self.player.currentItem.duration);
    if (isnan(duration)) {
        return @0;
    }
    else {
        return @(duration * 1000.0f);
    }
}

- (NSNumber *)getPlayhead {
    Float64 pos = CMTimeGetSeconds(self.player.currentItem.currentTime);
    if (isnan(pos)) {
        return @0;
    }
    else {
        return @(pos * 1000.0f);
    }
}

/*
- (NSString *)getSrc {
    AVAsset *currentPlayerAsset = self.player.currentItem.asset;
    if (![currentPlayerAsset isKindOfClass:AVURLAsset.class]) return @"";
    return [[(AVURLAsset *)currentPlayerAsset URL] absoluteString];
}
 */

- (NSString *)getSrc {
    return _playbackController.analytics.source;
}

- (NSNumber *)getPlayrate {
    return @(self.player.rate);
}

- (NSNumber *)getFps {
    double fps = 0.0f;
    AVAsset *asset = self.player.currentItem.asset;
    if (asset) {
        AVAssetTrack *videoATrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
        if (videoATrack) {
            fps = videoATrack.nominalFrameRate;
        }
    }
    return @(fps);
}

- (NSNumber *)getIsMuted {
    return @(self.player.muted);
}

- (NSNumber *)getIsAutoplayed {
    return @(_playbackController.isAutoPlay);
}

@end
