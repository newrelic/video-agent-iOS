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
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(8000), @"totalPreRollAdTime": @(3000)}
                         isPlaying:YES];

    NSDictionary *result = [self.aggregator generateAggregateAttributes];
    XCTAssertEqualObjects(result[KPI_STARTUP_TIME], @(5000));
}

- (void)testStartupTimeClampedToZero {
    [self.aggregator processAction:CONTENT_REQUEST attributes:@{} isPlaying:NO];
    // Pre-roll ad time exceeds timeSinceRequested — should clamp to 0
    [self.aggregator processAction:CONTENT_START
                        attributes:@{@"timeSinceRequested": @(2000), @"totalPreRollAdTime": @(5000)}
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

    [self.aggregator processAction:CONTENT_START
                        attributes:@{
                            @"timeSinceRequested": @(3000),
                            @"totalPreRollAdTime": @(1000),
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

@end
