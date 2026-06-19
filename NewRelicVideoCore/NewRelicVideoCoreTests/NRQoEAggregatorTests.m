//
//  NRQoEAggregatorTests.m
//  NewRelicVideoCoreTests
//
//  Unit tests for NRQoEAggregator KPI computation.
//

@import XCTest;
#import "NRQoEAggregator.h"
#import "NRVideoDefs.h"

@interface NRQoEAggregatorTests : XCTestCase

@property (nonatomic) NRQoEAggregator *aggregator;

@end

@implementation NRQoEAggregatorTests

- (void)setUp {
    [super setUp];
    self.aggregator = [[NRQoEAggregator alloc] init];
}

- (void)tearDown {
    self.aggregator = nil;
    [super tearDown];
}

#pragma mark - Lifecycle / Gate

- (void)testReturnsNilBeforeContentRequest {
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result, @"Should return nil when no CONTENT_REQUEST has been received");
}

- (void)testReturnsNonNilAfterContentRequest {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNotNil(result, @"Should return non-nil after CONTENT_REQUEST");
}

- (void)testResetClearsState {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator reset];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result, @"Should return nil after reset");
}

#pragma mark - Startup Time

- (void)testStartupTimeBasic {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(5000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_STARTUP_TIME], @(5000));
}

- (void)testStartupTimeSubtractsPreRollAdTime {
    // Pre-roll ad time is set via setTotalPreRollAdTime: (the NRVideoTracker path),
    // not via the attributes dict — that key never appears in production event dicts.
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator setTotalPreRollAdTime:3000];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(8000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_STARTUP_TIME], @(5000));
}

- (void)testStartupTimeClampedToZero {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    // Pre-roll ad time exceeds timeSinceRequested — should clamp to 0.
    [self.aggregator setTotalPreRollAdTime:5000];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(2000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_STARTUP_TIME], @(0));
}

- (void)testStartupTimeNilBeforeContentStart {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_STARTUP_TIME], @"startupTime should be absent before CONTENT_START");
}

#pragma mark - Peak Bitrate

- (void)testPeakBitrateTracksHighest {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(2000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentBitrate": @(4000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentBitrate": @(3000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_PEAK_BITRATE], @(4000000));
}

- (void)testPeakBitrateZeroWhenNoBitrate {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_PEAK_BITRATE], @"peakBitrate should be absent when no bitrate observed");
}

- (void)testPeakBitrateFallsBackToRenditionBitrate {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentRenditionBitrate": @(1500000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_PEAK_BITRATE], @(1500000));
}

#pragma mark - Average Bitrate

- (void)testAverageBitrateConstant {
    // When bitrate doesn't change, average should equal that bitrate
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(3000000)}
                         isPlaying:YES];
    // Let a tiny bit of time pass so there's a non-zero duration
    [NSThread sleepForTimeInterval:0.05];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    long avgBitrate = [result[KPI_AVERAGE_BITRATE] longValue];
    XCTAssertEqualWithAccuracy(avgBitrate, 3000000, 100000,
                               @"Average bitrate should be ~3M for constant bitrate");
}

- (void)testAverageBitrateAbsentWhenNoBitrate {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_AVERAGE_BITRATE], @"averageBitrate should be absent when no bitrate");
}

#pragma mark - Rebuffering (First Buffer Skip)

- (void)testFirstBufferEndIsSkipped {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer — should be skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(0),
                          @"First buffer should be skipped");
}

- (void)testSecondBufferEndIsCounted {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer — skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500)}
                         isPlaying:YES];
    // Second buffer — counted
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(300)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(300));
}

- (void)testFirstBufferSkipIsSessionBased {
    // The first buffer is skipped regardless of bufferType — no bufferType attribute is used
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer with "connection" type — still skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500), @"bufferType": @"connection"}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(0),
                          @"First buffer should be skipped regardless of bufferType");
}

- (void)testMultipleRebufferingEventsAccumulate {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer — skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500)}
                         isPlaying:YES];
    // Second buffer — counted (200ms)
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(200)}
                         isPlaying:YES];
    // Third buffer — counted (300ms)
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(300)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(500));
}

- (void)testFirstBufferSkipResetsOnReset {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer — skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500)}
                         isPlaying:YES];
    // Second buffer — counted
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(200)}
                         isPlaying:YES];

    // Reset for next session
    [self.aggregator reset];

    // New session
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // First buffer of NEW session — should be skipped again
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(700)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(0),
                          @"First buffer of new session should be skipped after reset");
}

#pragma mark - Rebuffering Ratio

- (void)testRebufferingRatioNilBeforeStart {
    // Before CONTENT_START, rebuffering attributes are null (not yet measurable)
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_REBUFFERING_RATIO], @"Should be null before CONTENT_START");
    XCTAssertNil(result[KPI_TOTAL_REBUFFERING_TIME], @"Should be null before CONTENT_START");
}

- (void)testRebufferingRatioZeroAfterStartWithNoPlaytime {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_REBUFFERING_RATIO], @(0.0));
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(0));
}

- (void)testRebufferingRatioComputed {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"totalPlaytime": @(10000)}
                         isPlaying:YES];
    // Skip first buffer
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500), @"totalPlaytime": @(10000)}
                         isPlaying:YES];
    // Second buffer — 2000ms rebuffering
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(2000), @"totalPlaytime": @(10000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // ratio = (2000 / 10000) * 100 = 20.0%
    double ratio = [result[KPI_REBUFFERING_RATIO] doubleValue];
    XCTAssertEqualWithAccuracy(ratio, 20.0, 0.01);
}

#pragma mark - Error Flags

- (void)testHadStartupErrorBeforeStart {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_ERROR attributes:@{} isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_HAD_STARTUP_ERROR], @YES);
    // hadPlaybackError is null before CONTENT_START (not yet measurable)
    XCTAssertNil(result[KPI_HAD_PLAYBACK_ERROR], @"hadPlaybackError should be null before CONTENT_START");
}

- (void)testHadPlaybackErrorAfterStart {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_ERROR attributes:@{} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_HAD_STARTUP_ERROR], @NO);
    XCTAssertEqualObjects(result[KPI_HAD_PLAYBACK_ERROR], @YES);
}

- (void)testBothErrorFlagsCanBeTrue {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    // Error before start
    [self.aggregator processAction:CONTENT_ERROR attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // Error after start
    [self.aggregator processAction:CONTENT_ERROR attributes:@{} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_HAD_STARTUP_ERROR], @YES);
    XCTAssertEqualObjects(result[KPI_HAD_PLAYBACK_ERROR], @YES);
}

- (void)testNoErrorsByDefault {
    // Before CONTENT_START, error flags are null (not yet determined)
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_HAD_STARTUP_ERROR], @"Should be null before CONTENT_START");
    XCTAssertNil(result[KPI_HAD_PLAYBACK_ERROR], @"Should be null before CONTENT_START");

    // After CONTENT_START, flags become NO (determined — no errors occurred)
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_HAD_STARTUP_ERROR], @NO);
    XCTAssertEqualObjects(result[KPI_HAD_PLAYBACK_ERROR], @NO);
}

#pragma mark - Playtime Tracking

- (void)testTotalPlaytimeUpdatedFromAttributes {
    [self.aggregator processAction:CONTENT_REQUEST
                        attributes:@{@"totalPlaytime": @(0)}
                         isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"totalPlaytime": @(0)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"totalPlaytime": @(30000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // rebufferingRatio uses lastTotalPlaytime, which was set to 30000
    double ratio = [result[KPI_REBUFFERING_RATIO] doubleValue];
    XCTAssertEqualWithAccuracy(ratio, 0.0, 0.01,
                               @"Ratio should be 0%% with 0 rebuffering and 30s playtime");
}

#pragma mark - Bitrate Pause/Resume

- (void)testBitrateTimerPausesOnNonPlaying {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(2000000)}
                         isPlaying:YES];
    [NSThread sleepForTimeInterval:0.05];

    // Pause — timer should stop
    [self.aggregator processAction:CONTENT_PAUSE
                        attributes:@{@"contentBitrate": @(2000000)}
                         isPlaying:NO];

    // Long pause — should NOT accumulate bitrate time
    [NSThread sleepForTimeInterval:0.1];

    // Resume — timer restarts
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"contentBitrate": @(2000000)}
                         isPlaying:YES];
    [NSThread sleepForTimeInterval:0.05];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    long avgBitrate = [result[KPI_AVERAGE_BITRATE] longValue];
    // Bitrate was constant, so average should be ~2M regardless of pause
    XCTAssertEqualWithAccuracy(avgBitrate, 2000000, 200000,
                               @"Average bitrate should be ~2M, pause time excluded");
}

#pragma mark - CONTENT_END Flushes Bitrate

- (void)testContentEndFlushesBitrateSegment {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(2000000)}
                         isPlaying:YES];
    [NSThread sleepForTimeInterval:0.05];
    [self.aggregator processAction:CONTENT_END
                        attributes:@{@"contentBitrate": @(2000000)}
                         isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // After CONTENT_END, the segment is flushed. Average should be ~2M.
    XCTAssertNotNil(result[KPI_AVERAGE_BITRATE],
                    @"Average bitrate should be present after CONTENT_END");
}

#pragma mark - Full Session Scenario

- (void)testFullPlaybackSession {
    // Simulate: request → start → heartbeat → buffer → error → end
    [self.aggregator processAction:CONTENT_REQUEST
                        attributes:@{@"totalPlaytime": @(0)}
                         isPlaying:NO];

    [self.aggregator setTotalPreRollAdTime:1000];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{
                            @"timeSinceRequested": @(3000),
                            @"contentBitrate": @(2000000),
                            @"totalPlaytime": @(0)
                        }
                         isPlaying:YES];

    [NSThread sleepForTimeInterval:0.02];

    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentBitrate": @(2000000), @"totalPlaytime": @(30000)}
                         isPlaying:YES];

    // First buffer — skipped
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(1000), @"totalPlaytime": @(30000)}
                         isPlaying:YES];

    // Second buffer — counted
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(500), @"totalPlaytime": @(30000)}
                         isPlaying:YES];

    // Error during playback
    [self.aggregator processAction:CONTENT_ERROR
                        attributes:@{@"totalPlaytime": @(30000)}
                         isPlaying:YES];

    [self.aggregator processAction:CONTENT_END
                        attributes:@{@"contentBitrate": @(2000000), @"totalPlaytime": @(60000)}
                         isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];

    // Startup time = 3000 - 1000 = 2000ms
    XCTAssertEqualObjects(result[KPI_STARTUP_TIME], @(2000));

    // Peak bitrate = 2Mbps (constant)
    XCTAssertEqualObjects(result[KPI_PEAK_BITRATE], @(2000000));

    // Rebuffering time = 500ms (only second buffer counted)
    XCTAssertEqualObjects(result[KPI_TOTAL_REBUFFERING_TIME], @(500));

    // Error flags
    XCTAssertEqualObjects(result[KPI_HAD_STARTUP_ERROR], @NO);
    XCTAssertEqualObjects(result[KPI_HAD_PLAYBACK_ERROR], @YES);

    // Rebuffering ratio = (500 / 60000) * 100 ≈ 0.83%
    double ratio = [result[KPI_REBUFFERING_RATIO] doubleValue];
    XCTAssertEqualWithAccuracy(ratio, 0.833, 0.01);
}

#pragma mark - Reset Between Sessions

- (void)testResetClearsAllKPIs {
    // First session
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{
                            @"timeSinceRequested": @(2000),
                            @"contentBitrate": @(5000000),
                            @"totalPlaytime": @(10000)
                        }
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_ERROR attributes:@{} isPlaying:YES];

    // Skip first buffer
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(100), @"totalPlaytime": @(10000)}
                         isPlaying:YES];
    // Count second buffer
    [self.aggregator processAction:CONTENT_BUFFER_END
                        attributes:@{@"timeSinceBufferBegin": @(200), @"totalPlaytime": @(10000)}
                         isPlaying:YES];

    [self.aggregator reset];

    // Verify everything is cleared
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result, @"Should be nil after reset (no CONTENT_REQUEST in new session)");

    // Second session should start clean
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    result = [self.aggregator generateAggregateAttributes];

    XCTAssertNil(result[KPI_STARTUP_TIME], @"startupTime should be nil in new session");
    XCTAssertNil(result[KPI_PEAK_BITRATE], @"peakBitrate should be absent");
    // Before CONTENT_START in new session, these are null (not yet measurable)
    XCTAssertNil(result[KPI_TOTAL_REBUFFERING_TIME], @"Should be null before CONTENT_START");
    XCTAssertNil(result[KPI_HAD_STARTUP_ERROR], @"Should be null before CONTENT_START");
    XCTAssertNil(result[KPI_HAD_PLAYBACK_ERROR], @"Should be null before CONTENT_START");
}

#pragma mark - Ignored Bitrate Values

- (void)testZeroBitrateIsIgnored {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(0)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_PEAK_BITRATE], @"Zero bitrate should not be tracked");
    XCTAssertNil(result[KPI_AVERAGE_BITRATE], @"Zero bitrate should not produce average");
}

- (void)testNegativeBitrateIsIgnored {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentBitrate": @(-1000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_PEAK_BITRATE], @"Negative bitrate should not be tracked");
}

#pragma mark - Download Rate

- (void)testAvgDownloadRateIsArithmeticMean {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentNetworkDownloadBitrate": @(2000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(4000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(6000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // (2M + 4M + 6M) / 3 = 4M — arithmetic mean of samples, NOT time-weighted
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(4000000));
}

- (void)testMinMaxDownloadRate {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentNetworkDownloadBitrate": @(3000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(6000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(2000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_MIN_DOWNLOAD_RATE], @(2000000));
    XCTAssertEqualObjects(result[KPI_MAX_DOWNLOAD_RATE], @(6000000));
}

- (void)testDownloadRateAbsentWhenNoSamples {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_AVG_DOWNLOAD_RATE], @"Absent when no download rate sampled");
    XCTAssertNil(result[KPI_MIN_DOWNLOAD_RATE]);
    XCTAssertNil(result[KPI_MAX_DOWNLOAD_RATE]);
}

- (void)testDownloadRateIgnoresZeroNegativeAndNull {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentNetworkDownloadBitrate": @(0)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(-500)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": [NSNull null]}
                         isPlaying:YES];
    // Only this one is a valid sample
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(5000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(5000000));
    XCTAssertEqualObjects(result[KPI_MIN_DOWNLOAD_RATE], @(5000000));
    XCTAssertEqualObjects(result[KPI_MAX_DOWNLOAD_RATE], @(5000000));
}

- (void)testAvgDownloadRateRoundsToNearestInteger {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentNetworkDownloadBitrate": @(1000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(1000001)}
                         isPlaying:YES];
    // (1000000 + 1000001) / 2 = 1000000.5 → rounds to 1000001
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(1000001));
}

- (void)testDownloadRateResetsBetweenSessions {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000), @"contentNetworkDownloadBitrate": @(9000000)}
                         isPlaying:YES];
    [self.aggregator reset];

    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_AVG_DOWNLOAD_RATE], @"Should clear after reset");
    XCTAssertNil(result[KPI_MIN_DOWNLOAD_RATE], @"min must not leak across sessions");
    XCTAssertNil(result[KPI_MAX_DOWNLOAD_RATE], @"max must not leak across sessions");
}

#pragma mark - Rendition Switches

- (void)testSwitchUpsCounted {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"up"}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"up"}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(2));
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(0));
}

- (void)testSwitchDownsCounted {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"down"}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(1));
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(0));
}

- (void)testMixedSwitchSequence {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // up, down, down, up, up  → 3 ups, 2 downs
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"up"} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"down"} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"down"} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"up"} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"up"} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(3));
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(2));
}

- (void)testSwitchIgnoresMissingNullAndUnknownShift {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // No shift key at all
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{} isPlaying:YES];
    // shift is NSNull
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": [NSNull null]} isPlaying:YES];
    // shift is an unrecognized value
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"sideways"} isPlaying:YES];
    // One valid "up" to prove the handler still works after the bad ones
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"up"} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(1));
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(0));
}

- (void)testSwitchCountsEmittedAsZeroWhenNoChanges {
    // Counts are always emitted (mirrors Android), reading 0 before any rendition change.
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(0));
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(0));
}

- (void)testSwitchCountsResetBetweenSessions {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START attributes:@{@"timeSinceRequested": @(1000)} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"up"} isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{@"shift": @"down"} isPlaying:YES];
    [self.aggregator reset];

    // New session: counts must start fresh at 0
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_UPS], @(0), @"ups must not leak across sessions");
    XCTAssertEqualObjects(result[KPI_TOTAL_SWITCH_DOWNS], @(0), @"downs must not leak across sessions");
}

#pragma mark - Total Pause Time

// Helper: drive the aggregator into a "post-CONTENT_START" steady state so each
// pause-time test starts from the same baseline.
- (void)beginPauseTestSession {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
}

// Briefing case 1 — closed-only.
// pause → resume → assert KPI equals timeSincePaused exactly.
- (void)testTotalPauseTimeFromClosedSegmentOnly {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(2500)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(2500),
                          @"Closed segment must equal timeSincePaused exactly — "
                          @"no clock observation should leak in.");
}

// Briefing case 2 — mid-pause snapshot.
// pause → wait → snapshot → assert open-segment delta is included AND that
// the underlying accumulator was not mutated (catches the "local var, not self"
// gotcha from the briefing).
- (void)testTotalPauseTimeIncludesOpenSegmentMidPause {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [NSThread sleepForTimeInterval:0.05];

    NSDictionary *snap = [self.aggregator generateAggregateAttributes];
    long emitted = [snap[KPI_TOTAL_PAUSE_TIME] longValue];
    XCTAssertGreaterThanOrEqual(emitted, 30,
                                @"Open segment (~50ms) must be visible in mid-pause emit");
    XCTAssertLessThan(emitted, 500, @"sanity bound — emit should be ~50ms, well under 500ms");

    // KVC into the private accumulator: snapshot must NOT have written to self.
    long banked = [[self.aggregator valueForKey:@"totalPauseTime"] longValue];
    XCTAssertEqual(banked, 0L,
                   @"Open-segment branch must use a local var. If self.totalPauseTime "
                   @"got mutated here, the next RESUME will double-count.");
}

// Briefing case 3 — no double count.
// pause → snapshot mid-pause → resume → snapshot → assert resume value is
// exactly timeSincePaused. If the open-segment branch had leaked into self,
// the post-resume value would be ~2500 + ~50ms = ~2550. The point of this
// test is to fail fast if that regression is ever introduced.
- (void)testTotalPauseTimeNoDoubleCountAfterResume {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [NSThread sleepForTimeInterval:0.05];

    // Mid-pause snapshot — the trap. Discarded; we only care about the side effect.
    (void)[self.aggregator generateAggregateAttributes];

    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(2500)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(2500),
                          @"Post-resume value must equal timeSincePaused exactly. "
                          @"Any leftover from the mid-pause snapshot would double-count.");
}

// Multiple pause-resume cycles must accumulate, not overwrite.
- (void)testTotalPauseTimeAccumulatesAcrossMultipleCycles {
    [self beginPauseTestSession];

    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(1000)}
                         isPlaying:YES];

    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(500)}
                         isPlaying:YES];

    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(750)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(2250),
                          @"Three cycles of 1000+500+750 must sum to 2250");
}

// Pre-CONTENT_START "pauses" (e.g. weird player flow) must not appear in the
// emitted dict — same gate as totalRebufferingTime.
- (void)testTotalPauseTimeAbsentBeforeContentStart {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(1000)}
                         isPlaying:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNil(result[KPI_TOTAL_PAUSE_TIME],
                 @"Pre-start pauses must be absent from the emit (hasReceivedStart gate)");
}

// reset() must clear both the closed accumulator AND the open-segment timer,
// otherwise pause state from the previous session leaks into the new one.
- (void)testResetClearsBothPauseFields {
    [self beginPauseTestSession];

    // Build up some closed-segment state and leave an open segment armed.
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(1234)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];

    [self.aggregator reset];

    XCTAssertEqual(0L, [[self.aggregator valueForKey:@"totalPauseTime"] longValue],
                   @"reset must clear the closed-segment accumulator");
    XCTAssertEqualWithAccuracy(0.0,
                               [[self.aggregator valueForKey:@"pauseStartTimestamp"] doubleValue],
                               0.0001,
                               @"reset must disarm the open-segment timer — "
                               @"otherwise the next emit would add a huge bogus delta.");
}

// CONTENT_RESUME without timeSincePaused in the dict must not crash and must
// not poison the accumulator. The pauseStartTimestamp must still be disarmed
// so the next snapshot doesn't keep adding a stale open segment.
- (void)testTotalPauseTimeHandlesMissingTimeSincePausedAttribute {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME attributes:@{} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(0),
                          @"Missing timeSincePaused must be a graceful no-op (not a crash)");
    XCTAssertEqualWithAccuracy(0.0,
                               [[self.aggregator valueForKey:@"pauseStartTimestamp"] doubleValue],
                               0.0001,
                               @"Even without timeSincePaused, RESUME must disarm the timer.");
}

// Successive mid-pause snapshots during a long pause must report monotonically
// increasing values. This is the live-harvest case the briefing's "verify
// before declaring done" step calls out.
- (void)testTotalPauseTimeGrowsMonotonicallyAcrossMidPauseHarvests {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];

    [NSThread sleepForTimeInterval:0.03];
    long snap1 = [[self.aggregator generateAggregateAttributes][KPI_TOTAL_PAUSE_TIME] longValue];

    [NSThread sleepForTimeInterval:0.05];
    long snap2 = [[self.aggregator generateAggregateAttributes][KPI_TOTAL_PAUSE_TIME] longValue];

    [NSThread sleepForTimeInterval:0.05];
    long snap3 = [[self.aggregator generateAggregateAttributes][KPI_TOTAL_PAUSE_TIME] longValue];

    XCTAssertGreaterThan(snap2, snap1, @"second mid-pause snapshot must be > first");
    XCTAssertGreaterThan(snap3, snap2, @"third mid-pause snapshot must be > second");
}

#pragma mark - Ad-Break Pause Exclusion

// A content pause that brackets an ad break (player paused for the ad) must NOT
// be counted in totalPauseTime. isAdBreak is true at CONTENT_PAUSE (adBreakActive:YES)
// but already cleared by CONTENT_RESUME (adBreakActive:NO) — the fix keys off the
// armed timer, so the closed segment is skipped.
- (void)testAdBreakPauseExcludedFromTotalPauseTime {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO adBreakActive:YES];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(30000)}
                         isPlaying:YES adBreakActive:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(0),
                          @"Ad-break pause must be excluded from totalPauseTime");
}

// A real user pause still counts; an ad-break pause in the same view is excluded.
// Proves the gate is selective, not a blanket suppression.
- (void)testUserPauseCountsButAdBreakPauseDoesNot {
    [self beginPauseTestSession];
    // Real user pause — counts.
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO adBreakActive:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(5000)}
                         isPlaying:YES adBreakActive:NO];
    // Ad-break pause — excluded.
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO adBreakActive:YES];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(30000)}
                         isPlaying:YES adBreakActive:NO];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(5000),
                          @"Only the user pause counts; ad-break pause excluded");
}

// The 3-arg processAction: (no adBreakActive) must still count a normal pause —
// backward-compatible default of adBreakActive:NO.
- (void)testThreeArgProcessActionStillCountsPause {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_RESUME
                        attributes:@{@"timeSincePaused": @(4000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_PAUSE_TIME], @(4000),
                          @"3-arg API must behave as a non-ad-break (user) pause");
}

// A mid-ad-break harvest snapshot must not add an open segment for an ad-break pause
// (the open-segment branch keys off pauseStartTimestamp, which was never armed).
- (void)testAdBreakPauseNotInMidBreakSnapshot {
    [self beginPauseTestSession];
    [self.aggregator processAction:CONTENT_PAUSE attributes:@{} isPlaying:NO adBreakActive:YES];
    [NSThread sleepForTimeInterval:0.05];

    NSDictionary *snap = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(snap[KPI_TOTAL_PAUSE_TIME], @(0),
                          @"Open ad-break pause must not appear in a mid-break snapshot");
}

#pragma mark - Download Rate Dedup

// Stale-sample dedup. AVPlayer's accessLog.events.lastObject keeps returning
// the same entry between real network events, so every-event observation
// would otherwise count the same throughput value over and over and bias the
// average toward whichever rate was sticky during the longest idle window.
- (void)testDownloadRateSkipsConsecutiveDuplicates {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    // 5 Mbps reported across 10 events — only the first is a real new download.
    for (int i = 0; i < 10; i++) {
        [self.aggregator processAction:CONTENT_HEARTBEAT
                            attributes:@{@"contentNetworkDownloadBitrate": @(5000000)}
                             isPlaying:YES];
    }
    // 7 Mbps reported across 5 events — only the first is a real new download.
    for (int i = 0; i < 5; i++) {
        [self.aggregator processAction:CONTENT_HEARTBEAT
                            attributes:@{@"contentNetworkDownloadBitrate": @(7000000)}
                             isPlaying:YES];
    }

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // True mean over the two distinct events: (5M + 7M) / 2 = 6M.
    // Without dedup this would skew toward 5M because of the 10:5 weighting.
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(6000000),
                          @"Stale repeats must be skipped — average reflects "
                          @"distinct samples, not event count.");
    XCTAssertEqualObjects(result[KPI_MIN_DOWNLOAD_RATE], @(5000000));
    XCTAssertEqualObjects(result[KPI_MAX_DOWNLOAD_RATE], @(7000000));
}

// A → B → A pattern: dedup is consecutive only. If the rate genuinely returns
// to a previous value (real new download that happens to clock the same), it
// must count again — the access log entry is fresh, the value is just equal.
- (void)testDownloadRateAcceptsNonConsecutiveDuplicates {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(3000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(7000000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(3000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    // 3 distinct events: (3M + 7M + 3M) / 3 ≈ 4_333_333
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(4333333),
                          @"A→B→A pattern: the second 3M is a fresh event, must count");
}

// Reset clears lastDownloadRateSample — a fresh session must accept the same
// value the previous session ended on as a brand-new sample.
- (void)testResetClearsLastDownloadRateSample {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(5000000)}
                         isPlaying:YES];

    [self.aggregator reset];
    XCTAssertNil([self.aggregator valueForKey:@"lastDownloadRateSample"],
                 @"reset must clear lastDownloadRateSample");

    // New session ending in the SAME 5M value — must count, not be deduped
    // against the stale lastDownloadRateSample from before the reset.
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_HEARTBEAT
                        attributes:@{@"contentNetworkDownloadBitrate": @(5000000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_AVG_DOWNLOAD_RATE], @(5000000),
                          @"Post-reset session must accept the value as a new sample");
}

#pragma mark - Total Renditions

// Helper: send a CONTENT_RENDITION_CHANGE with the given W/H. This is the
// real path the set is fed from (CONTENT_HEARTBEAT does NOT touch the
// set — rendition tracking is event-driven, not sample-driven).
- (void)observeRenditionWidth:(long)width height:(long)height {
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"contentRenditionWidth":  @(width),
                                     @"contentRenditionHeight": @(height)}
                         isPlaying:YES];
}

// 3 distinct W×H pairs → count of 3.
- (void)testTotalRenditionsCountsDistinctValues {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000),
                                     @"contentRenditionWidth":  @(640),
                                     @"contentRenditionHeight": @(360)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"up",
                                     @"contentRenditionWidth":  @(1280),
                                     @"contentRenditionHeight": @(720)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"up",
                                     @"contentRenditionWidth":  @(1920),
                                     @"contentRenditionHeight": @(1080)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(3),
                          @"Three distinct W×H pairs should count as 3");
}

// Same W×H repeated → count of 1 (set dedup).
- (void)testTotalRenditionsDedupsRepeatedValues {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000),
                                     @"contentRenditionWidth":  @(1280),
                                     @"contentRenditionHeight": @(720)}
                         isPlaying:YES];
    for (int i = 0; i < 10; i++) {
        [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                            attributes:@{@"contentRenditionWidth":  @(1280),
                                         @"contentRenditionHeight": @(720)}
                             isPlaying:YES];
    }
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(1),
                          @"10 observations of the same W×H must count as 1");
}

// Initial rendition seeded at CONTENT_START — no RENDITION_CHANGE needed.
// This is the iOS-specific fix: NRTrackerAVPlayer doesn't fire the change
// event for the initial variant (NRTrackerAVPlayer.m:351-354).
- (void)testTotalRenditionsSeedsFromContentStart {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000),
                                     @"contentRenditionWidth":  @(1920),
                                     @"contentRenditionHeight": @(1080)}
                         isPlaying:YES];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(1),
                          @"CONTENT_START's W×H must seed the set without "
                          @"requiring a CONTENT_RENDITION_CHANGE event.");
}

// Invalid values must never enter the set.
- (void)testTotalRenditionsIgnoresInvalidValues {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000)}
                         isPlaying:YES];

    // 0/negative
    [self observeRenditionWidth:0 height:0];
    [self observeRenditionWidth:-1 height:1080];
    [self observeRenditionWidth:1920 height:-1];

    // NSNull
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"contentRenditionWidth":  [NSNull null],
                                     @"contentRenditionHeight": @(1080)}
                         isPlaying:YES];

    // Missing
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE attributes:@{} isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(0),
                          @"None of the invalid inputs should enter the set");
}

// Always emitted, even at 0 (per spec §4 "Always (0 valid)").
- (void)testTotalRenditionsEmittedWhenZero {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertNotNil(result[KPI_TOTAL_RENDITIONS],
                    @"totalRenditions must be present even pre-CONTENT_START");
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(0),
                          @"Pre-start value must be 0, not absent");
}

// reset() clears the set so a new session doesn't inherit prior renditions.
- (void)testResetClearsPlayedRenditions {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000),
                                     @"contentRenditionWidth":  @(640),
                                     @"contentRenditionHeight": @(360)}
                         isPlaying:YES];
    [self observeRenditionWidth:1280 height:720];
    [self observeRenditionWidth:1920 height:1080];
    XCTAssertEqual(3u,
                   [(NSSet *)[self.aggregator valueForKey:@"playedRenditions"] count]);

    [self.aggregator reset];
    XCTAssertEqual(0u,
                   [(NSSet *)[self.aggregator valueForKey:@"playedRenditions"] count],
                   @"reset must empty the set");
}

// Same W×H delivered via different event types must collide in the set —
// 1280×720 from CONTENT_START and from CONTENT_RENDITION_CHANGE share a hash.
- (void)testTotalRenditionsDedupsAcrossEventTypes {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(1000),
                                     @"contentRenditionWidth":  @(1280),
                                     @"contentRenditionHeight": @(720)}
                         isPlaying:YES];
    [self.aggregator processAction:CONTENT_RENDITION_CHANGE
                        attributes:@{@"shift": @"none",
                                     @"contentRenditionWidth":  @(1280),
                                     @"contentRenditionHeight": @(720)}
                         isPlaying:YES];
    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_TOTAL_RENDITIONS], @(1),
                          @"Same W×H seen via two different event types must dedupe");
}

@end
