//
//  AVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"

// BUG: is video is buffering, seeking doesn't produce time observer events wiith rate == 0.
// BUG: buffering events are not always triggered by AVPlayer.

@import AVKit;

@interface AVPlayerTracker ()

// AVPlayer weak reference
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic) int numZeroRates;
@property (nonatomic) double estimatedBitrate;

@end

@implementation AVPlayerTracker

- (instancetype)initWithAVPlayer:(AVPlayer *)player {
    if (self = [super init]) {
        self.player = player;
    }
    return self;
}

- (void)reset {
    [super reset];
    self.numZeroRates = 0;
    self.estimatedBitrate = 0;
}

- (void)setup {
    
    [super setup];
    
    [self setupBitrateOptions];
    
    // Register periodic time observer (an event every 1/2 seconds)
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        //double currentTime = CMTimeGetSeconds(time);
        //AV_LOG(@"Current playback rate = %f, time = %lf", self.player.rate, currentTime);
        
        // KNOWN PROBLEMS:
        // * It send a pause right before seek start and a resume right after seek end
        // * If seeked while paused, the seek end is sent only when user resumes the video.
        
        if (self.player.rate == 0) {
            self.numZeroRates ++;
            
            if (self.numZeroRates == 2) {
                [self sendSeekStart];
            }
        }
        else {
            if (self.numZeroRates > 2) {
                [self sendSeekEnd];
                [self sendResume];      // We send Resume because the Pause is sent before seek start and we neet to put the state machine in a "normal" state.
            }
            self.numZeroRates = 0;
        }
    }];
    
    // Register NSNotification listeners
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemTimeJumpedNotification:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    // Register KVO events
    
    [self.player addObserver:self forKeyPath:@"rate"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferEmpty"
                                 options:NSKeyValueObservingOptionNew
                                 context:NULL];
    
    [self.player.currentItem addObserver:self forKeyPath:@"playbackBufferFull"
                                 options:NSKeyValueObservingOptionNew
                                 context:NULL];
    
    [self.player.currentItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp"
                                 options:NSKeyValueObservingOptionNew
                                 context:NULL];
    
    AV_LOG(@"Setup AVPlayer events and listener");
}

#pragma mark - Item Handlers

- (void)itemTimeJumpedNotification:(NSNotification *)notification {
    
    AVPlayerItem *p = [notification object];
    NSString *statusStr = @"";
    switch (p.status) {
        case AVPlayerItemStatusFailed:
            statusStr = @"Failed";
            break;
        case AVPlayerItemStatusUnknown:
            statusStr = @"Unknown";
            break;
        case AVPlayerItemStatusReadyToPlay:
            statusStr = @"Ready";
            break;
        default:
            break;
    }
    AV_LOG(@"ItemTimeJumpedNotification = %@", statusStr);
    
    if (p.status == AVPlayerItemStatusReadyToPlay) {
        [self sendStart];
    }
    else if (p.status == AVPlayerItemStatusFailed) {
        AV_LOG(@"#### ERROR WHILE PLAYING");
        // NOTE: this is probably redundant and already catched in "rate" KVO when self.player.error != nil
    }
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    AV_LOG(@"ItemDidPlayToEndTimeNotification");
    AV_LOG(@"#### FINISHED PLAYING");
    // NOTE: this is redundant and already catched in "rate" KVO
}

// KVO observer method
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"rate"]) {
        
        float rate = [(NSNumber *)change[NSKeyValueChangeNewKey] floatValue];
        
        if (rate == 0.0) {
            AV_LOG(@"Video Rate Log: Stopped Playback");
            
            if (self.player.error != nil) {
                AV_LOG(@"  -> Playback Failed");
                [self sendError];
            }
            else if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
                AV_LOG(@"  -> Playback Reached the End");
                [self sendEnd];
                [self abortTimerEvent];
            }
            else if (!self.player.currentItem.playbackLikelyToKeepUp) {
                // NOTE: it happens when bad connection and user seeks back and forth and doesn't give time enought for buffering
                AV_LOG(@"  -> Playback Waiting Data");
            }
            else {
                // Click Pause
                [self sendPause];
            }
        }
        else if (rate == 1.0) {
            AV_LOG(@"Video Rate Log: Normal Playback");
            
            // Click Play
            [self sendResume];
            [self startTimerEvent];
        }
        else if (rate == -1.0) {
            AV_LOG(@"Video Rate Log: Reverse Playback");
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        AV_LOG(@"Video Playback Buffer Empty");
        [self sendBufferStart];
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        AV_LOG(@"Video Playback Likely To Keep Up");
        [self sendBufferEnd];
    }
    else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        AV_LOG(@"Video Playback Buffer Full");
        [self sendBufferEnd];
    }
    else {
        AV_LOG(@"OBSERVER unknown = %@", keyPath);
    }
}

// Time Evenent, called by a timer in the superclass, every OBSERVATION_TIME seconds
- (void)timeEvent {
    if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
        AV_LOG(@"Timeout, video ended but no event received.");
        [self sendEnd];
        [self abortTimerEvent];
    }

    [self setupBitrateOptions];
}

- (void)setupBitrateOptions {
    // Calc estimated bitrate and send a rendition change event if it changed
    AVPlayerItemAccessLogEvent *event = [self.player.currentItem.accessLog.events lastObject];
    double numberOfBitsTransferred = (event.numberOfBytesTransferred * 8);
    double newEstimatedBitrate = numberOfBitsTransferred / event.segmentsDownloadedDuration;
    
    if (self.estimatedBitrate == 0) {
        self.estimatedBitrate = newEstimatedBitrate;
    }
    else if (fabs(self.estimatedBitrate - newEstimatedBitrate) >  self.estimatedBitrate * 0.01) {
        // If bitrate changes more than 1%, rendition change event
        [self sendRenditionChange];
        self.estimatedBitrate = newEstimatedBitrate;
        
        AV_LOG(@"New Rendition Change = %d", newEstimatedBitrate);
    }
}

#pragma mark - VideoTracker getters

- (NSString *)getTrackerName {
    return @"avplayer";
}

- (NSString *)getTrackerVersion {
    return @"1.0";
}

- (NSString *)getPlayerVersion {
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)getPlayerName {
    return @"avplayer";
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
    Float64 duration = CMTimeGetSeconds(self.player.currentItem.currentTime);
    if (isnan(duration)) {
        return @0;
    }
    else {
        return @(duration * 1000.0f);
    }
}

- (NSString *)getSrc {
    AVAsset *currentPlayerAsset = self.player.currentItem.asset;
    if (![currentPlayerAsset isKindOfClass:AVURLAsset.class]) return @"";
    return [[(AVURLAsset *)currentPlayerAsset URL] absoluteString];
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

// NOTE: should be handled by a custom tracker, subclassing it
- (NSNumber *)getIsLive {
    return @NO;
}

// NOTE: should be handled by a custom tracker, subclassing it
- (NSNumber *)getIsAd {
    return @NO;
}

@end
