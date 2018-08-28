//
//  AVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"
#import "TrackerAutomat.h"

#define INTERVAL_SEEK           0.5
#define OBSERVATION_TIME        10.0f

// TODO: SEEK start/end

// NOTE: if autoplay, we have to manually send the transition AUTOPLAY
// NOTE: if time period event arrives (addPeriodicTimeObserverForInterval) and rate == 0 we are seeking??
// BUG: if we seek until the end, the VIDEO FINISHED never arrives. Possible workaround: after getting a timevent with rate = 0, wait for a timevent with rate = 1, if timeout fire the video finshed event.
// BUG: is video is not playing (is buffering), seeking doesn't produce time observer events wiith rate == 0.
// BUG: buffering events are not always triggered by AVPlayer.

@import AVKit;

@interface AVPlayerTracker ()

@property (nonatomic) TrackerAutomat *automat;

// AVPlayer weak reference
@property (nonatomic, weak) AVPlayer *player;

@property (nonatomic) double lastPlayhead;
@property (nonatomic) NSTimer *playerStateObserverTimer;

@end

@implementation AVPlayerTracker

- (instancetype)initWithAVPlayer:(AVPlayer *)player {
    if (self = [super init]) {
        self.player = player;
        self.automat = [[TrackerAutomat alloc] init];
    }
    return self;
}

- (void)reset {}

- (void)setup {
    
    // Register periodic time observer (an event every 1/2 seconds)
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        double currentTime = CMTimeGetSeconds(time);
        AV_LOG(@"Current playback rate = %f, time = %lf", self.player.rate, currentTime);
        
        // TEST: Nice People At Work Method
        // NOTE: sometimes, when seeking while video is paused or seeking backward, this method doesn't work well.
        if (self.lastPlayhead != 0) {
            double distance = ABS(self.lastPlayhead - currentTime);
            if (distance > INTERVAL_SEEK * 2) {
                // Distance is very big -> seeking
                //[self seekingHandler];
                AV_LOG(@"#### SEEKING (I)");
            }
        }
        self.lastPlayhead = currentTime;
        
        // TODO: My Method
        // NOTE: this method works better than the NPAW, with only one exception: when video is paused, it's fired once, causing a false positive.
        if (self.player.rate == 0) {
            AV_LOG(@"#### SEEKING (II)");
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
}

- (NSTimeInterval)epoch {
    return [[NSDate date] timeIntervalSince1970];
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
        [self.automat transition:TrackerTransitionFrameShown];
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
                [self.automat transition:TrackerTransitionErrorPlaying];
                
                [self abortPlayerStateObserverTimer];
            }
            else if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
                AV_LOG(@"  -> Playback Reached the End");
                [self.automat transition:TrackerTransitionVideoFinished];
                
                [self abortPlayerStateObserverTimer];
            }
            else if (!self.player.currentItem.playbackLikelyToKeepUp) {
                // NOTE: it happens when bad connection and user seeks back and forth and doesn't give time enought for buffering
                AV_LOG(@"  -> Playback Waiting Data");
            }
            else {
                // Click Pause
                [self.automat transition:TrackerTransitionClickPause];
            }
        }
        else if (rate == 1.0) {
            AV_LOG(@"Video Rate Log: Normal Playback");
            
            // Click Play
            [self.automat transition:TrackerTransitionClickPlay];
            
            [self startPlayerStateObserverTimer];
        }
        else if (rate == -1.0) {
            AV_LOG(@"Video Rate Log: Reverse Playback");
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        AV_LOG(@"Video Playback Buffer Empty");
        
        [self.automat transition:TrackerTransitionInitBuffering];
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        AV_LOG(@"Video Playback Likely To Keep Up");
        
        [self.automat transition:TrackerTransitionEndBuffering];
    }
    else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        AV_LOG(@"Video Playback Buffer Full");

        [self.automat transition:TrackerTransitionEndBuffering];
    }
    else {
        AV_LOG(@"OBSERVER unknown = %@", keyPath);
    }
}

- (void)startPlayerStateObserverTimer {
    if (self.playerStateObserverTimer) {
        [self abortPlayerStateObserverTimer];
    }
    
    self.playerStateObserverTimer = [NSTimer scheduledTimerWithTimeInterval:OBSERVATION_TIME
                                                                     target:self
                                                                   selector:@selector(playerObserverMethod:)
                                                                   userInfo:nil
                                                                    repeats:YES];
}

- (void)abortPlayerStateObserverTimer {
    [self.playerStateObserverTimer invalidate];
    self.playerStateObserverTimer = nil;
}

- (void)playerObserverMethod:(NSTimer *)timer {
    // TODO
    AV_LOG(@"PLAYER STATE {");
    AV_LOG(@"Rate = %f", self.player.rate);
    AV_LOG(@"Status = %d", self.player.status);
    AV_LOG(@"currentItem.isPlaybackBufferFull = %d", self.player.currentItem.isPlaybackBufferFull);
    AV_LOG(@"currentItem.isPlaybackBufferEmpty = %d", self.player.currentItem.isPlaybackBufferEmpty);
    AV_LOG(@"currentItem.isPlaybackBufferFull = %d", self.player.currentItem.isPlaybackBufferFull);
    if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
        AV_LOG(@"Playback Reached the End");
    }
    AV_LOG(@"}");
    
}

@end
