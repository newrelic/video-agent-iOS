//
//  NRQoEAggregator.h
//  NewRelicVideoCore
//
//  Quality of Experience (QoE) KPI Aggregator
//
//  DESIGN:
//  This class is a single-responsibility aggregator that computes QoE KPIs by
//  reading from the existing event pipeline's fully-assembled attributes.
//  It does NOT maintain parallel state — the tracker's timeSince table, bitrate
//  getters, and playtime counters already compute the raw values. This class
//  simply observes them at each content event via processAction:attributes:.
//
//  HOW IT WORKS:
//  1. NRVideoTracker calls processAction:attributes: from preSendAction: for
//     every CONTENT_* event, AFTER all attributes (timeSince, bitrate, playtime)
//     are fully assembled.
//  2. The aggregator extracts relevant values from the attributes dictionary:
//     - timeSinceRequested, totalAdPlaytime → startup time
//     - contentBitrate → peak + time-weighted average
//     - timeSinceBufferBegin → rebuffering time (all post-initial buffers)
//     - totalPlaytime → latest playtime for ratio calculation
//  3. On demand (heartbeat cycle or content end), generateAggregateAttributes
//     returns the computed KPI dictionary, which is sent as a QOE_AGGREGATE event.
//  4. reset clears all state for the next video session.
//
//  KPIs PRODUCED (attribute keys defined in NRVideoDefs.h):
//  - startupTime           Time from request to start, minus pre-roll ad time (ms)
//  - peakBitrate           Highest observed bitrate during playback (bps)
//  - averageBitrate        Time-weighted average bitrate (bps)
//  - totalPlaytime         Total content playtime (ms)
//  - totalRebufferingTime  Total rebuffering time, excludes initial buffer (ms)
//  - rebufferingRatio      (rebufferingTime / playtime) * 100 (percentage)
//  - hadStartupError       Error occurred before content started
//  - hadPlaybackError      Error occurred after content started
//
//  NAMING CONVENTION (NRVideoDefs.h):
//  Base names (ATTR_*) define WHAT is measured: "startupTime", "peakBitrate", etc.
//  QOE_PREFIX is currently empty (no namespace prefix), aligned with Android and JS SDKs.
//  KPI_* macros = @QOE_PREFIX ATTR_* → @"startupTime" (compile-time concatenation).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NRQoEAggregator : NSObject

/**
 Process a content event action and its fully-assembled attributes.
 Called from NRVideoTracker's preSendAction: for every CONTENT_* event.
 Extracts relevant QoE data (bitrate, playtime, buffer duration, etc.)
 from the attributes dictionary that the tracker pipeline has already built.

 @param action The content action name (e.g. CONTENT_START, CONTENT_BUFFER_END).
 @param attributes The fully-processed attributes dictionary for this event.
 @param isPlaying Whether the player is currently in a playing state (from tracker state machine).
 */
- (void)processAction:(NSString *)action attributes:(NSDictionary *)attributes isPlaying:(BOOL)isPlaying;

/**
 Generate the QoE aggregate attributes dictionary.
 Includes the current in-progress bitrate segment in the average calculation
 so that intermediate reports (during playback) are accurate.

 @return Dictionary of KPI attributes, or nil if no CONTENT_REQUEST has been received.
 */
- (nullable NSDictionary *)generateAggregateAttributes;

/**
 Reset all QoE state for the next video session.
 Called after CONTENT_END once the final aggregate has been sent.
 */
- (void)reset;

/**
 Set the total pre-roll ad time for startup time calculation.
 Called before CONTENT_START to provide the aggregator with internal
 pre-roll ad duration for accurate startup time computation.

 @param preRollAdTime Total wall-clock time spent in pre-roll ads (ms).
 */
- (void)setTotalPreRollAdTime:(long)preRollAdTime;

@end

NS_ASSUME_NONNULL_END
