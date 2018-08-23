//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "BackendActions.h"

/***********************************************************************************************************************
// TODO: make it Tracker independant. Move all Tracker dependant code to a separate classe in Trackers/WhateverTracker/
***********************************************************************************************************************/

// TODO: every time the playback ends, we need to create a new "VIDEO EVENT ID"
// TODO: what if we have multiple players instantiated, what happens with the NSNotifications?

@import AVKit;

@interface NewRelicVideoAgent ()

@property (nonatomic) BackendActions *actions;

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

@implementation NewRelicVideoAgent

+ (void)startWithAVPlayer:(AVPlayer *)player {
    static NewRelicVideoAgent *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NewRelicVideoAgent alloc] init];
        sharedInstance.actions = [BackendActions new];
    });
    
    sharedInstance.player = player;
    [sharedInstance resetState];
    [sharedInstance setupPlayerEventHandlers];
}

- (void)resetState {
    self.isPlaying = NO;
    self.playActionRequested = NO;
    self.playActionTime = 0;
    self.actualPlayStartTime = 0;
    self.isBuffering = NO;
    self.isPaused = NO;
}

- (void)endPlayback {
    [self resetState];
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
        [self.actions sendStart:self.actualPlayStartTime - self.playActionTime];
    }
    else if (p.status == AVPlayerItemStatusFailed) {
        [self resetState];
        [self.actions sendError];
    }
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    
    NSLog(@"ItemDidPlayToEndTimeNotification");
    [self endPlayback];
    [self.actions sendEnd];
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
                [self.actions sendPause];
            }
        }
        else if (rate == 1.0) {
            NSLog(@"Video Rate Log: Normal Playback");
            
            if (!self.playActionRequested) {
                self.playActionRequested = YES;
                self.playActionTime = [self epoch];
                [self.actions sendRequest];
            }
            else if (self.isPaused) {
                self.isPaused = NO;
                [self.actions sendResume];
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
            [self.actions sendBufferStart];
        }
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        NSLog(@"Video Playback Likely To Keep Up");
        if (self.isBuffering) {
            self.isBuffering = NO;
            [self.actions sendBufferEnd];
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        NSLog(@"Video Playback Buffer Full");
        if (self.isBuffering) {
            self.isBuffering = NO;
            [self.actions sendBufferEnd];
        }
    }
}

@end
