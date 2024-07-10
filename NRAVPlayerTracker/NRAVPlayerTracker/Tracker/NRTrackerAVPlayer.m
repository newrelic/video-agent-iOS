//
//  NRTrackerAVPlayer.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/08/2020.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import "NRTrackerAVPlayer.h"

#define TRACKER_TIME_EVENT 1.5

@import AVKit;

@interface NRTrackerAVPlayer ()

// AVPlayer weak references
@property (nonatomic, weak) AVPlayer *playerInstance;
@property (nonatomic) id timeObserver;
@property (nonatomic) BOOL isLive;
@property (nonatomic) float lastRenditionHeight;
@property (nonatomic) float lastRenditionWidth;
@property (nonatomic) Float64 lastTrackerTimeEvent;
@property (nonatomic) NSString *renditionChangeShift;

@end

@implementation NRTrackerAVPlayer

- (instancetype)initWithAVPlayer:(AVPlayer *)player {
    if (self = [super init]) {
        [self setPlayer:player];
    }
    return self;
}

- (void)setPlayer:(id)player {
    [super setPlayer:player];
    self.playerInstance = player;
    [self registerListeners];
}

- (void)unregisterListeners {
    [super unregisterListeners];
    
    AV_LOG(@"AVPlayer Unregister Listeners");
    
    // Unregister observers
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemTimeJumpedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemFailedToPlayToEndTimeNotification object:nil];
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"status"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"rate"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"currentItem.status"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"currentItem.playbackBufferEmpty"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"currentItem.playbackBufferFull"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"timeControlStatus"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"reasonForWaitingToPlay"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeObserver:self forKeyPath:@"currentItem"];
    }
    @catch (id e) {}
    
    @try {
        [self.state removeObserver:self forKeyPath:@"isUserSeeking"];
    }
    @catch (id e) {}
    
    @try {
        [self.playerInstance removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    @catch(id e) {}
    
    self.isLive = NO;
    
    self.lastRenditionHeight = 0;
    self.lastRenditionWidth = 0;
    self.lastTrackerTimeEvent = 0;
}

- (void)registerListeners {
    [super registerListeners];
    
    AV_LOG(@"AVPlayer Register Listeners");

    // Register observers
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemTimeJumpedNotification:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemFailedToPlayToEndTimeNotification:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:nil];

    [self.playerInstance addObserver:self
                  forKeyPath:@"status"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"rate"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"currentItem.status"
                     options:(NSKeyValueObservingOptionNew)
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"currentItem.playbackBufferEmpty"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"currentItem.playbackBufferFull"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];

    [self.playerInstance addObserver:self
                  forKeyPath:@"currentItem.playbackLikelyToKeepUp"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"timeControlStatus"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"reasonForWaitingToPlay"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.playerInstance addObserver:self
                  forKeyPath:@"currentItem"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    [self.state addObserver:self
                  forKeyPath:@"isUserSeeking"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    self.timeObserver =
    [self.playerInstance addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        
        AV_LOG(@"(AVPlayerTracker) Time Observer = %f , rate = %f , duration = %f", CMTimeGetSeconds(time), self.playerInstance.rate, CMTimeGetSeconds(self.playerInstance.currentItem.duration));
        
        // Check various state changes periodically
        [self periodicVideoStateCheck];
        
        // If duration is NaN, then is live streaming. Otherwise is VoD.
        self.isLive = isnan(CMTimeGetSeconds(self.playerInstance.currentItem.duration));
        
        if (self.playerInstance.rate > 0.0) {
            [self sendStart];
            [self sendBufferEnd];
            [self sendResume];
        }
        else if (self.playerInstance.rate == 0.0) {
            if ([self readyToEnd]) {
                [self sendEnd];
            }
            else {
                [self sendPause];
            }
        }
    }];
}

// KVO observer method
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    AV_LOG(@"(AVPlayerTracker) Observed keyPath = %@ , object = %@ , change = %@ , context = %@", keyPath, object, change, context);
    // User seek event sent by the integrators
    if ([keyPath isEqualToString:@"isUserSeeking"]) {
        if (self.state.isUserSeeking) {
            [self sendSeekStart];
        }
    }
    else if ([keyPath isEqualToString:@"currentItem.playbackBufferEmpty"] && self.state.isSeeking && self.state.isPaused) {
        [self sendBufferStart];
    }
    else if ([keyPath isEqualToString:@"currentItem.playbackBufferFull"] && self.state.isSeeking && self.state.isPaused) {
        [self sendBufferEnd];
        [self sendSeekEnd];
    }
    else if ([keyPath isEqualToString:@"currentItem.playbackLikelyToKeepUp"]) {
        [self sendRequest];

        if (self.state.isSeeking && self.state.isPaused && self.playerInstance.currentItem.playbackLikelyToKeepUp) {
            [self sendBufferEnd];
            [self sendSeekEnd];
        }
    }
    else if ([keyPath isEqualToString:@"status"]) {
        if (self.playerInstance.status == AVPlayerItemStatusReadyToPlay) {
            [self sendRequest];
        }
    }
    else if ([keyPath isEqualToString:@"currentItem.status"]) {
        if (self.playerInstance.currentItem.status == AVPlayerItemStatusFailed) {
            AV_LOG(@"(AVPlayerTracker) Error While Playing = %@", self.playerInstance.currentItem.error);
            
            if (self.playerInstance.currentItem.error) {
                [self sendError:self.playerInstance.currentItem.error];
            }
            else {
                [self sendError:nil];
            }
        }
    }
    else if ([keyPath isEqualToString:@"currentItem"]) {
        if (self.playerInstance.currentItem != nil) {
            AV_LOG(@"(AVPlayerTracker) New Video Session!");
            // goNext
            [self sendEnd];
        }
    }
    else if ([keyPath isEqualToString:@"timeControlStatus"]) {
        if (@available(iOS 10.0, *)) {
            if (self.playerInstance.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate) {
                [self sendBufferStart];
            }
            else {
                [self sendBufferEnd];
                [self sendSeekEnd];
            }
        } else {
            // Fallback on earlier versions
        }
    }
    else if ([keyPath isEqualToString:@"currentItem.playbackBufferFull"]) {
        // Sometimes when we seek to the end (using bar or jump button) the "AVPlayerItemDidPlayToEndTimeNotification" is not sent. So check if we reached the end and force the event.
        if ([self getDuration].integerValue > 0) {
            if ([self getPlayhead].integerValue > [self getDuration].integerValue - 10) {
                if (!self.state.isPaused && [self getPlayrate].integerValue == 0) {
                    [self sendEnd];
                }
            }
        }
    }
}

- (void)itemTimeJumpedNotification:(NSNotification *)notification {
    AV_LOG(@"(AVPlayerTracker) Time Jumped! = %f", CMTimeGetSeconds(self.playerInstance.currentItem.currentTime));
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    AV_LOG(@"(AVPlayerTracker) Did Play To End");
    if ([self readyToEnd]) {
        [self sendEnd];
    }
}

- (void)itemFailedToPlayToEndTimeNotification:(NSNotification *)notification {
    NSError *error = notification.userInfo[AVPlayerItemFailedToPlayToEndTimeErrorKey];
    [self sendError:error];
}

- (BOOL)readyToEnd {
    if (CMTimeGetSeconds(self.playerInstance.currentItem.currentTime) > CMTimeGetSeconds(self.playerInstance.currentItem.duration) - 0.6) {
        return YES;
    }
    else {
        return NO;
    }
}

- (void)periodicVideoStateCheck {
    if (self.lastTrackerTimeEvent == 0) {
        self.lastTrackerTimeEvent = CMTimeGetSeconds(self.playerInstance.currentItem.currentTime);
        [self checkRenditionChange];
    }
    else {
        if (CMTimeGetSeconds(self.playerInstance.currentItem.currentTime) - self.lastTrackerTimeEvent > TRACKER_TIME_EVENT) {
            self.lastTrackerTimeEvent = CMTimeGetSeconds(self.playerInstance.currentItem.currentTime);
            [self checkRenditionChange];
        }
    }
}

- (void)checkRenditionChange {
    if (self.lastRenditionWidth == 0 || self.lastRenditionHeight == 0) {
        self.lastRenditionHeight = [self getRenditionHeight].floatValue;
        self.lastRenditionWidth = [self getRenditionWidth].floatValue;
    }
    else {
        float currentRenditionHeight =  [self getRenditionHeight].floatValue;
        float currentRenditionWidth =  [self getRenditionWidth].floatValue;
        float currentMul = currentRenditionWidth * currentRenditionHeight;
        float lastMul = self.lastRenditionWidth * self.lastRenditionHeight;
        
        if (currentMul != lastMul) {
            AV_LOG(@"(AVPlayerTracker) RESOLUTION CHANGED, H = %f, W = %f", currentRenditionHeight, currentRenditionWidth);
            
            if (currentMul > lastMul) {
                self.renditionChangeShift = @"up";
            }
            else {
                self.renditionChangeShift = @"down";
            }
            
            [self sendRenditionChange];
            
            self.lastRenditionHeight = currentRenditionHeight;
            self.lastRenditionWidth = currentRenditionWidth;
        }
    }
}

- (NSMutableDictionary *)getAttributes:(NSString *)action attributes:(NSDictionary *)attributes {
    NSMutableDictionary *attr = [super getAttributes:action attributes:attributes];
    
    // Implement getter for "playhead"
    if (self.state.isAd) {
        [attr setObject:[self getPlayrate] forKey:@"adPlayrate"];
    }
    else {
        [attr setObject:[self getPlayrate] forKey:@"contentPlayrate"];
    }
    
    if ([action isEqual:CONTENT_RENDITION_CHANGE] || [action isEqual:AD_RENDITION_CHANGE]) {
        [attr setObject:self.renditionChangeShift forKey:@"shift"];
    }
    
    return attr;
}

#pragma mark - Attribute getters

- (NSString *)getTrackerName {
    return @"AVPlayerTracker";
}

- (NSString *)getTrackerVersion {
    return @"2.0.2";
}

- (NSString *)getPlayerVersion {
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)getPlayerName {
    return @"avplayer";
}

- (NSNumber *)getBitrate {
    AVPlayerItemAccessLogEvent *event = [self.playerInstance.currentItem.accessLog.events lastObject];
    return @(event.indicatedBitrate);
}

- (NSNumber *)getRenditionWidth {
    return @(self.playerInstance.currentItem.presentationSize.width);
}

- (NSNumber *)getRenditionHeight {
    return @(self.playerInstance.currentItem.presentationSize.height);
}

- (NSNumber *)getDuration {
    Float64 duration = CMTimeGetSeconds(self.playerInstance.currentItem.duration);
    if (isnan(duration)) {
        return @0;
    }
    else {
        return @(duration * 1000.0f);
    }
}

- (NSNumber *)getPlayhead {
    Float64 pos = CMTimeGetSeconds(self.playerInstance.currentItem.currentTime);
    if (isnan(pos)) {
        return @0;
    }
    else {
        return @(pos * 1000.0f);
    }
}

- (NSString *)getSrc {
    AVAsset *currentPlayerAsset = self.playerInstance.currentItem.asset;
    if (![currentPlayerAsset isKindOfClass:AVURLAsset.class]) return [super getSrc];
    return [[(AVURLAsset *)currentPlayerAsset URL] absoluteString];
}

- (NSNumber *)getPlayrate {
    return @(self.playerInstance.rate);
}

- (NSNumber *)getFps {
    AVAsset *asset = self.playerInstance.currentItem.asset;
    if (asset) {
        NSError *error;
        AVKeyValueStatus kvostatus = [asset statusOfValueForKey:@"tracks" error:&error];

        if (kvostatus != AVKeyValueStatusLoaded) {
            return (NSNumber *)[NSNull null];
        }
        
        AVAssetTrack *videoATrack = [[asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
        if (videoATrack) {
            return @(videoATrack.nominalFrameRate);
        }
    }
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getIsLive {
    return @(self.isLive);
}

- (NSNumber *)getIsMuted {
    return @(self.playerInstance.muted);
}

#pragma mark - Overwrite senders

- (void)sendEnd {
    //Make sure we close the previous blocks
    [self sendBufferEnd];
    [self sendSeekEnd];
    [self sendResume];
    // Send END
    [super sendEnd];
    
    AV_LOG(@"(AVPlayerTracker) sendEnd");
}

- (void)sendResume {
    //Make sure we close the previous blocks
    // Send RESUME
    [super sendResume];
    
    AV_LOG(@"(AVPlayerTracker) sendResume");
}

@end
