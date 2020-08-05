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
    
    NSLog(@"Tracker Reset");
    
    // Unregister observers
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemTimeJumpedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    @try {
        [self.player removeObserver:self forKeyPath:@"status"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"rate"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"currentItem.status"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"currentItem.playbackBufferEmpty"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"currentItem.playbackBufferFull"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"timeControlStatus"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeObserver:self forKeyPath:@"reasonForWaitingToPlay"];
    }
    @catch (id e) {}
    
    @try {
        [self.player removeTimeObserver:self.timeObserver];
    }
    @catch(id e) {}
    
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
    
    NSLog(@"Tracker Setup");

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
            if ([self readyToEnd]) {
                [self goEnd];
            }
            else {
                [self goPause];
            }
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
    if ([self readyToEnd]) {
        [self goEnd];
    }
}

- (BOOL)readyToEnd {
    if (CMTimeGetSeconds(self.player.currentItem.currentTime) > CMTimeGetSeconds(self.player.currentItem.duration) - 0.6) {
        return YES;
    }
    else {
        return NO;
    }
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
    if (self.didEnd) return NO;
    
    if (self.didStart && !self.isPaused) {
        [self sendPause];
        self.isPaused = YES;
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)goResume {
    if (self.didEnd) return NO;
    
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
    if (self.didEnd) return NO;
    
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
    if (self.didEnd) return NO;
    
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
    if (self.didEnd) return NO;
    
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
    if (self.didEnd) return NO;
    
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
        if (self.isBuffering) {
            [self goBufferEnd];
        }
        if (self.isSeeking) {
            [self goSeekEnd];
        }
        if (self.isPaused) {
            [self goResume];
        }
        [self sendEnd];
        self.didEnd = YES;
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark - ContentsTracker getters

- (NSString *)getTrackerName {
    return @"avplayertracker";
}

- (NSString *)getTrackerVersion {
    return @"0.0.0";
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
    Float64 pos = CMTimeGetSeconds(self.player.currentItem.currentTime);
    if (isnan(pos)) {
        return @0;
    }
    else {
        return @(pos * 1000.0f);
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
    AVAsset *asset = self.player.currentItem.asset;
    if (asset) {
        NSError *error;
        AVKeyValueStatus kvostatus = [asset statusOfValueForKey:@"tracks" error:&error];

        if (kvostatus != AVKeyValueStatusLoaded) {
            return nil;
        }
        
        AVAssetTrack *videoATrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
        if (videoATrack) {
            return @(videoATrack.nominalFrameRate);
        }
    }
    return nil;
}

- (NSNumber *)getIsLive {
    return @(self.isLive);
}

- (NSNumber *)getIsMuted {
    return @(self.player.muted);
}

@end
