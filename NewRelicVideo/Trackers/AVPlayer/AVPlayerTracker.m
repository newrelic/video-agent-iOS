//
//  AVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"
#import "EventDefs.h"

@import AVKit;

// KNOWN ISSUES:
// * It sends a PAUSE right before SEEK_START and a RESUME right after SEEK_END.
// * If seeked while paused, the SEEK_END is sent only when user resumes the video.

@interface AVPlayerTracker ()

// AVPlayer weak references
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayerViewController *playerViewController;

@property (nonatomic) int numZeroRates;
@property (nonatomic) double estimatedBitrate;
@property (nonatomic) BOOL isAutoPlayed;
@property (nonatomic) BOOL isFullScreen;
@property (nonatomic) BOOL firstFrameHappend;
@property (nonatomic) int numTimeouts;
@property (nonatomic) id timeObserver;

@end

@implementation AVPlayerTracker

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
    self.numZeroRates = 0;
    self.estimatedBitrate = 0;
    self.firstFrameHappend = NO;
    self.numTimeouts = 0;
    
    AV_LOG(@"AVPLAYER CURRENT ITEM (reset) = %@", self.player.currentItem);
    
    if (self.timeObserver && self.player) {
        @try {
            [self.player removeTimeObserver:self.timeObserver];
        }
        @catch(id e) {}
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemTimeJumpedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    
    AV_LOG(@"Unregistered AVPlayerItemTimeJumpedNotification and AVPlayerItemDidPlayToEndTimeNotification");

    [self unregisterAllEvents];
    
    @try {
        [self.player removeObserver:self forKeyPath:@"rate"];
    }
    @catch (id e) {}
    
    AV_LOG(@"Unregistered Player Rate");
    
    if (self.playerViewController) {
        @try {
            [self.playerViewController removeObserver:self forKeyPath:@"videoBounds"];
        }
        @catch (id e) {}
        
        AV_LOG(@"Unregistered PlayerController videoBounds");
    }
}

- (void)setup {
    
    [super setup];
    
    [self setupBitrateOptions];
    
    // Register periodic time observer (an event every 1/2 seconds)
    
    self.timeObserver =
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        
        //AV_LOG(@"Time Observer = %f , rate = %f", CMTimeGetSeconds(time), self.player.rate);
        
        if (!self.player.currentItem) {
            AV_LOG(@"Time observer event but currentIntem is Nil, aborting");
            return;
        }
        
        // Seeking
        if (self.player.rate != 1) {
            self.numZeroRates ++;
            
            if (self.numZeroRates == 2) {
                [self sendSeekStart];
            }
        }
        else {
            if (self.numZeroRates > 2) {
                [self sendSeekEnd];
                if (self.state == TrackerStatePaused) {
                    [self sendResume];      // We send Resume because the Pause is sent before seek start and we neet to put the state machine in a "normal" state.
                }
            }
            self.numZeroRates = 0;
        }
        
        // Start
        if (!self.firstFrameHappend) {
            AV_LOG(@"First time observer event -> sendStart");
            AV_LOG(@"Time Observer = %f , rate = %f , currentItem = %@", CMTimeGetSeconds(time), self.player.rate, self.player.currentItem);
            
            // NOTE: with AVPlayer playlists, the request event only happens for the first video, we need manually send it before start.
            if (self.state == TrackerStateStopped) {
                [self sendRequest];
            }
            
            if (self.state == TrackerStateBuffering) {
                [self sendBufferEnd];
            }
            
            [self sendStart];
            
            self.firstFrameHappend = YES;
        }
    }];
    
    AV_LOG(@"AVPLAYER CURRENT ITEM (setup) = %@", self.player.currentItem);
    
    // Register NSNotification listeners
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemTimeJumpedNotification:)
                                                 name:AVPlayerItemTimeJumpedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(itemDidPlayToEndTimeNotification:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
    AV_LOG(@"Registered AVPlayerItemTimeJumpedNotification and AVPlayerItemDidPlayToEndTimeNotification");
    
    // Register currentItem KVO's
    
    [self registerAllEvents];
    
    [self.player addObserver:self forKeyPath:@"rate"
                     options:NSKeyValueObservingOptionNew
                     context:NULL];
    
    AV_LOG(@"Registered Player Rate");
    
    if (self.playerViewController) {
        [self.playerViewController addObserver:self forKeyPath:@"videoBounds"
                                       options:NSKeyValueObservingOptionNew
                                       context:NULL];
        
        AV_LOG(@"Registered PlayerController videoBounds");
    }
    
    [self sendPlayerReady];
}

- (void)registerAllEvents {
    if ([self.player isKindOfClass:[AVQueuePlayer class]]) {
        AV_LOG(@"Register observers for multiple items");
        for (AVPlayerItem *item in ((AVQueuePlayer *)self.player).items) {
            AV_LOG(@" > item = %@", item);
            [self registerObserversForItem:item];
        }
    }
    else {
        AV_LOG(@"Register observers for one item = %@", self.player.currentItem);
        [self registerObserversForItem:self.player.currentItem];
    }
}

- (void)unregisterAllEvents {
    if ([self.player isKindOfClass:[AVQueuePlayer class]]) {
        AV_LOG(@"Unregister observers for multiple items");
        for (AVPlayerItem *item in ((AVQueuePlayer *)self.player).items) {
            AV_LOG(@" > item = %@", item);
            [self unregisterObserversForItem:item];
        }
    }
    else {
        AV_LOG(@"Unregister observers for one item = %@", self.player.currentItem);
        [self unregisterObserversForItem:self.player.currentItem];
    }
}

- (void)registerObserversForItem:(AVPlayerItem *)item {
    
    [item addObserver:self forKeyPath:@"playbackBufferEmpty"
              options:NSKeyValueObservingOptionNew
              context:NULL];
    
    AV_LOG(@"Registered playbackBufferEmpty for item");
    
    [item addObserver:self forKeyPath:@"playbackBufferFull"
              options:NSKeyValueObservingOptionNew
              context:NULL];
    
    AV_LOG(@"Registered playbackBufferFull for item");
    
    [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp"
              options:NSKeyValueObservingOptionNew
              context:NULL];
    
    AV_LOG(@"Registered playbackLikelyToKeepUp for item");
}

- (void)unregisterObserversForItem:(AVPlayerItem *)item {
    AV_LOG(@"Unregister observers for item");
    @try {
        [item removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    }
    @catch (id e) {}
    AV_LOG(@"Unregistered playbackBufferEmpty for item");
    @try {
        [item removeObserver:self forKeyPath:@"playbackBufferFull"];
    }
    @catch (id e) {}
    AV_LOG(@"Unregistered playbackBufferFull for item");
    @try {
        [item removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    }
    @catch (id e) {}
    AV_LOG(@"Unregistered playbackLikelyToKeepUp for item");
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
        AV_LOG(@"status == AVPlayerItemStatusReadyToPlay");
        
        if (self.state == TrackerStateBuffering) {
            AV_LOG(@"sendBufferEnd");
            [self sendBufferEnd];
        }
        
        if (self.state == TrackerStateStarting) {
            AV_LOG(@"sendStart");
            [self sendStart];
        }
    }
    else if (p.status == AVPlayerItemStatusFailed) {
        AV_LOG(@"#### ERROR WHILE PLAYING");
        if (p.error) {
            [self sendError:p.error.localizedDescription];
        }
        else {
            [self sendError:@"<UNKNOWN>"];
        }
    }
    else if (p.status == AVPlayerItemStatusUnknown) {
        AV_LOG(@"status == AVPlayerItemStatusUnknown");
    }
}

- (void)itemDidPlayToEndTimeNotification:(NSNotification *)notification {
    AV_LOG(@"ItemDidPlayToEndTimeNotification");
    AV_LOG(@"#### FINISHED PLAYING");
    
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
            AV_LOG(@"Video Rate Log: Stopped Playback");
            
            if (self.player.error != nil) {
                AV_LOG(@"  -> Playback Failed");
                [self sendError:self.player.error.localizedDescription];
            }
            else if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
                AV_LOG(@"  -> Playback Reached the End");
            }
            else if (!self.player.currentItem.playbackLikelyToKeepUp) {
                // NOTE: it happens when bad connection and user seeks back and forth and doesn't give time enought for buffering
                AV_LOG(@"  -> Playback Waiting Data");
                if (self.state == TrackerStateStarting) {
                    [self sendBufferStart];
                }
            }
            else {
                // Click Pause
                if (self.state == TrackerStateSeeking) {
                    [self sendSeekEnd];
                }
                else {
                    [self sendPause];
                }
            }
        }
        else if (rate == 1.0) {
            AV_LOG(@"Video Rate Log: Normal Playback");
            
            // Click Play, may be a Request or a Resume
            if ([self getPlayhead].doubleValue == 0) {
                [self sendRequest];
            }
            else {
                if (self.state == TrackerStateSeeking) {
                    // In case we receive a seek_start without seek_end
                    [self sendSeekEnd];
                    [self sendResume];
                }
                else if (self.state == TrackerStatePaused) {
                    [self sendResume];
                }
            }
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
    
    // AVPlayerViewController KVOs
    if ([keyPath isEqualToString:@"videoBounds"]) {
        // NOTE: in tvOS we just ignore the bounds
        //AV_LOG(@"VIDEO BOUNDS CHANGE = %@", NSStringFromCGRect(self.playerViewController.videoBounds));
        AV_LOG(@"SCREEN BOUNDS = %@", NSStringFromCGRect([UIScreen mainScreen].bounds));
        
        CGRect newBounds = [change[NSKeyValueChangeNewKey] CGRectValue];
        
        if ([UIScreen mainScreen].bounds.size.height == newBounds.size.height || [UIScreen mainScreen].bounds.size.width == newBounds.size.width) {
            AV_LOG(@"FULL SCREEN");
            self.isFullScreen = YES;
        }
        else {
            AV_LOG(@"NO FULL SCREEN");
            self.isFullScreen = NO;
        }
    }
}

// TODO: do this with an indep timer, not trackerTimerEvent
// Time Evenent, called by a timer in the superclass, every OBSERVATION_TIME seconds
/*
- (void)trackerTimeEvent {
    [super trackerTimeEvent];
    
    if (CMTimeGetSeconds(self.player.currentTime) >= CMTimeGetSeconds(self.player.currentItem.duration)) {
        if (self.numTimeouts < 1) {
            AV_LOG(@"Video ended? let's wait for another event to trigger a timeout.");
            self.numTimeouts ++;
        }
        else {
            AV_LOG(@"Timeout, video ended but no event received.");
            [self sendEnd];
            self.numTimeouts = 0;
        }
    }

    [self setupBitrateOptions];
}
 */

- (void)setupBitrateOptions {
    // Calc estimated bitrate and send a rendition change event if it changed
    AVPlayerItemAccessLogEvent *event = [self.player.currentItem.accessLog.events lastObject];
    double numberOfBitsTransferred = (event.numberOfBytesTransferred * 8);
    double newEstimatedBitrate = numberOfBitsTransferred / event.segmentsDownloadedDuration;
    
    if (self.estimatedBitrate == 0) {
        self.estimatedBitrate = newEstimatedBitrate;
    }
    else if (fabs(self.estimatedBitrate - newEstimatedBitrate) >  self.estimatedBitrate * 0.01) {
        // If bitrate changed more than 1%, rendition change event
        
        /*
         TODO:
         - Move RENDITION_CHANGE's "shift" attribute to Tracker. We could add a argument with bitrate and compare with last recorded one.
         */
        
        if (self.estimatedBitrate - newEstimatedBitrate > 0) {
            // Lower rendition
            [self setOptionKey:@"shift" value:@"down" forAction:CONTENT_RENDITION_CHANGE];
        }
        else {
            // Higher rendition
            [self setOptionKey:@"shift" value:@"up" forAction:CONTENT_RENDITION_CHANGE];
        }
        
        [self sendRenditionChange];
        self.estimatedBitrate = newEstimatedBitrate;
        
        AV_LOG(@"New Rendition Change = %d", newEstimatedBitrate);
    }
}

- (void)sendEnd {
    [super sendEnd];
    self.isAutoPlayed = NO;
    self.firstFrameHappend = NO;
    self.numTimeouts = 0;
    
    // unregister all to avoid crash in iOS10
    [self unregisterAllEvents];
}

- (void)sendBufferStart {
    if (self.state != TrackerStateBuffering) {
        [super sendBufferStart];
    }
}

- (void)sendRequest {
    [self unregisterAllEvents];
    [self registerAllEvents];
    [super sendRequest];
}

#pragma mark - ContentsTracker getters

- (NSString *)getTrackerName {
    return @"avplayertracker";
}

- (NSString *)getTrackerVersion {
    return @PRODUCT_VERSION_STR;
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

- (NSNumber *)getIsMuted {
    return @(self.player.muted);
}

- (NSNumber *)getIsAutoplayed {
    return @(self.isAutoPlayed);
}

- (void)setIsAutoplayed:(NSNumber *)state {
    self.isAutoPlayed = state.boolValue;
}

- (NSNumber *)getIsFullscreen {
    return @(self.isFullScreen);
}

#pragma mark - Optonal methods

- (void)stop {
    if (self.player.currentItem != nil && self.state != TrackerStateStopped) {
        [self sendEnd];
        [self.player pause];
    }
}

@end
