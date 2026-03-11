//
//  NRQoEAggregator.m
//  NewRelicVideoCore
//
//  Quality of Experience KPI aggregator.
//  See NRQoEAggregator.h for design overview.
//

#import "NRQoEAggregator.h"
#import "NRVideoDefs.h"

@interface NRQoEAggregator ()

// --- Lifecycle flags ---
@property (nonatomic) BOOL hasReceivedRequest;   // YES after CONTENT_REQUEST
@property (nonatomic) BOOL hasReceivedStart;      // YES after CONTENT_START

// --- Startup ---
@property (nonatomic) long startupTime;           // ms, = timeSinceRequested - totalAdPlaytime

// --- Bitrate tracking (time-weighted average) ---
// Algorithm: Each time the bitrate changes, we "close" the previous segment:
//   bitrateWeightedSum += previousBitrate * segmentDuration
//   bitrateTotalDuration += segmentDuration
// At report time, the current in-progress segment is also included.
// Average = bitrateWeightedSum / bitrateTotalDuration
@property (nonatomic) long peakBitrate;                        // Highest observed bitrate (bps)
@property (nonatomic) long currentBitrate;                     // Current bitrate being tracked
@property (nonatomic) NSTimeInterval lastBitrateChangeTimestamp; // Wall-clock time of last change
@property (nonatomic) double bitrateWeightedSum;               // Accumulated (bitrate * duration)
@property (nonatomic) double bitrateTotalDuration;             // Accumulated duration (seconds)

// --- Rebuffering ---
// Counts all CONTENT_BUFFER_END events except the very first one (initial buffer).
// Aligned with Android and JS SDKs: skip initial, accumulate everything else.
// Reads timeSinceBufferBegin from CONTENT_BUFFER_END attributes.
@property (nonatomic) BOOL initialBufferingHappened; // YES after first BUFFER_END
@property (nonatomic) long totalRebufferingTime;  // ms

// --- Failure flags ---
// Error before start = startup failure; error after start = playback failure
@property (nonatomic) BOOL hadStartupError;
@property (nonatomic) BOOL hadPlaybackError;

// --- Playtime ---
// Read from the tracker's totalPlaytime attribute on every content event.
// Used to compute rebufferingRatio = (totalRebufferingTime / lastTotalPlaytime) * 100
@property (nonatomic) long lastTotalPlaytime;     // ms, latest value from event attributes

@end

@implementation NRQoEAggregator

- (instancetype)init {
    if (self = [super init]) {
        [self reset];
    }
    return self;
}

- (void)reset {
    @synchronized (self) {
        self.hasReceivedRequest = NO;
        self.hasReceivedStart = NO;
        self.startupTime = 0;
        self.peakBitrate = 0;
        self.currentBitrate = 0;
        self.lastBitrateChangeTimestamp = 0;
        self.bitrateWeightedSum = 0;
        self.bitrateTotalDuration = 0;
        self.initialBufferingHappened = NO;
        self.totalRebufferingTime = 0;
        self.hadStartupError = NO;
        self.hadPlaybackError = NO;
        self.lastTotalPlaytime = 0;
    }
}

// Static dispatch table: maps action names to handler blocks.
// Blocks take (aggregator, attributes) to avoid retain cycles in the static dictionary.
typedef void (^QoEActionHandler)(NRQoEAggregator *, NSDictionary *);

static NSDictionary<NSString *, QoEActionHandler> *sActionHandlers;

+ (void)initialize {
    if (self == [NRQoEAggregator class]) {
        sActionHandlers = @{
            CONTENT_REQUEST:    ^(NRQoEAggregator *agg, NSDictionary *attrs) {
                [agg handleRequest];
            },
            CONTENT_START:      ^(NRQoEAggregator *agg, NSDictionary *attrs) {
                [agg handleStartWithAttributes:attrs];
            },
            CONTENT_BUFFER_END: ^(NRQoEAggregator *agg, NSDictionary *attrs) {
                [agg handleBufferEndWithAttributes:attrs];
            },
            CONTENT_ERROR:      ^(NRQoEAggregator *agg, NSDictionary *attrs) {
                [agg handleError];
            },
            CONTENT_END:        ^(NRQoEAggregator *agg, NSDictionary *attrs) {
                [agg flushBitrateSegment];
            },
        };
    }
}

// Called from NRVideoTracker's preSendAction: for every CONTENT_* event.
// At this point, the tracker pipeline has already assembled all attributes
// (timeSince values, bitrate, playtime, bufferType, etc.), so we just read them.
- (void)processAction:(NSString *)action attributes:(NSDictionary *)attributes {
    @synchronized (self) {
        // Always grab the latest totalPlaytime — the tracker updates this before every event
        NSNumber *playtime = attributes[@"totalPlaytime"];
        if (playtime) {
            self.lastTotalPlaytime = [playtime longValue];
        }

        // Track bitrate from every content event for time-weighted average + peak
        [self updateBitrateFromAttributes:attributes];

        // Action-specific KPI extraction via dispatch table
        QoEActionHandler handler = sActionHandlers[action];
        if (handler) {
            handler(self, attributes);
        }
    }
}

// Produces a snapshot of all KPIs at the current moment.
// Called periodically (on harvest cycle boundaries) and once at CONTENT_END.
// Returns nil if no CONTENT_REQUEST was received (nothing to report).
- (nullable NSDictionary *)generateAggregateAttributes {
    @synchronized (self) {
        if (!self.hasReceivedRequest) {
            return nil;
        }

        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];

        // --- Startup time (ms) ---
        // Only meaningful after content has started playing
        if (self.hasReceivedStart) {
            attrs[KPI_STARTUP_TIME] = @(self.startupTime);
        }

        // --- Peak bitrate (bps) ---
        if (self.peakBitrate > 0) {
            attrs[KPI_PEAK_BITRATE] = @(self.peakBitrate);
        }

        // --- Time-weighted average bitrate (bps) ---
        // Completed segments are already accumulated in bitrateWeightedSum/bitrateTotalDuration.
        // We also include the *current in-progress segment* (from last bitrate change to now)
        // so that intermediate reports during playback are accurate, not stale.
        double weightedSum = self.bitrateWeightedSum;
        double totalDuration = self.bitrateTotalDuration;
        if (self.currentBitrate > 0 && self.lastBitrateChangeTimestamp > 0) {
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            double segmentDuration = now - self.lastBitrateChangeTimestamp;
            if (segmentDuration > 0) {
                weightedSum += self.currentBitrate * segmentDuration;
                totalDuration += segmentDuration;
            }
        }
        if (totalDuration > 0) {
            attrs[KPI_AVERAGE_BITRATE] = @((long)(weightedSum / totalDuration));
        }

        // --- Rebuffering ---
        // totalRebufferingTime is accumulated from "connection" type BUFFER_END events (ms)
        // rebufferingRatio = (rebufferingTime / playtime) * 100, as a percentage
        // Note: kpi.totalPlaytime is NOT emitted — the tracker's totalPlaytime is already
        // carried over from content event attributes by buildQoeEvent.
        attrs[KPI_TOTAL_REBUFFERING_TIME] = @(self.totalRebufferingTime);

        if (self.lastTotalPlaytime > 0) {
            double ratio = ((double)self.totalRebufferingTime / (double)self.lastTotalPlaytime) * 100.0;
            attrs[KPI_REBUFFERING_RATIO] = @(ratio);
        } else {
            attrs[KPI_REBUFFERING_RATIO] = @(0.0);
        }

        // --- Error flags ---
        attrs[KPI_HAD_STARTUP_ERROR] = @(self.hadStartupError);
        attrs[KPI_HAD_PLAYBACK_ERROR] = @(self.hadPlaybackError);

        return [attrs copy];
    }
}

#pragma mark - Private

- (void)handleRequest {
    self.hasReceivedRequest = YES;
}

- (void)handleStartWithAttributes:(NSDictionary *)attributes {
    self.hasReceivedStart = YES;

    // Startup time = timeSinceRequested - totalAdPlaytime
    // timeSinceRequested: time from CONTENT_REQUEST to CONTENT_START (computed by timeSince table)
    // totalAdPlaytime: pre-roll ad duration (set by the ad tracker via linkedTracker)
    // We subtract ad time because the user wasn't waiting for content during ads.
    NSNumber *timeSinceRequested = attributes[@"timeSinceRequested"];
    if (timeSinceRequested) {
        long startup = [timeSinceRequested longValue];

        NSNumber *adPlaytime = attributes[@"totalAdPlaytime"];
        if (adPlaytime) {
            startup -= [adPlaytime longValue];
        }

        self.startupTime = MAX(startup, 0);
    }

    // Set a baseline timestamp for the first bitrate segment (time-weighted tracking starts here)
    if (self.lastBitrateChangeTimestamp == 0) {
        self.lastBitrateChangeTimestamp = [[NSDate date] timeIntervalSince1970];
    }
}

- (void)handleBufferEndWithAttributes:(NSDictionary *)attributes {
    // Skip the first buffer event (initial buffering) — aligned with Android and JS SDKs.
    // All subsequent CONTENT_BUFFER_END events count as rebuffering regardless of bufferType.
    if (!self.initialBufferingHappened) {
        self.initialBufferingHappened = YES;
        return;
    }

    // timeSinceBufferBegin = duration of this buffer event (computed by timeSince table)
    NSNumber *timeSinceBufferBegin = attributes[@"timeSinceBufferBegin"];
    if (timeSinceBufferBegin) {
        self.totalRebufferingTime += [timeSinceBufferBegin longValue];
    }
}

- (void)handleError {
    // Distinguish startup vs playback failure based on whether content has started.
    // Before CONTENT_START → startup failure (e.g., network error loading manifest)
    // After CONTENT_START  → playback failure (e.g., stream decode error mid-play)
    if (self.hasReceivedStart) {
        self.hadPlaybackError = YES;
    } else {
        self.hadStartupError = YES;
    }
}

// TIME-WEIGHTED AVERAGE BITRATE ALGORITHM:
//
// We track bitrate as a series of segments. Each segment has a bitrate and duration.
// When bitrate changes (e.g., adaptive bitrate switching), we "close" the previous
// segment by adding (previousBitrate * segmentDuration) to the weighted sum.
//
// Example: 2Mbps for 10s, then 4Mbps for 20s → avg = (2*10 + 4*20) / 30 = 3.33 Mbps
//
// The current in-progress segment is NOT accumulated here — it's included on-the-fly
// in generateAggregateAttributes so intermediate reports stay accurate.
//
// On CONTENT_END, flushBitrateSegment closes the final segment.
- (void)updateBitrateFromAttributes:(NSDictionary *)attributes {
    // Read bitrate — prefer contentBitrate, fall back to contentRenditionBitrate
    NSNumber *bitrateValue = attributes[@"contentBitrate"];
    if (!bitrateValue) {
        bitrateValue = attributes[@"contentRenditionBitrate"];
    }
    if (!bitrateValue) {
        return;
    }

    long bitrate = [bitrateValue longValue];
    if (bitrate <= 0) {
        return;
    }

    // Track the highest bitrate seen during playback
    if (bitrate > self.peakBitrate) {
        self.peakBitrate = bitrate;
    }

    // When bitrate changes, close the previous segment and start a new one
    if (bitrate != self.currentBitrate && self.currentBitrate > 0 && self.lastBitrateChangeTimestamp > 0) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        double segmentDuration = now - self.lastBitrateChangeTimestamp;
        if (segmentDuration > 0) {
            self.bitrateWeightedSum += self.currentBitrate * segmentDuration;
            self.bitrateTotalDuration += segmentDuration;
        }
        self.lastBitrateChangeTimestamp = now;
    }

    // Initialize baseline on first bitrate observation (if not already set by handleStart)
    if (self.currentBitrate == 0 && self.lastBitrateChangeTimestamp == 0) {
        self.lastBitrateChangeTimestamp = [[NSDate date] timeIntervalSince1970];
    }

    self.currentBitrate = bitrate;
}

// Called on CONTENT_END to close the final bitrate segment.
// Without this, the last segment between the last bitrate change and content end
// would be lost from the accumulated weighted sum.
- (void)flushBitrateSegment {
    if (self.currentBitrate > 0 && self.lastBitrateChangeTimestamp > 0) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        double segmentDuration = now - self.lastBitrateChangeTimestamp;
        if (segmentDuration > 0) {
            self.bitrateWeightedSum += self.currentBitrate * segmentDuration;
            self.bitrateTotalDuration += segmentDuration;
        }
        self.lastBitrateChangeTimestamp = now;
    }
}

@end
