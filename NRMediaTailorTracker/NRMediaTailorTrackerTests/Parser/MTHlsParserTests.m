//
//  MTHlsParserTests.m
//  NRMediaTailorTrackerTests
//
//  Unit tests for MTHlsParser:
//   - Primary DATERANGE tracking-URL path (Bug B4)
//   - Fallback segment-marker break detection (no DATERANGE)
//   - Live PROGRAM-DATE-TIME propagation onto MTAdBreak (Bug A4/A8)
//   - Empty-avail manifest (no ad segments) returns zero breaks
//   - Pod-fits-in-break invariant + clamp helper (Bug A6)
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTHlsParser.h>
#import <NRMediaTailorTracker/MTManifestParseResult.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>

@interface MTHlsParserTests : XCTestCase
@end

@implementation MTHlsParserTests

#pragma mark - Helpers

- (NSString *)loadFixture:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:name withExtension:@"m3u8" subdirectory:@"HLS"];
    if (url == nil) {
        url = [bundle URLForResource:name withExtension:@"m3u8"];
    }
    XCTAssertNotNil(url, @"Fixture not found: %@", name);
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error, @"Failed to read fixture %@: %@", name, error);
    return text;
}

#pragma mark - Primary DATERANGE path

- (void)testParse_VODWithDateRange_recoversTrackingURLAndDetectsBreak {
    NSString *manifest = [self loadFixture:@"mediatailor_vod_with_daterange"];

    MTManifestParseResult *result =
        [MTHlsParser parseManifestText:manifest];

    XCTAssertNotNil(result.trackingURL);
    XCTAssertEqualObjects(result.trackingURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/sess-123");

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqualWithAccuracy(br.startTimeMs, 4000.0, 0.001); // 2 × 2s content first
    XCTAssertEqualWithAccuracy(br.durationMs, 6000.0, 0.001); // 3 × 2s ad
    XCTAssertEqualWithAccuracy(br.endTimeMs, 10000.0, 0.001);
    XCTAssertEqual(br.pods.count, (NSUInteger)1);

    MTAdPod *pod = br.pods.firstObject;
    XCTAssertEqualWithAccuracy(pod.startTimeMs, 4000.0, 0.001);
    XCTAssertEqualWithAccuracy(pod.durationMs, 6000.0, 0.001);
}

- (void)testParse_DateRangeTrackingClassVariant_alsoMatches {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:6\n"
        @"#EXT-X-TARGETDURATION:2\n"
        @"#EXT-X-PLAYLIST-TYPE:VOD\n"
        @"#EXT-X-DATERANGE:ID=\"av1\",CLASS=\"tracking\",URI=\"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/x/y\"\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/content/seg-0.ts\n"
        @"#EXT-X-ENDLIST\n";
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];
    XCTAssertNotNil(result.trackingURL);
    XCTAssertEqualObjects(result.trackingURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/x/y");
}

- (void)testParse_DateRangeNonTrackingClass_ignored {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-DATERANGE:ID=\"id-only\",CLASS=\"some.other.class\",URI=\"https://example.com/x\"\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/seg-0.ts\n";
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];
    XCTAssertNil(result.trackingURL);
}

- (void)testParse_RelativeURIInDateRange_resolvedAgainstManifestURL {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-DATERANGE:CLASS=\"com.apple.hls.interstitial\",URI=\"track/abc\"\n";
    NSURL *manifestURL = [NSURL URLWithString:@"https://host.example.com/v1/master/x/asset.m3u8"];
    MTManifestParseResult *result =
        [MTHlsParser parseManifestText:manifest manifestURL:manifestURL customSegmentMarkers:nil];
    XCTAssertNotNil(result.trackingURL);
    XCTAssertEqualObjects(result.trackingURL.absoluteString,
                          @"https://host.example.com/v1/master/x/track/abc");
}

#pragma mark - Fallback segment-marker path

- (void)testParse_VODWithSegmentMarkersOnly_detectsBreakWithTwoPods {
    NSString *manifest = [self loadFixture:@"mediatailor_vod_segment_markers_only"];
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];

    XCTAssertNil(result.trackingURL,
                 @"No DATERANGE present — caller must fall back to MTDetector.deriveTrackingURL:");

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqualWithAccuracy(br.startTimeMs, 4000.0, 0.001); // 1 × 4s content first
    XCTAssertEqualWithAccuracy(br.durationMs, 16000.0, 0.001); // 4 × 4s ad
    XCTAssertEqual(br.pods.count, (NSUInteger)2);

    MTAdPod *pod1 = br.pods[0];
    MTAdPod *pod2 = br.pods[1];
    XCTAssertEqualWithAccuracy(pod1.startTimeMs, 4000.0, 0.001);
    XCTAssertEqualWithAccuracy(pod1.durationMs, 8000.0, 0.001);
    XCTAssertEqualWithAccuracy(pod2.startTimeMs, 12000.0, 0.001);
    XCTAssertEqualWithAccuracy(pod2.durationMs, 8000.0, 0.001);
}

- (void)testParse_customSegmentMarker_picksUpNonDefaultCDNPath {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/content/seg-0.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/ads-custom/spot-0.ts\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/ads-custom/spot-1.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/content/seg-1.ts\n";

    // Without the custom marker, the parser sees no ad segments.
    MTManifestParseResult *r1 = [MTHlsParser parseManifestText:manifest];
    XCTAssertEqual(r1.breaks.count, (NSUInteger)0);

    // With the custom marker, the break is detected.
    MTManifestParseResult *r2 =
        [MTHlsParser parseManifestText:manifest manifestURL:nil customSegmentMarkers:@[@"/ads-custom/"]];
    XCTAssertEqual(r2.breaks.count, (NSUInteger)1);
    XCTAssertEqualWithAccuracy([r2.breaks.firstObject durationMs], 4000.0, 0.001);
}

#pragma mark - Live sliding window

- (void)testParse_LiveWithProgramDateTime_propagatesToAdBreak {
    NSString *manifest = [self loadFixture:@"mediatailor_live_sliding_window"];
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    MTAdBreak *br = result.breaks.firstObject;

    XCTAssertEqualWithAccuracy(br.startTimeMs, 12000.0, 0.001); // 2 × 6s content
    XCTAssertEqualWithAccuracy(br.durationMs, 18000.0, 0.001); // 3 × 6s ad
    XCTAssertEqualObjects(br.availProgramDateTime, @"2026-06-22T20:30:12.000Z");
}

#pragma mark - Empty avail manifest

- (void)testParse_EmptyAvailManifest_emitsNoFillBreakFromDateRange {
    NSString *manifest = [self loadFixture:@"mediatailor_empty_avail"];
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];

    XCTAssertNotNil(result.trackingURL,
                    @"DATERANGE is still present — tracking URL must be recovered even when stitched content has no ad segments");
    XCTAssertEqualObjects(result.trackingURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/sess-empty");

    // Atomic facts §6 — ad-server failure: tracker must emit AD_BREAK_START
    // / AD_BREAK_END for the slot even though no ad segments were stitched.
    // Parser surfaces a no-fill placeholder break so the merger / state
    // machine doesn't need the tracking-API path to recognise this case.
    XCTAssertEqual(result.breaks.count, (NSUInteger)1,
                   @"DATERANGE-only avail must surface as a no-fill placeholder break");
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertTrue(br.isNoFill, @"DATERANGE-only break must be flagged isNoFill");
    XCTAssertEqual(br.pods.count, (NSUInteger)0, @"No-fill break has zero pods");
    XCTAssertEqualObjects(br.availId, @"avail-empty");
    XCTAssertEqualObjects(br.availProgramDateTime, @"2026-06-22T20:00:00.000Z");
}

- (void)testParse_RealBreakPresent_DateRangeIsAbsorbedNotDuplicated {
    // Fixture 1 has both a DATERANGE entry AND real ad segments — the
    // DATERANGE must NOT produce a second (no-fill) break. The real break
    // takes precedence.
    NSString *manifest = [self loadFixture:@"mediatailor_vod_with_daterange"];
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    XCTAssertFalse(result.breaks.firstObject.isNoFill);
}

#pragma mark - Min ad duration filter

- (void)testParse_subMinDurationAdSegment_dropped {
    // Single ad segment of 400ms — under the 500ms min — should be dropped.
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/content/seg-0.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:0.4,\n"
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/hlssegment/abcd/blip-0.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:2.0,\n"
        @"https://cdn.example.com/content/seg-1.ts\n";
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

#pragma mark - Pod-fits-in-break invariant (Bug A6)

- (void)testParse_oversizePodFixture_naturalParseRespectsInvariant {
    NSString *manifest = [self loadFixture:@"mediatailor_oversize_pod"];
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqual(br.pods.count, (NSUInteger)3);

    // Invariant: every pod's end ≤ break's end (Bug A6).
    for (MTAdPod *pod in br.pods) {
        XCTAssertLessThanOrEqual(pod.endTimeMs, br.endTimeMs,
                                 @"Pod end (%f) must not exceed break end (%f)",
                                 pod.endTimeMs, br.endTimeMs);
        XCTAssertGreaterThanOrEqual(pod.startTimeMs, br.startTimeMs);
    }
    // Natural parse should not have clamped anything.
    XCTAssertEqual([MTHlsParser lastClampedPodCount], 0);
}

- (void)testClampPodIfNeeded_overshootingPod_isClampedToBreakEnd {
    MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:@"avail-x"
                                           startTimeMs:1000.0
                                            durationMs:5000.0]; // endTimeMs = 6000
    MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:3000.0
                                             durationMs:10000.0]; // endTimeMs = 13000 → overshoots

    BOOL clamped = [MTHlsParser clampPodIfNeeded:pod toBreak:br];
    XCTAssertTrue(clamped);
    XCTAssertEqualWithAccuracy(pod.durationMs, 3000.0, 0.001); // pulled back to 6000-3000
    XCTAssertEqualWithAccuracy(pod.endTimeMs, 6000.0, 0.001);
}

- (void)testClampPodIfNeeded_podWithinBreak_isNotModified {
    MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:@"avail-x"
                                           startTimeMs:1000.0
                                            durationMs:5000.0];
    MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:2000.0
                                             durationMs:3000.0]; // ends at 5000, inside [1000,6000)

    BOOL clamped = [MTHlsParser clampPodIfNeeded:pod toBreak:br];
    XCTAssertFalse(clamped);
    XCTAssertEqualWithAccuracy(pod.durationMs, 3000.0, 0.001);
}

#pragma mark - Edge cases

- (void)testParse_nilManifest_returnsEmptyResult {
    MTManifestParseResult *result = [MTHlsParser parseManifestText:nil];
    XCTAssertNil(result.trackingURL);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

- (void)testParse_emptyManifest_returnsEmptyResult {
    MTManifestParseResult *result = [MTHlsParser parseManifestText:@""];
    XCTAssertNil(result.trackingURL);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

- (void)testParse_contentOnlyManifest_returnsZeroBreaks {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-PLAYLIST-TYPE:VOD\n"
        @"#EXTINF:4.0,\n"
        @"https://cdn.example.com/content/seg-0.ts\n"
        @"#EXTINF:4.0,\n"
        @"https://cdn.example.com/content/seg-1.ts\n"
        @"#EXT-X-ENDLIST\n";
    MTManifestParseResult *result = [MTHlsParser parseManifestText:manifest];
    XCTAssertNil(result.trackingURL);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

@end
