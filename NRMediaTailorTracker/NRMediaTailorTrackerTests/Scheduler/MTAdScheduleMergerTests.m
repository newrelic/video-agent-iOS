//
//  MTAdScheduleMergerTests.m
//  NRMediaTailorTrackerTests
//
//  Unit tests for the schedule merger: manifest/tracking-API enrichment,
//  no-fill and mismatch handling, dedup, missing-avail-start fallback, and
//  the creativeId-based identity check.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTAdScheduleMerger.h>
#import <NRMediaTailorTracker/MergedSchedule.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>
#import <NRMediaTailorTracker/MTAvail.h>
#import <NRMediaTailorTracker/MTAd.h>
#import <NRMediaTailorTracker/MTTrackingResponse.h>
#import <NRMediaTailorTracker/MTAdErrorCode.h>

@interface MTAdScheduleMergerTests : XCTestCase
@end

@implementation MTAdScheduleMergerTests

#pragma mark - Helpers

- (MTAdBreak *)breakAtMs:(NSTimeInterval)startMs durationMs:(NSTimeInterval)durMs pods:(NSArray<NSValue *> *)pods {
    MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:nil startTimeMs:startMs durationMs:durMs];
    for (NSValue *v in pods) {
        NSRange r = v.rangeValue; // (location=startMs, length=durMs)
        MTAdPod *p = [[MTAdPod alloc] initWithStartTimeMs:r.location durationMs:r.length];
        [br.pods addObject:p];
    }
    return br;
}

- (MTTrackingResponse *)trackingWithDict:(NSDictionary *)dict {
    return [MTTrackingResponse fromDictionary:dict];
}

#pragma mark - Golden path

- (void)testGolden_oneBreakTwoPodsTwoAds_mergedCorrectly {
    MTAdBreak *br = [self breakAtMs:1000 durationMs:10000
                               pods:@[[NSValue valueWithRange:NSMakeRange(1000, 5000)],
                                      [NSValue valueWithRange:NSMakeRange(6000, 4000)]]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"avail-1",
            @"startTimeInSeconds": @1.0,
            @"durationInSeconds": @10.0,
            @"ads": @[
                @{@"adId": @"ad-A", @"creativeId": @"cr-A", @"adTitle": @"Ad A",
                  @"adSystem": @"BrandA",
                  @"startTimeInSeconds": @1.0, @"durationInSeconds": @5.0},
                @{@"adId": @"ad-B", @"creativeId": @"cr-B", @"adTitle": @"Ad B",
                  @"adSystem": @"BrandB",
                  @"startTimeInSeconds": @6.0, @"durationInSeconds": @4.0},
            ],
        }],
    };

    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];

    XCTAssertEqual(result.breaks.count, 1u);
    XCTAssertEqual(result.pendingErrors.count, 0u);

    MTAdBreak *merged = result.breaks.firstObject;
    XCTAssertEqualObjects(merged.availId, @"avail-1");
    XCTAssertEqual(merged.pods.count, 2u);
    XCTAssertFalse(merged.podCountMismatch);
    XCTAssertFalse(merged.isNoFill);

    XCTAssertEqualObjects(merged.pods[0].adTitle, @"Ad A");
    XCTAssertEqualObjects(merged.pods[0].adId, @"ad-A");
    XCTAssertEqualObjects(merged.pods[1].adTitle, @"Ad B");
    XCTAssertEqualObjects(merged.pods[1].adId, @"ad-B");
}

#pragma mark - Empty ads → no-fill

- (void)testEmptyAdsInAvail_breakMarkedNoFillAndQueuesError {
    MTAdBreak *br = [self breakAtMs:5000 durationMs:3000 pods:@[]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"no-fill-1",
            @"startTimeInSeconds": @5.0,
            @"durationInSeconds": @3.0,
            @"ads": @[],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];

    XCTAssertEqual(result.breaks.count, 1u);
    MTAdBreak *merged = result.breaks.firstObject;
    XCTAssertTrue(merged.isNoFill, @"empty avail must flag break as no-fill");

    XCTAssertEqual(result.pendingErrors.count, 1u);
    MTMergedScheduleError *err = result.pendingErrors.firstObject;
    XCTAssertEqual(err.errorCode, MTAdErrorCodeNoFill);
    XCTAssertEqual(err.adBreak, merged);
}

- (void)testEmptyAvailWithNoManifestCounterpart_synthesizesNoFillBreak {
    // Tracking returns an empty avail at 8 s but the manifest has no break
    // there yet (e.g. tracking-API ahead of the player). Merger must still
    // surface an AD_BREAK_START/END pair so the customer sees the no-fill.
    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"no-fill-2",
            @"startTimeInSeconds": @8.0,
            @"durationInSeconds": @5.0,
            @"ads": @[],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[]
                                                    trackingResponse:[self trackingWithDict:json]];
    XCTAssertEqual(result.breaks.count, 1u);
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertTrue(br.isNoFill);
    XCTAssertEqualObjects(br.availId, @"no-fill-2");
    XCTAssertEqual(result.pendingErrors.count, 1u);
}

#pragma mark - Pod-count mismatch keeps manifest geometry

- (void)testManifest2PodsTracking3Ads_keepsManifestPodsAndFlagsMismatch {
    MTAdBreak *br = [self breakAtMs:0 durationMs:15000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 7000)],
                                      [NSValue valueWithRange:NSMakeRange(7000, 8000)]]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"avail-mismatch",
            @"startTimeInSeconds": @0.0,
            @"durationInSeconds": @15.0,
            @"ads": @[
                @{@"adId": @"a1", @"creativeId": @"c1", @"adTitle": @"first",
                  @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0},
                @{@"adId": @"a2", @"creativeId": @"c2", @"adTitle": @"second",
                  @"startTimeInSeconds": @5.0, @"durationInSeconds": @5.0},
                @{@"adId": @"a3", @"creativeId": @"c3", @"adTitle": @"third",
                  @"startTimeInSeconds": @10.0, @"durationInSeconds": @5.0},
            ],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];

    XCTAssertEqual(result.breaks.count, 1u);
    MTAdBreak *merged = result.breaks.firstObject;
    XCTAssertEqual(merged.pods.count, 2u, @"manifest pod count is preserved");
    XCTAssertTrue(merged.podCountMismatch);

    // First pod at 0 ms is closest to ad a1 at 0 s; second pod at 7000 ms
    // is closest to ad a2 at 5 s (delta 2 s) — NOT a3 at 10 s (delta 3 s).
    XCTAssertEqualObjects(merged.pods[0].adId, @"a1");
    XCTAssertEqualObjects(merged.pods[1].adId, @"a2");

    BOOL gotMismatchError = NO;
    for (MTMergedScheduleError *e in result.pendingErrors) {
        if (e.errorCode == MTAdErrorCodeManifestTrackingMismatch) { gotMismatchError = YES; break; }
    }
    XCTAssertTrue(gotMismatchError);
}

#pragma mark - Live-window slide dedup

- (void)testSameAvailIdAndProgramDateTime_deduplicated {
    MTAdBreak *first = [self breakAtMs:30000 durationMs:5000 pods:@[]];
    first.availId = @"live-avail-1";
    first.availProgramDateTime = @"2026-06-22T18:00:00.000Z";

    // Same wall-clock identity but a different relative startTimeMs — the
    // typical live window slide pattern. Without the compound key fix this
    // would duplicate.
    MTAdBreak *second = [self breakAtMs:10000 durationMs:5000 pods:@[]];
    second.availId = @"live-avail-1";
    second.availProgramDateTime = @"2026-06-22T18:00:00.000Z";

    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[first, second]
                                                    trackingResponse:nil];
    XCTAssertEqual(result.breaks.count, 1u, @"compound (availId, programDateTime) dedup");
    XCTAssertEqualObjects(result.breaks.firstObject.availProgramDateTime, @"2026-06-22T18:00:00.000Z");
}

- (void)testDifferentProgramDateTime_notDeduplicated {
    MTAdBreak *first = [self breakAtMs:30000 durationMs:5000 pods:@[]];
    first.availId = @"live-avail-1";
    first.availProgramDateTime = @"2026-06-22T18:00:00.000Z";

    MTAdBreak *second = [self breakAtMs:30000 durationMs:5000 pods:@[]];
    second.availId = @"live-avail-1";
    second.availProgramDateTime = @"2026-06-22T18:05:00.000Z";

    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[first, second]
                                                    trackingResponse:nil];
    XCTAssertEqual(result.breaks.count, 2u, @"distinct wall-clocks must NOT collapse");
}

#pragma mark - Missing avail start

- (void)testMissingAvailStartTime_logsAndQueuesError {
    MTAdBreak *br = [self breakAtMs:0 durationMs:5000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)]]];
    br.startTimeIsUnknown = YES; // manifest genuinely didn't know this break's position

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"broken-avail",
            // NO startTimeInSeconds
            @"durationInSeconds": @5.0,
            @"ads": @[
                @{@"adId": @"a1", @"creativeId": @"c1",
                  @"startTimeInSeconds": @42.0, @"durationInSeconds": @5.0},
            ],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];

    BOOL gotMissingStart = NO;
    for (MTMergedScheduleError *e in result.pendingErrors) {
        if (e.errorCode == MTAdErrorCodeMissingAvailStart) { gotMissingStart = YES; break; }
    }
    XCTAssertTrue(gotMissingStart, @"missing avail start must surface MISSING_AVAIL_START error");
    // And the merger must still produce the break (fallback worked).
    XCTAssertEqual(result.breaks.count, 1u);
    XCTAssertEqualWithAccuracy(result.breaks.firstObject.startTimeMs, 42000.0, 0.01,
                               @"break with a genuinely unknown start must adopt the first ad's startTime");
}

- (void)testDoesNotOverwriteLegitimateZeroPositionPreroll {
    // A real preroll parsed at position 0 — startTimeIsUnknown defaults to NO,
    // so this must NOT be confused with the "unknown position" placeholder
    // that also happens to be 0.
    MTAdBreak *br = [self breakAtMs:0 durationMs:5000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)]]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"broken-avail",
            // NO startTimeInSeconds
            @"durationInSeconds": @5.0,
            @"ads": @[
                @{@"adId": @"a1", @"creativeId": @"c1",
                  @"startTimeInSeconds": @42.0, @"durationInSeconds": @5.0},
            ],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];

    XCTAssertEqual(result.breaks.count, 1u);
    XCTAssertEqualWithAccuracy(result.breaks.firstObject.startTimeMs, 0.0, 0.01,
                               @"a legitimate preroll at position 0 must not be clobbered by the A8 fallback");
}

#pragma mark - creativeId is the primary identity

- (void)testCreativeIdUsedAsPrimaryIdentityOverAdId {
    MTAdBreak *br = [self breakAtMs:0 durationMs:5000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)]]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"avail-1",
            @"startTimeInSeconds": @0.0,
            @"durationInSeconds": @5.0,
            @"ads": @[
                @{@"adId": @"ad-99", @"creativeId": @"creative-xyz", @"adTitle": @"with creative",
                  @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0},
            ],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];
    MTAdPod *pod = result.breaks.firstObject.pods.firstObject;
    XCTAssertEqualObjects(pod.primaryKey, @"creative-xyz",
                          @"primaryKey must come from creativeId");
}

- (void)testMissingCreativeId_fallsBackToCompositeKey {
    MTAdBreak *br = [self breakAtMs:0 durationMs:5000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)]]];

    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"avail-1",
            @"startTimeInSeconds": @0.0,
            @"durationInSeconds": @5.0,
            @"ads": @[
                @{@"adId": @"ad-99", @"adTitle": @"no creative",
                  @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0},
            ],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];
    MTAdPod *pod = result.breaks.firstObject.pods.firstObject;
    XCTAssertEqualObjects(pod.primaryKey, @"avail-1:ad-99",
                          @"missing creativeId must fall back to composite");
}

#pragma mark - Edge cases

- (void)testNilInputs_returnsEmptySchedule {
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:nil trackingResponse:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 0u);
    XCTAssertEqual(result.pendingErrors.count, 0u);
    XCTAssertEqual(result.podCountMismatchCount, 0u);
    XCTAssertEqual(result.dataIntegrityWarningCount, 0u);
}

#pragma mark - Manifest-only flow

- (void)testManifestOnly_nilTracking_breaksPassThroughUnchanged {
    MTAdBreak *br1 = [self breakAtMs:1000 durationMs:5000
                                pods:@[[NSValue valueWithRange:NSMakeRange(1000, 5000)]]];
    MTAdBreak *br2 = [self breakAtMs:20000 durationMs:8000
                                pods:@[[NSValue valueWithRange:NSMakeRange(20000, 8000)]]];

    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br1, br2]
                                                    trackingResponse:nil];

    XCTAssertEqual(result.breaks.count, 2u);
    XCTAssertEqual(result.pendingErrors.count, 0u);
    XCTAssertEqual(result.podCountMismatchCount, 0u);
    XCTAssertEqual(result.dataIntegrityWarningCount, 0u);
    XCTAssertEqual(result.breaks[0].pods.count, 1u);
    XCTAssertEqual(result.breaks[1].pods.count, 1u);
}

#pragma mark - Counters

- (void)testCounters_podCountMismatchCount_aggregatesAcrossBreaks {
    MTAdBreak *br1 = [self breakAtMs:0 durationMs:10000
                                pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)],
                                       [NSValue valueWithRange:NSMakeRange(5000, 5000)]]];
    MTAdBreak *br2 = [self breakAtMs:30000 durationMs:10000
                                pods:@[[NSValue valueWithRange:NSMakeRange(30000, 5000)],
                                       [NSValue valueWithRange:NSMakeRange(35000, 5000)]]];

    NSDictionary *json = @{
        @"avails": @[
            @{@"availId": @"a1", @"startTimeInSeconds": @0.0, @"durationInSeconds": @10.0,
              @"ads": @[@{@"adId": @"x1", @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0},
                        @{@"adId": @"x2", @"startTimeInSeconds": @5.0, @"durationInSeconds": @5.0},
                        @{@"adId": @"x3", @"startTimeInSeconds": @8.0, @"durationInSeconds": @2.0}]},
            @{@"availId": @"a2", @"startTimeInSeconds": @30.0, @"durationInSeconds": @10.0,
              @"ads": @[@{@"adId": @"y1", @"startTimeInSeconds": @30.0, @"durationInSeconds": @5.0},
                        @{@"adId": @"y2", @"startTimeInSeconds": @33.0, @"durationInSeconds": @4.0},
                        @{@"adId": @"y3", @"startTimeInSeconds": @37.0, @"durationInSeconds": @3.0}]},
        ],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br1, br2]
                                                    trackingResponse:[self trackingWithDict:json]];
    XCTAssertEqual(result.podCountMismatchCount, 2u, @"both breaks have manifest=2 vs tracking=3");
}

- (void)testCounters_dataIntegrityWarningCount_countsMissingAvailStart {
    MTAdBreak *br = [self breakAtMs:0 durationMs:5000
                               pods:@[[NSValue valueWithRange:NSMakeRange(0, 5000)]]];
    NSDictionary *json = @{
        @"avails": @[@{
            @"availId": @"broken",
            @"durationInSeconds": @5.0,
            @"ads": @[@{@"adId": @"a", @"creativeId": @"c",
                        @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0}],
        }],
    };
    MergedSchedule *result = [MTAdScheduleMerger mergeManifestBreaks:@[br]
                                                    trackingResponse:[self trackingWithDict:json]];
    XCTAssertEqual(result.dataIntegrityWarningCount, 1u);
}

@end
