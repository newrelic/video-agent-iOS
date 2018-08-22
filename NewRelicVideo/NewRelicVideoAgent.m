//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "EventDefs.h"
#import <NewRelicAgent/NewRelic.h>

// TODO: simulate slow network, see what happens with the timeSinceRequest
// TODO: what if we have multiple players instantiated, what happens with the NSNotifications?
// TODO: every time the playback ends, we need to create a new "video event id"

// DONE: Autoplay, what happens with the request and start events?
// DONE: check if NewRelicAgent exist and is init

@import AVKit;

@interface NewRelicVideoAgent ()

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

@end

@implementation NewRelicVideoAgent

+ (void)startWithAVPlayer:(AVPlayer *)player {
    static NewRelicVideoAgent *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NewRelicVideoAgent alloc] init];
        // First time inits here
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
}

- (void)endPlayback {
    [self resetState];
}

- (NSTimeInterval)epoch {
    return [[NSDate date] timeIntervalSince1970];
}

- (void)setupPlayerEventHandlers {
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        //double currentTime = (double)time.value / (double)time.timescale;
        //NSLog(@"Current playback time = %lf", currentTime);
        
        // User click "play" (What about the autoplay?)
        if (!self.playActionRequested) {
            self.playActionRequested = YES;
            self.playActionTime = [self epoch];
            [self sendRequest];
        }
    }];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemTimeJumpedNotification:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
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
        [self sendStart];
    }
    else if (p.status == AVPlayerItemStatusFailed) {
        [self resetState];
        [self sendError];
    }
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    
    NSLog(@"ItemDidPlayToEndTimeNotification");
    [self endPlayback];
    [self sendEnd];
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
            
            if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
                NSLog(@"  -> Playback Reached the End");
            }
            else if (!self.player.currentItem.playbackLikelyToKeepUp) {
                NSLog(@"  -> Playback Waiting Data");
            }
        }
        else if (rate == 1.0) {
            NSLog(@"Video Rate Log: Normal Playback");
        }
        else if (rate == -1.0) {
            NSLog(@"Video Rate Log: Reverse Playback");
        }
    }
    else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
        NSLog(@"Video Playback Buffer Empty");
        [self sendBufferStart];
    }
    else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
        NSLog(@"Video Playback Likely To Keep Up");
        [self sendBufferEnd];
    }
    else if ([keyPath isEqualToString:@"playbackBufferFull"]) {
        NSLog(@"Video Playback Buffer Full");
        [self sendBufferEnd];
    }
}

#pragma mark - Tracker Method

- (void)sendBufferEnd {
    if (self.isBuffering) {
        self.isBuffering = NO;
        [self sendAction:CONTENT_BUFFER_END];
    }
}

- (void)sendBufferStart {
    if (!self.isBuffering) {
        self.isBuffering = YES;
        [self sendAction:CONTENT_BUFFER_START];
    }
}

- (void)sendError {
    [self sendAction:CONTENT_ERROR];
}

- (void)sendRequest {
    [self sendAction:CONTENT_REQUEST];
}

- (void)sendStart {
    NSTimeInterval timeToStart = self.actualPlayStartTime - self.playActionTime;
    timeToStart = timeToStart < 0 ? 0 : timeToStart;
    [self sendAction:CONTENT_START attr:@{@"timeSinceRequested": @(timeToStart * 1000.0f)}];
}

- (void)sendEnd {
    [self sendAction:CONTENT_END];
}

#pragma mark - SendAction

- (void)sendAction:(NSString *)name {
    [self sendAction:name attr:nil];
}

- (void)sendAction:(NSString *)name attr:(NSDictionary *)dict {
    
    dict = dict ? dict : @{};
    
    NSLog(@"sendAction name = %@, attr = %@", name, dict);
    
    NSMutableDictionary *ops = @{@"actionName": name}.mutableCopy;
    [ops addEntriesFromDictionary:dict];
    
    if ([NewRelicAgent currentSessionId]) {
        [NewRelic recordCustomEvent:VIDEO_EVENT
                         attributes:ops];
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
}

@end
