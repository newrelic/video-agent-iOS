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
#import "NRTimeSinceTable.h"
#import "NRChrono.h"
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
@property (nonatomic) int acc;
@property (nonatomic) NRChrono *chrono;

// QoE Aggregate properties
@property (nonatomic) long startupTime;
@property (nonatomic) long peakBitrate;
@property (nonatomic) long averageBitrate;
@property (nonatomic) long totalRebufferingTime;
@property (nonatomic) NSTimeInterval currentBufferStartTime;
@property (nonatomic) BOOL hadStartupFailure;
@property (nonatomic) BOOL hadPlaybackFailure;
@property (nonatomic) NSMutableArray<NSNumber *> *bitratesSample;
@property (nonatomic) long currentBitrate;
@property (nonatomic) NSTimeInterval lastBitrateChangeTime;
@property (nonatomic) long long totalWeightedBitrate;
@property (nonatomic) long startupPeriodAdTime;
@property (nonatomic) NSTimeInterval startupPeriodPauseStartTime;
@property (nonatomic) long startupPeriodPauseTime;

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
        self.chrono = [[NRChrono alloc] init];
        self.acc = 0;

        // Initialize QoE Aggregate properties
        self.startupTime = 0;
        self.peakBitrate = 0;
        self.averageBitrate = 0;
        self.totalRebufferingTime = 0;
        self.currentBufferStartTime = 0;
        self.hadStartupFailure = NO;
        self.hadPlaybackFailure = NO;
        self.bitratesSample = [[NSMutableArray alloc] init];
        self.currentBitrate = 0;
        self.lastBitrateChangeTime = 0;
        self.totalWeightedBitrate = 0;
        self.startupPeriodAdTime = 0;
        self.startupPeriodPauseStartTime = 0;
        self.startupPeriodPauseTime = 0;

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
        }
        [attr setObject:[self getTitle] forKey:@"contentTitle"];
        [attr setObject:[self getBitrate] forKey:@"contentBitrate"];
        if ([self respondsToSelector:@selector(getObservedBitrate)]) {
            [attr setObject:[self getObservedBitrate] forKey:@"contentObservedBitrate"];
        }
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

    // QoE: Track bitrate from processed attributes (for all content events except QOE_AGGREGATE)
    if (!self.state.isAd && ![action isEqualToString:QOE_AGGREGATE]) {
        [self trackBitrateFromProcessedAttributes:attr];
    }

    return attr;
}

#pragma mark - Senders

- (void)sendRequest {
    if ([self.state goRequest]) {
        self.playtimeSinceLastEventTimestamp = 0;

        if (self.state.isAd) {
            [self sendVideoAdEvent:AD_REQUEST];
        }
        else {
            [self sendVideoEvent:CONTENT_REQUEST];
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
                // QoE: Store ad time for startup calculation (covers pre-roll scenario)
                self.startupPeriodAdTime = self.totalAdPlaytime;
            }
            self.numberOfVideos++;

            // Initialize bitrate tracking timing on first CONTENT_START
            if (self.lastBitrateChangeTime == 0) {
                self.lastBitrateChangeTime = [[NSDate date] timeIntervalSince1970];
            }

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
            // QoE: Track pause start time during startup period (before CONTENT_START)
            // If totalPlaytime == 0, content hasn't started playing yet (startup period)
            if (self.totalPlaytime == 0 && self.startupPeriodPauseStartTime == 0) {
                self.startupPeriodPauseStartTime = [[NSDate date] timeIntervalSince1970];
            }
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
            // QoE: Calculate pause duration during startup period (before CONTENT_START)
            if (self.startupPeriodPauseStartTime > 0) {
                // Only count pause if we're still in startup period (totalPlaytime == 0)
                if (self.totalPlaytime == 0) {
                    NSTimeInterval pauseEndTime = [[NSDate date] timeIntervalSince1970];

                    // Validate pause end time is after pause start time
                    if (pauseEndTime > self.startupPeriodPauseStartTime) {
                        NSTimeInterval pauseDiff = pauseEndTime - self.startupPeriodPauseStartTime;

                        // Check if multiplication by 1000 would overflow
                        if (pauseDiff > (LONG_MAX / 1000.0)) {
                            // Overflow would occur - cap total at LONG_MAX
                            self.startupPeriodPauseTime = LONG_MAX;
                        } else {
                            long pauseDuration = (long)(pauseDiff * 1000.0);

                            // Protect against overflow when adding to total
                            if (pauseDuration > 0 && self.startupPeriodPauseTime <= LONG_MAX - pauseDuration) {
                                self.startupPeriodPauseTime += pauseDuration;
                            } else if (pauseDuration > 0) {
                                // Overflow would occur - cap at LONG_MAX
                                self.startupPeriodPauseTime = LONG_MAX;
                            }
                        }
                    }
                }

                // Reset pause start time for next pause (if any)
                self.startupPeriodPauseStartTime = 0;
            }
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
            // Add totalPlaytime to totalAdPlaytime with overflow protection
            if (self.totalPlaytime > 0 && self.totalAdPlaytime <= LONG_MAX - self.totalPlaytime) {
                self.totalAdPlaytime = self.totalAdPlaytime + self.totalPlaytime;
            } else if (self.totalPlaytime > 0) {
                // Overflow would occur - cap at LONG_MAX
                self.totalAdPlaytime = LONG_MAX;
            }
        }
        else {
            [self sendVideoEvent:CONTENT_END];

            // Reset QoE Aggregate metrics for next video
            self.startupTime = 0;
            self.peakBitrate = 0;
            self.averageBitrate = 0;
            self.totalRebufferingTime = 0;
            self.currentBufferStartTime = 0;
            self.hadStartupFailure = NO;
            self.hadPlaybackFailure = NO;
            [self.bitratesSample removeAllObjects];
            self.currentBitrate = 0;
            self.lastBitrateChangeTime = 0;
            self.totalWeightedBitrate = 0;
            self.startupPeriodAdTime = 0;
            self.startupPeriodPauseStartTime = 0;
            self.startupPeriodPauseTime = 0;
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

        // Track rebuffering start time (excluding initial buffering)
        if (!self.state.isAd && self.bufferType && ![self.bufferType isEqualToString:@"initial"]) {
            self.currentBufferStartTime = [[NSDate date] timeIntervalSince1970];
        }

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

        // Calculate rebuffering time (excluding initial buffering)
        if (!self.state.isAd && self.currentBufferStartTime > 0) {
            NSTimeInterval bufferEndTime = [[NSDate date] timeIntervalSince1970];

            // Validate buffer end time is after buffer start time
            if (bufferEndTime > self.currentBufferStartTime) {
                NSTimeInterval bufferDiff = bufferEndTime - self.currentBufferStartTime;

                // Check if multiplication by 1000 would overflow
                if (bufferDiff > (LONG_MAX / 1000.0)) {
                    // Overflow would occur - cap total at LONG_MAX
                    self.totalRebufferingTime = LONG_MAX;
                } else {
                    long bufferDuration = (long)(bufferDiff * 1000.0);

                    // Protect against overflow when adding to total
                    if (bufferDuration > 0 && self.totalRebufferingTime <= LONG_MAX - bufferDuration) {
                        self.totalRebufferingTime += bufferDuration;
                    } else if (bufferDuration > 0) {
                        // Overflow would occur - cap at LONG_MAX
                        self.totalRebufferingTime = LONG_MAX;
                    }
                }
            }
            self.currentBufferStartTime = 0;
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
        [self sendQoeAggregate];
    }
}

- (void)sendQoeAggregate {
    // Update bitrate tracking before sending QoE aggregate
    [self updateBitrateTracking];

    // Calculate startupTime once and cache for reuse using timeSince values
    // Formula: startupTime = timeSinceRequested - (timeSinceStarted OR timeSinceLastError) - exclusions
    if (self.startupTime == 0) {
        // Get timeSince values from the automatic timeSince system
        // Create temporary dictionary and apply timeSince attributes for QOE_AGGREGATE
        // Use KVC to access parent's private timeSinceTable property
        NSMutableDictionary *tempTimeSinceAttrs = [[NSMutableDictionary alloc] init];
        NRTimeSinceTable *timeSinceTable = [self valueForKey:@"timeSinceTable"];
        [timeSinceTable applyAttributes:QOE_AGGREGATE attributes:tempTimeSinceAttrs];

        NSNumber *timeSinceRequestedNum = [tempTimeSinceAttrs objectForKey:@"timeSinceRequested"];
        NSNumber *timeSinceStartedNum = [tempTimeSinceAttrs objectForKey:@"timeSinceStarted"];
        NSNumber *timeSinceLastErrorNum = [tempTimeSinceAttrs objectForKey:@"timeSinceLastError"];

        // Only calculate if we have a request time
        if (timeSinceRequestedNum && ![timeSinceRequestedNum isEqual:[NSNull null]]) {
            long long timeSinceRequested = [timeSinceRequestedNum longLongValue];
            long long rawStartupTime = 0;

            // Determine if this was a success or failure startup
            if (timeSinceStartedNum && ![timeSinceStartedNum isEqual:[NSNull null]]) {
                // Success case: CONTENT_START happened
                long long timeSinceStarted = [timeSinceStartedNum longLongValue];

                // Validate: timeSinceRequested should be >= timeSinceStarted
                if (timeSinceRequested >= timeSinceStarted) {
                    rawStartupTime = timeSinceRequested - timeSinceStarted;
                } else {
                    // Invalid: start happened before request - set to 0
                    self.startupTime = 0;
                    rawStartupTime = -1; // Mark as invalid
                }
            } else if (timeSinceLastErrorNum && ![timeSinceLastErrorNum isEqual:[NSNull null]]) {
                // Failure case: ERROR happened before START
                long long timeSinceLastError = [timeSinceLastErrorNum longLongValue];

                // Validate: timeSinceRequested should be >= timeSinceLastError
                if (timeSinceRequested >= timeSinceLastError) {
                    rawStartupTime = timeSinceRequested - timeSinceLastError;
                    self.hadStartupFailure = YES;
                } else {
                    // Invalid: error happened before request - set to 0
                    self.startupTime = 0;
                    rawStartupTime = -1; // Mark as invalid
                }
            }

            // Only proceed if we have a valid rawStartupTime
            if (rawStartupTime >= 0) {
                // Calculate total exclusion time (ad time + pause time)
                long long totalExclusionTime = 0;

                // Add ad time exclusion with overflow check
                if (!self.state.isAd && self.startupPeriodAdTime > 0) {
                    if (self.startupPeriodAdTime > LLONG_MAX - totalExclusionTime) {
                        totalExclusionTime = LLONG_MAX;
                    } else {
                        totalExclusionTime += self.startupPeriodAdTime;
                    }
                }

                // Add pause time exclusion with overflow check
                if (!self.state.isAd && self.startupPeriodPauseTime > 0 && totalExclusionTime < LLONG_MAX) {
                    if (self.startupPeriodPauseTime > LLONG_MAX - totalExclusionTime) {
                        totalExclusionTime = LLONG_MAX;
                    } else {
                        totalExclusionTime += self.startupPeriodPauseTime;
                    }
                }

                // Calculate final startup time with underflow protection
                if (totalExclusionTime >= rawStartupTime) {
                    // Exclusion time exceeds or equals raw time
                    self.startupTime = 0;
                } else {
                    long long finalStartupTime = rawStartupTime - totalExclusionTime;

                    // Cap at LONG_MAX for the final result
                    if (finalStartupTime > LONG_MAX) {
                        self.startupTime = LONG_MAX;
                    } else {
                        self.startupTime = (long)finalStartupTime;
                    }
                }
            }
        }
    }

    // Calculate time-weighted average bitrate
    long calculatedAverageBitrate = 0;
    if (self.totalPlaytime > 0) {
        // Add the current bitrate's contribution up to now
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
        long long totalWeighted = self.totalWeightedBitrate;

        if (self.currentBitrate > 0 && self.lastBitrateChangeTime > 0 && currentTime > self.lastBitrateChangeTime) {
            NSTimeInterval timeDiff = currentTime - self.lastBitrateChangeTime;

            // Check if multiplication by 1000 would overflow
            if (timeDiff <= (LLONG_MAX / 1000.0)) {
                long long currentDuration = (long long)(timeDiff * 1000.0);

                // Check if bitrate * duration would overflow
                if (currentDuration > 0 && self.currentBitrate <= LLONG_MAX / currentDuration) {
                    long long currentWeighted = self.currentBitrate * currentDuration;

                    // Check if adding to total would overflow
                    if (totalWeighted <= LLONG_MAX - currentWeighted) {
                        totalWeighted += currentWeighted;
                    } else {
                        // Overflow would occur - use LLONG_MAX
                        totalWeighted = LLONG_MAX;
                    }
                } else if (currentDuration > 0) {
                    // Multiplication would overflow - use LLONG_MAX
                    totalWeighted = LLONG_MAX;
                }
            } else {
                // Duration calculation would overflow - use LLONG_MAX
                totalWeighted = LLONG_MAX;
            }
        }

        // Calculate average with division overflow protection
        calculatedAverageBitrate = (long)(totalWeighted / self.totalPlaytime);
    }

    // Calculate rebuffering ratio
    double rebufferingRatio = 0.0;
    if (self.totalPlaytime > 0) {
        rebufferingRatio = ((double)self.totalRebufferingTime / (double)self.totalPlaytime) * 100.0;
    }

    // Note: timeSinceRequested, timeSinceStarted, and timeSinceLastError
    // are automatically added by the NRTimeSince system via applyAttributes
    NSDictionary *qoeAttributes = @{
        @"startupTime": @(self.startupTime),
        @"peakBitrate": @(self.peakBitrate),
        @"averageBitrate": @(calculatedAverageBitrate),
        @"totalPlaytime": @(self.totalPlaytime),
        @"totalRebufferingTime": @(self.totalRebufferingTime),
        @"rebufferingRatio": @(rebufferingRatio),
        @"hadStartupFailure": @(self.hadStartupFailure),
        @"hadPlaybackFailure": @(self.hadPlaybackFailure),
        @"qoeAggregateVersion": @"1.0.0"
    };

    [self sendVideoEvent:QOE_AGGREGATE attributes:qoeAttributes];
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
        // Track startup or playback failure for QoE Aggregate
        // If totalPlaytime > 0, content started playing → playback failure
        // If totalPlaytime == 0, content hasn't started → startup failure
        if (self.totalPlaytime > 0) {
            self.hadPlaybackFailure = YES;
        } else {
            self.hadStartupFailure = YES;
        }
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
    
    [self addTimeSinceEntryWithAction:CONTENT_REQUEST attribute:@"timeSinceRequested" applyTo:@"^(CONTENT_[A-Z_]+|QOE_[A-Z_]+)$"];
    [self addTimeSinceEntryWithAction:AD_REQUEST attribute:@"timeSinceAdRequested" applyTo:@"^AD_[A-Z_]+$"];

    [self addTimeSinceEntryWithAction:CONTENT_START attribute:@"timeSinceStarted" applyTo:@"^(CONTENT_[A-Z_]+|QOE_[A-Z_]+)$"];
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
    
    [self addTimeSinceEntryWithAction:CONTENT_ERROR attribute:@"timeSinceLastError" applyTo:@"^(CONTENT_[A-Z_]+|QOE_[A-Z_]+)$"];
    [self addTimeSinceEntryWithAction:AD_ERROR attribute:@"timeSinceLastAdError" applyTo:@"^AD_[A-Z_]+$"];
    
    [self addTimeSinceEntryWithAction:CONTENT_RENDITION_CHANGE attribute:@"timeSinceLastRenditionChange" applyTo:@"^CONTENT_RENDITION_CHANGE$"];
    [self addTimeSinceEntryWithAction:AD_RENDITION_CHANGE attribute:@"timeSinceLastAdRenditionChange" applyTo:@"^AD_RENDITION_CHANGE$"];
    
    [self addTimeSinceEntryWithAction:AD_BREAK_START attribute:@"timeSinceAdBreakBegin" applyTo:@"^AD_BREAK_END$"];
    
    [self addTimeSinceEntryWithAction:AD_QUARTILE attribute:@"timeSinceLastAdQuartile" applyTo:@"^AD_QUARTILE$"];
}

- (void) updatePlayTime {
    // Calculate playtimeSinceLastEvent and totalPlaytime
    if (self.playtimeSinceLastEventTimestamp > 0) {
        NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

        // Validate current time is after last event timestamp
        if (currentTime > self.playtimeSinceLastEventTimestamp) {
            NSTimeInterval timeDiff = currentTime - self.playtimeSinceLastEventTimestamp;

            // Check if multiplication by 1000 would overflow
            if (timeDiff > (LONG_MAX / 1000.0)) {
                // Overflow would occur - cap playtime at LONG_MAX
                self.playtimeSinceLastEvent = LONG_MAX;
                self.totalPlaytime = LONG_MAX;
            } else {
                self.playtimeSinceLastEvent = (long)(1000.0f * timeDiff);

                // Protect against overflow when adding to totalPlaytime
                if (self.playtimeSinceLastEvent > 0 && self.totalPlaytime <= LONG_MAX - self.playtimeSinceLastEvent) {
                    self.totalPlaytime += self.playtimeSinceLastEvent;
                } else if (self.playtimeSinceLastEvent > 0) {
                    // Overflow would occur - cap at LONG_MAX
                    self.totalPlaytime = LONG_MAX;
                }
            }
            self.playtimeSinceLastEventTimestamp = currentTime;
        } else {
            // Time went backwards - don't update
            self.playtimeSinceLastEvent = 0;
        }
    }
    else {
        self.playtimeSinceLastEvent = 0;
    }
}

- (void)trackBitrateFromProcessedAttributes:(NSDictionary *)processedAttributes {
    // Extract contentBitrate from processed attributes
    id contentBitrate = [processedAttributes objectForKey:@"contentBitrate"];
    long bitrateValue = 0;

    // Handle different numeric types
    if ([contentBitrate isKindOfClass:[NSNumber class]]) {
        bitrateValue = [(NSNumber *)contentBitrate longValue];
    }

    if (bitrateValue <= 0) {
        return;
    }

    // Update QoE metrics with this bitrate
    [self updateBitrateMetrics:bitrateValue];
}

- (void)updateBitrateMetrics:(long)bitrate {
    if (bitrate <= 0) {
        return;
    }

    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];

    // If this is a bitrate change (and not the first bitrate)
    if (self.currentBitrate > 0 && bitrate != self.currentBitrate && self.lastBitrateChangeTime > 0) {
        // Validate current time is after last change time
        if (currentTime > self.lastBitrateChangeTime) {
            NSTimeInterval timeDiff = currentTime - self.lastBitrateChangeTime;

            // Check if multiplication by 1000 would overflow
            if (timeDiff > (LLONG_MAX / 1000.0)) {
                // Duration overflow - cap totalWeightedBitrate at LLONG_MAX
                self.totalWeightedBitrate = LLONG_MAX;
            } else {
                long long duration = (long long)(timeDiff * 1000.0);

                // Check if bitrate * duration would overflow
                if (duration > 0 && self.currentBitrate > 0 && self.currentBitrate <= LLONG_MAX / duration) {
                    long long weightedBitrate = self.currentBitrate * duration;

                    // Check if adding to total would overflow
                    if (self.totalWeightedBitrate <= LLONG_MAX - weightedBitrate) {
                        self.totalWeightedBitrate += weightedBitrate;
                    } else {
                        // Overflow would occur - cap at LLONG_MAX
                        self.totalWeightedBitrate = LLONG_MAX;
                    }
                } else if (duration > 0 && self.currentBitrate > 0) {
                    // Multiplication would overflow - cap at LLONG_MAX
                    self.totalWeightedBitrate = LLONG_MAX;
                }
            }
        }
    }

    // Update current bitrate and timestamp
    self.currentBitrate = bitrate;
    self.lastBitrateChangeTime = currentTime;

    // Update peak bitrate
    if (bitrate > self.peakBitrate) {
        self.peakBitrate = bitrate;
    }
}

- (void)updateBitrateTracking {
    // This method is called from sendQoeAggregate to ensure latest bitrate is captured
    NSNumber *renditionBitrate = [self getRenditionBitrate];

    if (renditionBitrate && ![renditionBitrate isEqual:[NSNull null]]) {
        long bitrateValue = [renditionBitrate longValue];
        if (bitrateValue > 0) {
            [self updateBitrateMetrics:bitrateValue];
        }
    }
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
