//
//  AVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"
#import "TrackerAutomat.h"

@import AVKit;

@interface AVPlayerTracker ()

@property (nonatomic) TrackerAutomat *automat;

// AVPlayer weak reference
@property (nonatomic, weak) AVPlayer *player;

// Is it playing?
@property (nonatomic) BOOL isPlaying;
// Did user press play?
@property (nonatomic) BOOL playActionRequested;
// Time of play press event
@property (nonatomic) NSTimeInterval playActionTime;
// Time of actual play start
@property (nonatomic) NSTimeInterval actualPlayStartTime;
// Is buffering?
@property (nonatomic) BOOL isBuffering;
// Is it paused?
@property (nonatomic) BOOL isPaused;

@end

@implementation AVPlayerTracker

- (instancetype)initWithAVPlayer:(AVPlayer *)player {
    if (self = [super init]) {
        self.player = player;
        self.automat = [[TrackerAutomat alloc] init];
    }
    return self;
}

- (void)reset {
    self.isPlaying = NO;
    self.playActionRequested = NO;
    self.playActionTime = 0;
    self.actualPlayStartTime = 0;
    self.isBuffering = NO;
    self.isPaused = NO;
}

- (void)setup {
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        double currentTime = (double)time.value / (double)time.timescale;
        NSLog(@"Current playback time = %lf", currentTime);
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

- (void)endPlayback {
    [self reset];
}

- (NSTimeInterval)epoch {
    return [[NSDate date] timeIntervalSince1970];
}

- (void)setupPlayerEventHandlers {
    
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
    NSLog(@"ItemTimeJumpedNotification = %@", statusStr);
    
    // If not playing and status is ReadyToPlay, we are starting actual playback
    if (!self.isPlaying && p.status == AVPlayerItemStatusReadyToPlay) {
        self.isPlaying = YES;
        self.actualPlayStartTime = [self epoch];
    
        NSLog(@"#### CLICK PLAY OR AUTOPLAY");
    }
    else if (p.status == AVPlayerItemStatusFailed) {
        [self reset];
        
        NSLog(@"#### ERROR WHILE PLAYING");
    }
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    
    NSLog(@"ItemDidPlayToEndTimeNotification");
    [self endPlayback];

    NSLog(@"#### FINISHED PLAYING");
}

// KVO observer method
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"rate"]) {
        
        float rate = [(NSNumber *)change[NSKeyValueChangeNewKey] floatValue];
        
        if (rate == 0.0) {
            NSLog(@"Video Rate Log: Stopped Playback");
            
            if (self.player.error != nil) {
                NSLog(@"  -> Playback Failed");
            }
            else if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
                NSLog(@"  -> Playback Reached the End");
            }
            else if (!self.player.currentItem.playbackLikelyToKeepUp) {
                NSLog(@"  -> Playback Waiting Data");
            }
            else {
                // User paused the video
                self.isPaused = YES;
                
                NSLog(@"#### PAUSE");
            }
        }
        else if (rate == 1.0) {
            NSLog(@"Video Rate Log: Normal Playback");
            
            if (!self.playActionRequested) {
                self.playActionRequested = YES;
                self.playActionTime = [self epoch];
                
                NSLog(@"#### VIDEO START PLAYING");
            }
            else if (self.isPaused) {
                self.isPaused = NO;
                
                NSLog(@"#### RESUME");
            }
        }
        else if (rate == -1.0) {
            NSLog(@"Video Rate Log: Reverse Playback");
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        NSLog(@"Video Playback Buffer Empty");
        if (!self.isBuffering) {
            self.isBuffering = YES;
            
            NSLog(@"#### VIDEO STARTED BUFFERING");
        }
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        NSLog(@"Video Playback Likely To Keep Up");
        if (self.isBuffering) {
            self.isBuffering = NO;
            
            NSLog(@"#### VIDEO ENDED BUFFERING (I)");
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        NSLog(@"Video Playback Buffer Full");
        if (self.isBuffering) {
            self.isBuffering = NO;
            
            NSLog(@"#### VIDEO ENDED BUFFERING (II)");
        }
    }
}

@end
