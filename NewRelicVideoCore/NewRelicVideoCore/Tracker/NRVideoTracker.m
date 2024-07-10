//
//  NRVideoTracker.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 14/12/2020.
//

#import "NRVideoTracker.h"
#import "NRVideoDefs.h"
#import "NRVideoLog.h"
#import "NRTimeSince.h"
#import <CommonCrypto/CommonDigest.h>

@interface NRTracker ()

@property (nonatomic, weak) NRTracker *linkedTracker;

@end

@interface NRVideoTracker ()

@property (nonatomic) NRTrackerState *state;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) int heartbeatTimeInterval;
@property (nonatomic) int numberOfVideos;
@property (nonatomic) int numberOfAds;
@property (nonatomic) int numberOfErrors;
@property (nonatomic) NSString *viewSessionId;
@property (nonatomic) int viewIdIndex;
@property (nonatomic) int adBreakIdIndex;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) long totalPlaytime;
@property (nonatomic) long totalAdPlaytime;
@property (nonatomic) long playtimeSinceLastEvent;
@property (nonatomic) NSString *bufferType;
@property (nonatomic, weak) NRTimeSince *lastAdTimeSince;

@end

@implementation NRVideoTracker

- (instancetype)init {
    if (self = [super init]) {
        self.state = [[NRTrackerState alloc] init];
        [self setHeartbeatTime:30];
        self.numberOfAds = 0;
        self.numberOfErrors = 0;
        self.numberOfVideos = 0;
        self.viewIdIndex = 0;
        self.adBreakIdIndex = 0;
        self.viewSessionId = [NSString stringWithFormat:@"%@-%ld%d", [self getAgentSession], (long)[[NSDate date] timeIntervalSince1970], arc4random_uniform(10000)];
        self.playtimeSinceLastEventTimestamp = 0;
        self.totalPlaytime = 0;
        self.totalAdPlaytime = 0;
        self.playtimeSinceLastEvent = 0;
        self.bufferType = nil;
        AV_LOG(@"Init NSVideoTracker");
    }
    return self;
}

- (void)dealloc {
    AV_LOG(@"Dealloc NSVideoTracker");
}

- (void)dispose {
    [super dispose];
    [self stopHeartbeat];
}

- (void)setPlayer:(id)player {
    [self sendEvent:PLAYER_READY];
    [self.state goPlayerReady];
}

- (void)startHeartbeat {
    if (self.heartbeatTimeInterval == 0) return;
    
    if (!self.timer) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)self.heartbeatTimeInterval
                                                      target:self
                                                    selector:@selector(heartbeatTimerHandler:)
                                                    userInfo:nil
                                                     repeats:YES];
    }
}

- (void)stopHeartbeat {
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = nil;
}

- (void)setHeartbeatTime:(int)seconds {
    if (seconds >= 1) {
        self.heartbeatTimeInterval = seconds;
        if (self.timer) {
            [self stopHeartbeat];
            [self startHeartbeat];
        }
    }
    else {
        //if < 1 disable HB
        self.heartbeatTimeInterval = 0;
    }
}

- (NSMutableDictionary *)getAttributes:(NSString *)action attributes:(NSDictionary *)attributes {
    NSMutableDictionary *attr;
    
    if (attributes) {
        attr = attributes.mutableCopy;
    } else {
        attr = @{}.mutableCopy;
    }
    
    if ([action hasSuffix:@"_BUFFER_START"] || [action hasSuffix:@"_BUFFER_END"]) {
        [attr setObject:[self getBufferType] forKey:@"bufferType"];
    }
    
    [attr setObject:[self getTrackerName] forKey:@"trackerName"];
    [attr setObject:[self getTrackerVersion] forKey:@"trackerVersion"];
    [attr setObject:[self getPlayerName] forKey:@"playerName"];
    [attr setObject:[self getPlayerVersion] forKey:@"playerVersion"];
    [attr setObject:[self getViewSession] forKey:@"viewSession"];
    [attr setObject:[self getViewId] forKey:@"viewId"];
    [attr setObject:@(self.state.isAd) forKey:@"isAd"];
    [attr setObject:@(self.numberOfAds) forKey:@"numberOfAds"];
    [attr setObject:@(self.numberOfVideos) forKey:@"numberOfVideos"];
    [attr setObject:@(self.numberOfErrors) forKey:@"numberOfErrors"];
    [attr setObject:@(self.playtimeSinceLastEvent) forKey:@"playtimeSinceLastEvent"];
    [attr setObject:@(self.totalPlaytime) forKey:@"totalPlaytime"];
    
    if (self.state.isAd) {
        [attr setObject:[self getTitle] forKey:@"adTitle"];
        [attr setObject:[self getBitrate] forKey:@"adBitrate"];
        [attr setObject:[self getRenditionBitrate] forKey:@"adRenditionBitrate"];
        [attr setObject:[self getRenditionWidth] forKey:@"adRenditionWidth"];
        [attr setObject:[self getRenditionHeight] forKey:@"adRenditionHeight"];
        [attr setObject:[self getDuration] forKey:@"adDuration"];
        [attr setObject:[self getPlayhead] forKey:@"adPlayhead"];
        [attr setObject:[self getLanguage] forKey:@"adLanguage"];
        [attr setObject:[self getSrc] forKey:@"adSrc"];
        [attr setObject:[self getIsMuted] forKey:@"adIsMuted"];
        [attr setObject:[self getFps] forKey:@"adFps"];
        [attr setObject:[self getAdCreativeId] forKey:@"adCreativeId"];
        [attr setObject:[self getAdPosition] forKey:@"adPosition"];
        [attr setObject:[self getAdQuartile] forKey:@"adQuartile"];
        [attr setObject:[self getAdPartner] forKey:@"adPartner"];
        [attr setObject:[self getVideoId] forKey:@"adId"];
        [attr setObject:[self getAdBreakId] forKey:@"adBreakId"];
        
        if ([action hasPrefix:@"AD_BREAK_"]) {
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                long playhead = [(NRVideoTracker *)self.linkedTracker getPlayhead].longValue;
                if (playhead < 100) {
                    [attr setObject:@"pre" forKey:@"adPosition"];
                }
            }
        }
        
        if ([action isEqual:AD_BREAK_END]) {
            [attr setObject:@(self.totalAdPlaytime) forKey:@"totalAdPlaytime"];
        }
    }
    else {
        if ([action isEqual:CONTENT_START]) {
            [attr setObject:@(self.totalAdPlaytime) forKey:@"totalAdPlaytime"];
        }
        [attr setObject:[self getTitle] forKey:@"contentTitle"];
        [attr setObject:[self getBitrate] forKey:@"contentBitrate"];
        [attr setObject:[self getRenditionBitrate] forKey:@"contentRenditionBitrate"];
        [attr setObject:[self getRenditionWidth] forKey:@"contentRenditionWidth"];
        [attr setObject:[self getRenditionHeight] forKey:@"contentRenditionHeight"];
        [attr setObject:[self getDuration] forKey:@"contentDuration"];
        [attr setObject:[self getPlayhead] forKey:@"contentPlayhead"];
        [attr setObject:[self getLanguage] forKey:@"contentLanguage"];
        [attr setObject:[self getSrc] forKey:@"contentSrc"];
        [attr setObject:[self getIsMuted] forKey:@"contentIsMuted"];
        [attr setObject:[self getIsLive] forKey:@"contentIsLive"];
        [attr setObject:[self getFps] forKey:@"contentFps"];
        [attr setObject:[self getVideoId] forKey:@"contentId"];
    }
    
    attr = [super getAttributes:action attributes:attr];
    
    return attr;
}

#pragma mark - Senders

- (void)sendEvent:(NSString *)action attributes:(NSDictionary *)attributes {
    
    // Calculate playtimeSinceLastEvent and totalPlaytime
    if (self.playtimeSinceLastEventTimestamp > 0) {
        self.playtimeSinceLastEvent = (long)(1000.0f * ([[NSDate date] timeIntervalSince1970] - self.playtimeSinceLastEventTimestamp));
        self.totalPlaytime += self.playtimeSinceLastEvent;
        self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    else {
        self.playtimeSinceLastEvent = 0;
    }
    
    [super sendEvent:action attributes:attributes];
}

- (void)sendRequest {
    if ([self.state goRequest]) {
        self.playtimeSinceLastEventTimestamp = 0;
        
        if (self.state.isAd) {
            [self sendEvent:AD_REQUEST];
        }
        else {
            [self sendEvent:CONTENT_REQUEST];
        }
    }
}

- (void)sendStart {
    if ([self.state goStart]) {
        [self startHeartbeat];
        if (self.state.isAd) {
            self.numberOfAds++;
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                [(NRVideoTracker *)self.linkedTracker setNumberOfAds:self.numberOfAds];
            }
            [self sendEvent:AD_START];
        }
        else {
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                self.totalAdPlaytime = [(NRVideoTracker *)self.linkedTracker getTotalAdPlaytime].longValue;
            }
            self.numberOfVideos++;
            [self sendEvent:CONTENT_START];
        }
        self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)sendPause {
    if ([self.state goPause]) {
        if (self.state.isAd) {
            [self sendEvent:AD_PAUSE];
        }
        else {
            [self sendEvent:CONTENT_PAUSE];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendResume {
    if ([self.state goResume]) {
        if (self.state.isAd) {
            [self sendEvent:AD_RESUME];
        }
        else {
            [self sendEvent:CONTENT_RESUME];
        }
        if (!self.state.isBuffering && !self.state.isSeeking) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
    }
}

- (void)sendEnd {
    if ([self.state goEnd]) {
        if (self.state.isAd) {
            [self sendEvent:AD_END];
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                [(NRVideoTracker *)self.linkedTracker adHappened];
            }
            self.totalAdPlaytime = self.totalAdPlaytime + self.totalPlaytime;
        }
        else {
            [self sendEvent:CONTENT_END];
        }
        
        [self stopHeartbeat];
        
        self.viewIdIndex++;
        self.numberOfErrors = 0;
        self.playtimeSinceLastEventTimestamp = 0;
        self.playtimeSinceLastEvent = 0;
        self.totalPlaytime = 0;
    }
}

- (void)sendSeekStart {
    if ([self.state goSeekStart]) {
        if (self.state.isAd) {
            [self sendEvent:AD_SEEK_START];
        }
        else {
            [self sendEvent:CONTENT_SEEK_START];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendSeekEnd {
    if ([self.state goSeekEnd]) {
        if (self.state.isAd) {
            [self sendEvent:AD_SEEK_END];
        }
        else {
            [self sendEvent:CONTENT_SEEK_END];
        }
        if (!self.state.isBuffering && !self.state.isPaused) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
    }
}

- (void)sendBufferStart {
    if ([self.state goBufferStart]) {
        self.bufferType = [self calculateBufferType];
        if (self.state.isAd) {
            [self sendEvent:AD_BUFFER_START];
        }
        else {
            [self sendEvent:CONTENT_BUFFER_START];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendBufferEnd {
    if ([self.state goBufferEnd]) {
        if (!self.bufferType) {
            self.bufferType = [self calculateBufferType];
        }
        if (self.state.isAd) {
            [self sendEvent:AD_BUFFER_END];
        }
        else {
            [self sendEvent:CONTENT_BUFFER_END];
        }
        if (!self.state.isSeeking && !self.state.isPaused) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
        self.bufferType = nil;
    }
}

- (void)sendHeartbeat {
    if (self.state.isAd) {
        [self sendEvent:AD_HEARTBEAT];
    }
    else {
        [self sendEvent:CONTENT_HEARTBEAT];
    }
}

- (void)sendRenditionChange {
    if (self.state.isAd) {
        [self sendEvent:AD_RENDITION_CHANGE];
    }
    else {
        [self sendEvent:CONTENT_RENDITION_CHANGE];
    }
}

- (void)sendError {
    [self sendError:nil];
}

- (void)sendError:(nullable NSError *)error {
    self.numberOfErrors++;
    
    NSDictionary *errAttr = nil;
    
    if (error) {
        errAttr = @{
            @"errorMessage": error.localizedDescription,
            @"errorDomain": error.domain,
            @"errorCode": @(error.code)
        };
    }
    else {
        errAttr = @{
            @"errorMessage": [NSNull null],
            @"errorDomain": [NSNull null],
            @"errorCode": [NSNull null]
        };
    }
    
    if (self.state.isAd) {
        [self sendEvent:AD_ERROR attributes:errAttr];
    }
    else {
        [self sendEvent:CONTENT_ERROR attributes:errAttr];
    }
}

- (void)sendAdBreakStart {
    if (self.state.isAd && [self.state goAdBreakStart]) {
        self.adBreakIdIndex++;
        self.totalAdPlaytime = 0;
        [self sendEvent:AD_BREAK_START];
    }
}

- (void)sendAdBreakEnd {
    if (self.state.isAd && [self.state goAdBreakEnd]) {
        [self sendEvent:AD_BREAK_END];
    }
}

- (void)sendAdQuartile {
    if (self.state.isAd) {
        [self sendEvent:AD_QUARTILE];
    }
}

- (void)sendAdClick {
    if (self.state.isAd) {
        [self sendEvent:AD_CLICK];
    }
}

#pragma mark - Attribute Getters

- (NSNumber *)getIsAd {
    return @(self.state.isAd);
}

- (NSString *)getTrackerVersion {
    return (NSString *)[NSNull null];
}

- (NSString *)getTrackerName {
    return (NSString *)[NSNull null];
}

- (NSString *)getPlayerVersion {
    return (NSString *)[NSNull null];
}

- (NSString *)getPlayerName {
    return (NSString *)[NSNull null];
}

- (NSString *)getTitle {
    return (NSString *)[NSNull null];
}

- (NSNumber *)getBitrate {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getRenditionBitrate {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getRenditionWidth {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getRenditionHeight {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getDuration {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getPlayhead {
    return (NSNumber *)[NSNull null];
}

- (NSString *)getLanguage {
    return (NSString *)[NSNull null];
}

- (NSString *)getSrc {
    return (NSString *)[NSNull null];
}

- (NSNumber *)getIsMuted {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getFps {
    return (NSNumber *)[NSNull null];
}

- (NSNumber *)getIsLive {
    return (NSNumber *)[NSNull null];
}

- (NSString *)getAdCreativeId {
    return (NSString *)[NSNull null];
}

- (NSString *)getAdPosition {
    return (NSString *)[NSNull null];
}

- (NSNumber *)getAdQuartile {
    return (NSNumber *)[NSNull null];
}

- (NSString *)getAdPartner {
    return (NSString *)[NSNull null];
}

- (NSString *)getAdBreakId {
    return [NSString stringWithFormat:@"%@-%d", [self getViewSession], self.adBreakIdIndex];
}

- (NSNumber *)getTotalAdPlaytime {
    return @(self.totalAdPlaytime);
}

- (NSString *)getViewSession {
    // If we are an Ad tracker, we use main tracker's viewSession
    if (self.state.isAd && [self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
        return [(NRVideoTracker *)self.linkedTracker getViewSession];
    }
    else {
        return self.viewSessionId;
    }
}

- (NSString *)getViewId {
    // If we are an Ad tracker, we use main tracker's viewId
    if (self.state.isAd && [self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
        return [(NRVideoTracker *)self.linkedTracker getViewId];
    }
    else {
        return [NSString stringWithFormat:@"%@-%d", [self getViewSession], self.viewIdIndex];
    }
}

- (NSString *)getVideoId {
    NSString *src = [self getSrc];
    if ([src isEqual:[NSNull null]]) {
        src = @"";
    }
    
    const char *cStr = [src UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result );

    return [NSString stringWithFormat:
        @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
        result[0], result[1], result[2], result[3],
        result[4], result[5], result[6], result[7],
        result[8], result[9], result[10], result[11],
        result[12], result[13], result[14], result[15]
    ];
}

- (NSString *)getBufferType {
    return self.bufferType;
}

- (void)adHappened {
    // Create an NRTimeSince entry without action (won't by updated by any action) and force a "now" to set the current timestamp reference
    if (!self.lastAdTimeSince) {
        NRTimeSince *ts = [[NRTimeSince alloc] initWithAction:@"" attribute:@"timeSinceLastAd" applyTo:@"^CONTENT_[A-Z_]+$"];
        [self addTimeSinceEntry:ts];
        self.lastAdTimeSince = ts;
    }
    [self.lastAdTimeSince now];
}

- (void)generateTimeSinceTable {
    [super generateTimeSinceTable];
    
    [self addTimeSinceEntryWithAction:CONTENT_HEARTBEAT attribute:@"timeSinceLastHeartbeat" applyTo:@"^CONTENT_[A-Z_]+$"];
    [self addTimeSinceEntryWithAction:AD_HEARTBEAT attribute:@"timeSinceLastAdHeartbeat" applyTo:@"^AD_[A-Z_]+$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_REQUEST attribute:@"timeSinceRequested" applyTo:@"^CONTENT_[A-Z_]+$"];
    [self addTimeSinceEntryWithAction:AD_REQUEST attribute:@"timeSinceAdRequested" applyTo:@"^AD_[A-Z_]+$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_START attribute:@"timeSinceStarted" applyTo:@"^CONTENT_[A-Z_]+$"];
    [self addTimeSinceEntryWithAction:AD_START attribute:@"timeSinceAdStarted" applyTo:@"^AD_[A-Z_]+$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_PAUSE attribute:@"timeSincePaused" applyTo:@"^CONTENT_RESUME$"];
    [self addTimeSinceEntryWithAction:AD_PAUSE attribute:@"timeSinceAdPaused" applyTo:@"^AD_RESUME$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_RESUME attribute:@"timeSinceResumed" applyTo:@"^CONTENT_BUFFER_(START|END)$"];
    [self addTimeSinceEntryWithAction:AD_RESUME attribute:@"timeSinceAdResumed" applyTo:@"^AD_BUFFER_(START|END)$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_SEEK_START attribute:@"timeSinceSeekBegin" applyTo:@"^CONTENT_SEEK_END$"];
    [self addTimeSinceEntryWithAction:AD_SEEK_START attribute:@"timeSinceAdSeekBegin" applyTo:@"^AD_SEEK_END$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_SEEK_END attribute:@"timeSinceSeekEnd" applyTo:@"^CONTENT_BUFFER_(START|END)$"];
    [self addTimeSinceEntryWithAction:AD_SEEK_END attribute:@"timeSinceAdSeekEnd" applyTo:@"^AD_BUFFER_(START|END)$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_BUFFER_START attribute:@"timeSinceBufferBegin" applyTo:@"^CONTENT_BUFFER_END$"];
    [self addTimeSinceEntryWithAction:AD_BUFFER_START attribute:@"timeSinceAdBufferBegin" applyTo:@"^AD_BUFFER_END$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_ERROR attribute:@"timeSinceLastError" applyTo:@"^CONTENT_[A-Z_]+$"];
    [self addTimeSinceEntryWithAction:AD_ERROR attribute:@"timeSinceLastAdError" applyTo:@"^AD_[A-Z_]+$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_RENDITION_CHANGE attribute:@"timeSinceLastRenditionChange" applyTo:@"^CONTENT_RENDITION_CHANGE$"];
    [self addTimeSinceEntryWithAction:AD_RENDITION_CHANGE attribute:@"timeSinceLastAdRenditionChange" applyTo:@"^AD_RENDITION_CHANGE$"];
    
    [self addTimeSinceEntryWithAction:AD_BREAK_START attribute:@"timeSinceAdBreakBegin" applyTo:@"^AD_BREAK_END$"];
    
    [self addTimeSinceEntryWithAction:AD_QUARTILE attribute:@"timeSinceLastAdQuartile" applyTo:@"^AD_QUARTILE$"];
}

#pragma mark - Private

- (void)heartbeatTimerHandler:(NSTimer *)timer {
    [self sendHeartbeat];
}

- (NSString *)calculateBufferType {
    NSNumber *playhead = [self getPlayhead];
    
    if (!self.state.isAd) {
        if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
            if (((NRVideoTracker *)self.linkedTracker).state.isAdBreak) {
                return @"ad";
            }
        }
    }
    
    if ([playhead isEqual:[NSNull null]]) {
        playhead = @0;
    }
    
    if (self.state.isSeeking) {
        return @"seek";
    }
    
    if (self.state.isPaused) {
        return @"pause";
    }
    
    //NOTE: AVPlayer starts counting contentPlayhead after buffering ends, and by the time we calculate BUFFER_END, playhead can be a bit higher than zero (few milliseconds).
    if (playhead.integerValue < 10) {
        return @"initial";
    }
    
    // If none of the above is true, it is a connection buffering
    return @"connection";
}

@end
