//
//  AVPlayerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"
#import "EventDefs.h"

// KNOWN ISSUES:
// * It sends a PAUSE right before SEEK_START and a RESUME right after SEEK_END.
// * If seeked while paused, the SEEK_END is sent only when user resumes the video.
// * While video is buffering, seeking doesn't produce time observer events with rate == 0.
// * Sometimes, when seeking to a part of the video not in buffer, we don't get BUFFER events, but a SEEK_END + RESUME when it finished buffering and starts playing again.

@import AVKit;

@interface AVPlayerTracker ()

// AVPlayer weak references
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayerViewController *playerViewController;

@property (nonatomic) int numZeroRates;
@property (nonatomic) double estimatedBitrate;
@property (nonatomic) BOOL isAutoPlayed;
@property (nonatomic) BOOL isFullScreen;
@property (nonatomic) NSString *videoID;

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
}

- (void)setup {
    
    [super setup];
    
    [self setupBitrateOptions];
    
    // Register periodic time observer (an event every 1/2 seconds)
    
    [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 2) queue:NULL usingBlock:^(CMTime time) {
        
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
    
    if (self.playerViewController) {
        [self.playerViewController addObserver:self forKeyPath:@"videoBounds"
                                       options:NSKeyValueObservingOptionNew
                                       context:NULL];
        
    }
    
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
    else if (p.status == AVPlayerItemStatusUnknown) {
        [self sendPlayerReady];
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
            
            // Click Play, may be a Request or a Resume
            if ([self getPlayhead].doubleValue == 0) {
                [self sendRequest];
            }
            else {
                [self sendResume];
            }
            
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
    
    // AVPlayerViewController KVOs
    if ([keyPath isEqualToString:@"videoBounds"]) {
        AV_LOG(@"VIDEO BOUNDS CHANGE = %@", NSStringFromCGRect(self.playerViewController.videoBounds));
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

// Time Evenent, called by a timer in the superclass, every OBSERVATION_TIME seconds
- (void)trackerTimeEvent {
    [super trackerTimeEvent];
    
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
        // If bitrate changed more than 1%, rendition change event
        
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
    self.videoID = nil;
    
    // TEST: custom action
    //[self sendCustomAction:@"MY_ACTION" attr:@{@"attr0": @"val0"}];
}

#pragma mark - ContentsTracker getters

- (NSString *)getTrackerName {
    return @"avplayertracker";
}

- (NSString *)getTrackerVersion {
    return @"0.1";
}

- (NSString *)getPlayerVersion {
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)getPlayerName {
    return @"avplayer";
}

- (NSString *)getVideoId {
    if (!self.videoID) {
        NSString *src = [self getSrc];
        __block long long val = 0;
        __block long long lastChar = 0;
        [src enumerateSubstringsInRange:NSMakeRange(0, src.length)
                                options:NSStringEnumerationByComposedCharacterSequences
                             usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                 long long currChar = [substring characterAtIndex:0];
                                 val += (currChar << (lastChar / 8)) + currChar;
                                 lastChar = currChar;
                             }];
        self.videoID = @(val).stringValue;
    }
    
    return self.videoID;
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

- (NSNumber *)getIsMutted {
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

@end
