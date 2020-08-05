//
//  BellAVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/08/2020.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import "BellAVPlayerTracker.h"

@import AVKit;

@interface BellAVPlayerTracker ()

// AVPlayer weak references
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayerViewController *playerViewController;

@property (nonatomic) id timeObserver;

@property (nonatomic) BOOL didRequest;
@property (nonatomic) BOOL didStart;
@property (nonatomic) BOOL didEnd;
@property (nonatomic) BOOL isPaused;
@property (nonatomic) BOOL isSeeking;
@property (nonatomic) BOOL isBuffering;
@property (nonatomic) BOOL isLive;

@end

@implementation BellAVPlayerTracker

- (instancetype)initWithAVPlayer:(AVPlayer *)player {
    if (self = [super init]) {
        self.player = player;
    }
    return self;
}

- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController {
    if (self = [self initWithAVPlayer:playerViewController.player]) {
        self.playerViewController = playerViewController;
    }
    return self;
}

- (void)reset {
    [super reset];
    
    //TODO: unregister observers
    
    self.didRequest = NO;
    self.didStart = NO;
    self.didEnd = NO;
    self.isPaused = NO;
    self.isSeeking = NO;
    self.isBuffering = NO;
    self.isLive = NO;
}

- (void)setup {
    [super setup];

    // Register observers
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemTimeJumpedNotification:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [self.player addObserver:self
                  forKeyPath:@"status"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    [self.player addObserver:self
                  forKeyPath:@"rate"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    [self.player addObserver:self
                  forKeyPath:@"currentItem.status"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    /*
    [self.player addObserver:self
                  forKeyPath:@"currentItem.loadedTimeRanges"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    */
    
    [self.player addObserver:self
                  forKeyPath:@"currentItem.playbackBufferEmpty"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.player addObserver:self
                  forKeyPath:@"currentItem.playbackBufferFull"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];

    [self.player addObserver:self
                  forKeyPath:@"currentItem.playbackLikelyToKeepUp"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.player addObserver:self
                  forKeyPath:@"timeControlStatus"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.player addObserver:self
                  forKeyPath:@"reasonForWaitingToPlay"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    self.timeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        
        NSLog(@"(BellAVPlayerTracker) Time Observer = %f , rate = %f , duration = %f", CMTimeGetSeconds(time), self.player.rate, CMTimeGetSeconds(self.player.currentItem.duration));
        
        // If duration is NaN, then is live streaming. Otherwise is VoD.
        self.isLive = isnan(CMTimeGetSeconds(self.player.currentItem.duration));
        
        if (self.player.rate == 1.0) {
            [self goStart];
            [self goBufferEnd];
            [self goResume];
        }
        else if (self.player.rate == 0.0) {
            [self goPause];
        }
    }];
    
    [self sendPlayerReady];
}

// KVO observer method
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    NSLog(@"(BellAVPlayerTracker) Observed keyPath = %@ , object = %@ , change = %@ , context = %@", keyPath, object, change, context);
    
    if ([keyPath isEqualToString:@"currentItem.playbackBufferEmpty"]) {
        if (!self.isBuffering && self.isPaused && self.player.rate == 0.0) {
            [self goSeekStart];
        }
        [self goBufferStart];
    }
    else if ([keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        [self goRequest];
        [self goBufferEnd];
    }
}

- (void)itemTimeJumpedNotification:(NSNotification *)notification {
    NSLog(@"(BellAVPlayerTracker) Time Jumped! = %f", CMTimeGetSeconds(self.player.currentItem.currentTime));
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    NSLog(@"(BellAVPlayerTracker) Did Play To End");
    [self goEnd];
}

#pragma mark - Events senders

- (BOOL)goRequest {
    if (!self.didRequest) {
        [self sendRequest];
        self.didRequest = YES;
        self.didEnd = NO;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goStart {
    if (self.didRequest && !self.didStart) {
        [self sendStart];
        self.didStart = YES;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goPause {
    if (!self.isPaused) {
        [self sendPause];
        self.isPaused = YES;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goResume {
    if (self.isPaused) {
        [self goSeekEnd];
        [self sendResume];
        self.isPaused = NO;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goBufferStart {
    if (!self.isBuffering) {
        [self sendBufferStart];
        self.isBuffering = YES;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goBufferEnd {
    if (self.isBuffering) {
        [self sendBufferEnd];
        self.isBuffering = NO;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goSeekStart {
    if (!self.isSeeking) {
        [self sendSeekStart];
        self.isSeeking = YES;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goSeekEnd {
    if (self.isSeeking) {
        [self sendSeekEnd];
        self.isSeeking = NO;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goEnd {
    if (!self.didEnd) {
        self.didEnd = YES;
        return YES;
    }
    else {
        return NO;
    }
}

@end
