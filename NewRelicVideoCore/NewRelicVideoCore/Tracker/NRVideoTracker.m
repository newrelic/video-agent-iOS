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
#import "NRChrono.h"
#import "NRQoEAggregator.h"
#import "NRVAVideo.h"
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
@property (nonatomic) long totalPreRollAdTime;  // wall-clock ms, sum of each AD_START → AD_END
@property (nonatomic) long playtimeSinceLastEvent;
@property (nonatomic) NSString *bufferType;
@property (nonatomic, weak) NRTimeSince *lastAdTimeSince;
@property (nonatomic) int acc;
@property (nonatomic) NRChrono *chrono;
// --- QoE Aggregate ---
// The aggregator observes CONTENT_* events via preSendAction and accumulates KPIs.
// QoE aggregate events are generated at harvest time via a callback block set on the harvest manager.
// See NRQoEAggregator.h for the full design overview.
@property (nonatomic) NRQoEAggregator *qoeAggregator;
// Snapshot of the last content event's fully-assembled attributes (post-getAttributes,
// post-timeSince, post-instrumentation, NSNull-cleaned). Used by buildQoeEvent to
// carry over content metadata, player info, rendition, etc. to QOE_AGGREGATE events.
@property (nonatomic, copy) NSDictionary *lastContentEventAttributes;
// Keys of custom attributes set via setAttribute:value: that should be carried to QOE_AGGREGATE events.
@property (nonatomic, strong) NSMutableSet<NSString *> *customAttributeKeys;

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
        self.totalPreRollAdTime = 0;
        self.playtimeSinceLastEvent = 0;
        self.bufferType = nil;
        self.chrono = [[NRChrono alloc] init];
        self.acc = 0;
        // QoE aggregator is only created if enabled in NRVAVideoConfiguration.
        if ([NRVAVideo isQoeAggregateEnabled]) {
            self.qoeAggregator = [[NRQoEAggregator alloc] init];
        }
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

- (void)setAttribute:(NSString *)key value:(id<NSCopying>)value {
    [super setAttribute:key value:value];
    // Track custom attribute keys so buildQoeEvent can carry them to QOE_AGGREGATE events.
    if (!self.customAttributeKeys) {
        self.customAttributeKeys = [NSMutableSet set];
    }
    [self.customAttributeKeys addObject:key];
}

- (void)setPlayer:(id)player {
    [self sendVideoEvent:PLAYER_READY];
    [self.state goPlayerReady];
}

- (void)startHeartbeat {
    if (self.heartbeatTimeInterval == 0) return;
    
    if (!self.timer) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval) self.state.isAd ? 2 : self.heartbeatTimeInterval
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
        self.heartbeatTimeInterval = self.state.isAd ? 2 : seconds;
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
    // Update totalPlaytime before assembling attributes
    [self updatePlayTime];

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
    [attr setObject:[self getTrackerSrc] forKey:@"src"];
    [attr setObject:[self getTrackerVersion] forKey:@"trackerVersion"];
    [attr setObject:[self getPlayerName] forKey:@"playerName"];
    [attr setObject:[self getPlayerVersion] forKey:@"playerVersion"];
    [attr setObject:[self getViewSession] forKey:@"viewSession"];
    [attr setObject:[self getViewId] forKey:@"viewId"];
    [attr setObject:@(self.numberOfAds) forKey:@"numberOfAds"];
    [attr setObject:@(self.numberOfVideos) forKey:@"numberOfVideos"];
    [attr setObject:@(self.numberOfErrors) forKey:@"numberOfErrors"];
    // [attr setObject:@(self.playtimeSinceLastEvent) forKey:@"elapsedTime"];
    [attr setObject:@(self.totalPlaytime) forKey:@"totalPlaytime"];
    
    if (self.state.isAd) {
        [attr setObject:[self getTitle] forKey:@"adTitle"];
        // Only add bitrate attributes after ad has started (first frame shown)
        if ([self.state isStarted]) {
            [attr setObject:[self getBitrate] forKey:@"adBitrate"];
            [attr setObject:[self getRenditionBitrate] forKey:@"adRenditionBitrate"];
        }
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
        [attr setObject:[self getAdSkipped] forKey:@"adSkipped"];
        
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
            [attr setObject:@(self.totalPreRollAdTime) forKey:@"totalPreRollAdTime"];
        }
        [attr setObject:[self getTitle] forKey:@"contentTitle"];
        // Only add bitrate attributes after content has started (first frame shown)
        if ([self.state isStarted]) {
            [attr setObject:[self getBitrate] forKey:@"contentBitrate"];
            if ([self respondsToSelector:@selector(getObservedBitrate)]) {
                [attr setObject:[self getObservedBitrate] forKey:@"contentObservedBitrate"];
            }
            [attr setObject:[self getRenditionBitrate] forKey:@"contentRenditionBitrate"];
        }
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

// Feed every CONTENT_* event to the QoE aggregator AFTER attributes are fully assembled.
// At this point, getAttributes: has already run, timeSince values are applied, instrumentation
// attrs are added, and NSNull values are cleaned. The aggregator reads these values —
// it does NOT maintain parallel state or call player APIs directly.
//
// We also save a snapshot of the attributes for buildQoeEvent to carry over content
// metadata (player info, rendition, content metadata, etc.) to QOE_AGGREGATE events.
- (BOOL)preSendAction:(NSString *)action attributes:(NSMutableDictionary *)attributes {
    // Accumulate wall-clock ad duration from timeSinceAdStarted at AD_END (pre-roll only)
    if ([action isEqualToString:AD_END]) {
        BOOL contentStarted = NO;
        if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
            contentStarted = [(NRVideoTracker *)self.linkedTracker state].isStarted;
        }
        if (!contentStarted) {
            NSNumber *timeSinceAdStarted = attributes[@"timeSinceAdStarted"];
            if (timeSinceAdStarted) {
                self.totalPreRollAdTime += [timeSinceAdStarted longValue];
            }
        }
    }

    if (self.qoeAggregator && !self.state.isAd && [action hasPrefix:@"CONTENT_"]) {
        [self.qoeAggregator processAction:action attributes:attributes isPlaying:self.state.isPlaying];
        self.lastContentEventAttributes = [attributes copy];
    }

    // Strip internal-only attributes that the aggregator needed but shouldn't appear in NRDB.
    // totalPreRollAdTime is used by the aggregator to compute startupTime but is not a user-facing attribute.
    [attributes removeObjectForKey:@"totalPreRollAdTime"];

    return [super preSendAction:action attributes:attributes];
}

#pragma mark - Senders

- (void)sendRequest {
    if ([self.state goRequest]) {
        self.playtimeSinceLastEventTimestamp = 0;
        
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_REQUEST];
        }
        else {
            // Increment viewId for subsequent videos (not the first).
            // Done here instead of sendEnd so post-roll ads share the same viewId as their content.
            if (self.numberOfVideos > 0) {
                self.viewIdIndex++;
            }
            [self sendVideoEvent:CONTENT_REQUEST];
            // Register QoE event provider at REQUEST so QoE is sent even if START never happens
            // (e.g., startup error). By this point preSendAction has already run, so
            // lastContentEventAttributes is set and aggregator has hasReceivedRequest=YES.
            if (self.qoeAggregator) {
                __weak typeof(self) weakSelf = self;
                [NRVAVideo setQoeEventProvider:^NSDictionary * {
                    return [weakSelf buildQoeEvent];
                }];
            }
        }
    }
}

- (void)sendStart {
    if ([self.state goStart]) {
        [self startHeartbeat];
        [self.chrono start];
        if (self.state.isAd) {
            self.numberOfAds++;
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                [(NRVideoTracker *)self.linkedTracker setNumberOfAds:self.numberOfAds];
            }
            [self sendVideoAdEvent:AD_START];
        }
        else {
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                self.totalAdPlaytime = [(NRVideoTracker *)self.linkedTracker getTotalAdPlaytime].longValue;
                self.totalPreRollAdTime = [(NRVideoTracker *)self.linkedTracker totalPreRollAdTime];
            }
            self.numberOfVideos++;
            [self sendVideoEvent:CONTENT_START];
        }
        self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)sendPause {
    if ([self.state goPause]) {
        if(!self.state.isBuffering){
            self.acc = (self.acc + [self.chrono getDeltaTime]);
        }
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_PAUSE];
        }
        else {
            [self sendVideoEvent:CONTENT_PAUSE];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendResume {
    if ([self.state goResume]) {
        if(!self.state.isBuffering){
            [self.chrono start];
        }
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_RESUME];
        }
        else {
            [self sendVideoEvent:CONTENT_RESUME];
        }
        if (!self.state.isBuffering && !self.state.isSeeking) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
    }
}

- (void)sendEnd {
    if ([self.state goEnd]) {
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_END];
            if ([self.linkedTracker isKindOfClass:[NRVideoTracker class]]) {
                [(NRVideoTracker *)self.linkedTracker adHappened];
            }
            self.totalAdPlaytime = self.totalAdPlaytime + self.totalPlaytime;
        }
        else {
            [self sendVideoEvent:CONTENT_END];
            // Build final QoE eagerly while all state is still valid, then enqueue
            // for the next harvest. This avoids the race where provider/aggregator/attributes
            // are cleared on the tracker thread before the harvestQueue can use them.
            NSDictionary *finalQoe = [self buildQoeEvent];
            if (finalQoe) {
                [NRVAVideo enqueueFinalQoeEvent:finalQoe];
            }
            [NRVAVideo setQoeEventProvider:nil];
            [self.qoeAggregator reset];
            self.lastContentEventAttributes = nil;
        }

        [self stopHeartbeat];

        self.numberOfErrors = 0;
        self.playtimeSinceLastEventTimestamp = 0;
        self.playtimeSinceLastEvent = 0;
        self.totalPlaytime = 0;
    }
}

- (void)sendSeekStart {
    if ([self.state goSeekStart]) {
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_SEEK_START];
        }
        else {
            [self sendVideoEvent:CONTENT_SEEK_START];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendSeekEnd {
    if ([self.state goSeekEnd]) {
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_SEEK_END];
        }
        else {
            [self sendVideoEvent:CONTENT_SEEK_END];
        }
        if (!self.state.isBuffering && !self.state.isPaused) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
    }
}

- (void)sendBufferStart {
    if ([self.state goBufferStart]) {
        if(self.state.isPlaying){
            self.acc = (self.acc + [self.chrono getDeltaTime]);
        }
        self.bufferType = [self calculateBufferType];
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_BUFFER_START];
        }
        else {
            [self sendVideoEvent:CONTENT_BUFFER_START];
        }
        self.playtimeSinceLastEventTimestamp = 0;
    }
}

- (void)sendBufferEnd {
    if ([self.state goBufferEnd]) {
        if(self.state.isPlaying){
            [self.chrono start];
        }
        if (!self.bufferType) {
            self.bufferType = [self calculateBufferType];
        }
        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_BUFFER_END];
        }
        else {
            [self sendVideoEvent:CONTENT_BUFFER_END];
        }
        if (!self.state.isSeeking && !self.state.isPaused) {
            self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
        }
        self.bufferType = nil;
    }
}

- (void)sendHeartbeat {
    int heartbeatInterval = self.state.isAd ? 2000 : self.heartbeatTimeInterval*1000;
    if(self.state.isPlaying){
        self.acc += [self.chrono getDeltaTime];
    }
    self.acc = (abs(self.acc - heartbeatInterval) <= 5) ? heartbeatInterval : self.acc;
    [self.chrono start];
    NSDictionary *attributes = @{@"elapsedTime": @(self.acc)};
    self.acc = 0;
    if (self.state.isAd) {
        [self sendVideoAdEvent:AD_HEARTBEAT attributes:attributes];
    }
    else {
        [self sendVideoEvent:CONTENT_HEARTBEAT attributes:attributes];
    }
}

- (void)sendRenditionChange {
    if (self.state.isAd) {
        [self sendVideoAdEvent:AD_RENDITION_CHANGE];
    }
    else {
        [self sendVideoEvent:CONTENT_RENDITION_CHANGE];
    }
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
        [self sendVideoErrorEvent:AD_ERROR attributes:errAttr];
    }
    else {
        [self sendVideoErrorEvent:CONTENT_ERROR attributes:errAttr];
    }
}

- (void)sendAdBreakStart {
    if (self.state.isAd && [self.state goAdBreakStart]) {
        self.adBreakIdIndex++;
        self.totalAdPlaytime = 0;
        [self sendVideoAdEvent:AD_BREAK_START];
    }
}

- (void)sendAdBreakEnd {
    if (self.state.isAd && [self.state goAdBreakEnd]) {
        [self sendVideoAdEvent:AD_BREAK_END];
    }
}

- (void)sendAdQuartile {
    if (self.state.isAd) {
        [self sendVideoAdEvent:AD_QUARTILE];
    }
}

- (void)sendAdClick {
    if (self.state.isAd) {
        [self sendVideoAdEvent:AD_CLICK];
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

- (NSString *)getTrackerSrc {
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

- (NSNumber *)getObservedBitrate {
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

- (NSNumber *)getAdSkipped {
    return @(0);
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

- (void) updatePlayTime {
    // Calculate playtimeSinceLastEvent and totalPlaytime
    if (self.playtimeSinceLastEventTimestamp > 0) {
        self.playtimeSinceLastEvent = (long)(1000.0f * ([[NSDate date] timeIntervalSince1970] - self.playtimeSinceLastEventTimestamp));
        self.totalPlaytime += self.playtimeSinceLastEvent;
        self.playtimeSinceLastEventTimestamp = [[NSDate date] timeIntervalSince1970];
    }
    else {
        self.playtimeSinceLastEvent = 0;
    }
}

// Read-only peek at the current totalPlaytime without mutating tracker state.
// Safe to call from the harvest thread. If the player is currently playing,
// adds the un-flushed delta since the last content event.
- (long)currentTotalPlaytime {
    if (self.playtimeSinceLastEventTimestamp > 0) {
        long delta = (long)(1000.0f * ([[NSDate date] timeIntervalSince1970] - self.playtimeSinceLastEventTimestamp));
        return self.totalPlaytime + delta;
    }
    return self.totalPlaytime;
}

#pragma mark - QoE Aggregate

// Builds a QOE_AGGREGATE event dict for direct injection into the harvest batch.
// Called by the harvest manager's qoeEventProvider block at harvest time.
//
// Attribute composition:
// 1. Whitelist = only specific context attributes from lastContentEventAttributes
//    (content metadata, device info, session identifiers, rendition, geo/ASN).
// 2. Overlay computed QoE KPI attributes from the aggregator.
// 3. Set actionName, eventType, and timestamp for direct batch injection.
- (NSDictionary *)buildQoeEvent {
    if (!self.qoeAggregator) return nil;

    NSDictionary *kpiAttributes = [self.qoeAggregator generateAggregateAttributes];
    if (!kpiAttributes) return nil;

    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];

    // Whitelist of content attributes allowed in QOE_AGGREGATE events.
    // Only these context attributes are carried over from the last content event.
    //
    // Not available in iOS video core (present in JS/browser SDK):
    //   asn, asnLatitude, asnLongitude, asnOrganization,
    //   contentCdn, contentIsAutoplayed, contentIsFullscreen,
    //   contentPreload, contentRenditionName,
    //   deviceGroup, deviceManufacturer, deviceModel, deviceName,
    //   deviceSize, deviceType, deviceUuid, pageUrl
    //
    // TODO: elapsedTime — only set on CONTENT_HEARTBEAT, not on every event.
    //   Needs dedicated handling to include in QOE_AGGREGATE.
    static NSSet *allowedKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedKeys = [NSSet setWithArray:@[
            @"contentDuration",
            @"contentFps",
            @"contentId",
            @"contentIsLive",
            @"contentIsMuted",
            @"contentPlayhead",
            @"contentPlayrate",
            @"contentRenditionHeight",
            @"contentRenditionWidth",
            @"contentSrc",
            @"contentTitle",
            @"instrumentation.name",
            @"instrumentation.provider",
            @"instrumentation.version",
            @"numberOfErrors",
            @"numberOfVideos",
            @"playerName",
            @"playerVersion",
            @"src",
            @"timeSinceRequested",
            @"timeSinceStarted",
            @"trackerName",
            @"trackerVersion",
            @"viewId",
            @"viewSession"
        ]];
    });

    // Copy only whitelisted attributes from the last content event snapshot
    for (NSString *key in self.lastContentEventAttributes) {
        if ([allowedKeys containsObject:key]) {
            attrs[key] = self.lastContentEventAttributes[key];
        }
    }

    // Also carry custom attributes (set via setAttribute:value:) to QOE_AGGREGATE events.
    // These are user-defined attributes that should appear in every event type.
    if (self.customAttributeKeys) {
        for (NSString *key in self.customAttributeKeys) {
            id value = self.lastContentEventAttributes[key];
            if (value && ![value isKindOfClass:[NSNull class]]) {
                attrs[key] = value;
            }
        }
    }

    // Overlay computed QoE KPI attributes from the aggregator
    [attrs addEntriesFromDictionary:kpiAttributes];

    // Override totalPlaytime with real-time value (aggregator's is stale between events)
    long freshPlaytime = [self currentTotalPlaytime];
    attrs[KPI_TOTAL_PLAYTIME] = @(freshPlaytime);

    // Recompute rebufferingRatio using fresh totalPlaytime
    if (freshPlaytime > 0) {
        long rebufTime = [attrs[KPI_TOTAL_REBUFFERING_TIME] longValue];
        attrs[KPI_REBUFFERING_RATIO] = @(((double)rebufTime / (double)freshPlaytime) * 100.0);
    }

    // Set event metadata for direct batch injection (bypasses recordEvent:)
    attrs[@"actionName"] = QOE_AGGREGATE;
    attrs[@"eventType"] = NR_VIDEO_EVENT;
    attrs[@"timestamp"] = @((long long)([[NSDate date] timeIntervalSince1970] * 1000));
    attrs[@"qoeAggregateVersion"] = QOE_AGGREGATE_VERSION;

    return [attrs copy];
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
