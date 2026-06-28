//
//  MTDashParserTests.m
//  NRMediaTailorTrackerTests
//
//  Unit tests for MTDashParser (T16). Mirrors MTHlsParserTests' shape:
//   - Fixture-driven happy paths (VOD multi-period, dynamic live w/ SCTE-35).
//   - Bug A7: mixed-representation periods → classified as content, mixed
//     counter incremented.
//   - Negative paths (nil / empty / invalid UTF-8 / malformed XML / no periods).
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTDashParser.h>
#import <NRMediaTailorTracker/MTManifestParseResult.h>
#import <NRMediaTailorTracker/MTAdBreak.h>

@interface MTDashParserTests : XCTestCase
@end

@implementation MTDashParserTests

#pragma mark - Fixture loader

- (NSData *)loadFixture:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *url = [bundle URLForResource:name withExtension:@"mpd" subdirectory:@"DASH"];
    if (url == nil) {
        url = [bundle URLForResource:name withExtension:@"mpd"];
    }
    XCTAssertNotNil(url, @"Fixture not found: %@", name);
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&error];
    XCTAssertNil(error, @"Failed to read fixture %@: %@", name, error);
    return data;
}

#pragma mark - Fixture 1 — VOD content / ad / content

- (void)testParse_vodMultiperiod_emitsSingleAdBreakAtMiddlePeriod {
    NSData *mpd = [self loadFixture:@"mediatailor_dash_vod_multiperiod"];
    MTDashParser *parser = [[MTDashParser alloc] init];

    MTManifestParseResult *result = [parser parseManifest:mpd baseURL:nil];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)1, @"only the middle (ad) period must produce a break");

    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqualObjects(br.availId, @"avail-1");
    XCTAssertEqualWithAccuracy(br.startTimeMs, 10000.0, 0.001); // PT10S
    XCTAssertEqualWithAccuracy(br.durationMs, 8000.0, 0.001);   // PT8S
    XCTAssertEqual(br.pods.count, (NSUInteger)0, @"parser surfaces structural ad periods; merger enriches pods");
    XCTAssertFalse(br.isNoFill, @"structural ad periods are not no-fill");
    XCTAssertNil(result.trackingURL, @"no <Location> in this fixture");
    XCTAssertEqual(parser.mixedPeriodCount, (NSUInteger)0, @"no mixed-classification periods");
}

#pragma mark - Fixture 2 — dynamic live with SCTE-35

- (void)testParse_dynamicLiveWithScte35Event_emitsBreakWithAvailProgramDateTime {
    NSData *mpd = [self loadFixture:@"mediatailor_dash_dynamic_live"];
    MTDashParser *parser = [[MTDashParser alloc] init];

    MTManifestParseResult *result = [parser parseManifest:mpd baseURL:nil];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)1);

    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqualWithAccuracy(br.startTimeMs, 30000.0, 0.001);
    XCTAssertEqualWithAccuracy(br.durationMs, 15000.0, 0.001);

    // availabilityStartTime + 30s offset = 2026-06-29T12:00:30.000Z.
    XCTAssertNotNil(br.availProgramDateTime,
                    @"dynamic live with availabilityStartTime must populate availProgramDateTime (Bug A4)");
    XCTAssertTrue([br.availProgramDateTime hasPrefix:@"2026-06-29T12:00:30"],
                  @"expected 2026-06-29T12:00:30… but got %@", br.availProgramDateTime);
}

#pragma mark - Fixture 3 — A7 mixed-representation period

- (void)testParse_mixedRepresentations_classifiesAsContentAndCountsAsMixed {
    NSData *mpd = [self loadFixture:@"mediatailor_dash_mixed_representations"];
    MTDashParser *parser = [[MTDashParser alloc] init];

    MTManifestParseResult *result = [parser parseManifest:mpd baseURL:nil];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0,
                   @"Bug A7: when representations disagree, period must be classified as CONTENT (no break)");
    XCTAssertEqual(parser.mixedPeriodCount, (NSUInteger)1,
                   @"the single mixed period must increment the mixed-period counter");
}

- (void)testMixedPeriodCount_isPerInstance_notGlobal {
    // Two separate parser instances must each see their own count, not a shared one.
    NSData *mixed = [self loadFixture:@"mediatailor_dash_mixed_representations"];
    NSData *clean = [self loadFixture:@"mediatailor_dash_vod_multiperiod"];

    MTDashParser *p1 = [[MTDashParser alloc] init];
    MTDashParser *p2 = [[MTDashParser alloc] init];

    [p1 parseManifest:mixed baseURL:nil];
    [p2 parseManifest:clean baseURL:nil];

    XCTAssertEqual(p1.mixedPeriodCount, (NSUInteger)1);
    XCTAssertEqual(p2.mixedPeriodCount, (NSUInteger)0);
}

#pragma mark - Fixture 4 — no periods

- (void)testParse_noPeriods_returnsEmptyResultWithoutCrash {
    NSData *mpd = [self loadFixture:@"mediatailor_dash_no_periods"];
    MTDashParser *parser = [[MTDashParser alloc] init];

    MTManifestParseResult *result = [parser parseManifest:mpd baseURL:nil];

    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
    XCTAssertNil(result.trackingURL);
    XCTAssertEqual(parser.mixedPeriodCount, (NSUInteger)0);
}

#pragma mark - Location → tracking URL

- (void)testParse_locationElement_recoveredAsTrackingURL {
    NSString *mpd =
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        @"<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\" type=\"static\""
        @"     mediaPresentationDuration=\"PT10S\">"
        @"  <Location>https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/sess-xyz</Location>"
        @"  <Period id=\"content-0\" start=\"PT0S\" duration=\"PT10S\">"
        @"    <AdaptationSet mimeType=\"video/mp4\">"
        @"      <Representation id=\"v0\" bandwidth=\"600000\">"
        @"        <BaseURL>https://cdn.example.com/content/</BaseURL>"
        @"      </Representation>"
        @"    </AdaptationSet>"
        @"  </Period>"
        @"</MPD>";
    NSData *data = [mpd dataUsingEncoding:NSUTF8StringEncoding];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:data baseURL:nil];

    XCTAssertNotNil(result.trackingURL);
    XCTAssertEqualObjects(result.trackingURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/sess-xyz");
    XCTAssertEqual(result.breaks.count, (NSUInteger)0); // content-only period
}

#pragma mark - Min ad duration filter

- (void)testParse_subMinDurationAdPeriod_dropped {
    NSString *mpd =
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        @"<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\" type=\"static\">"
        @"  <Period id=\"blip\" start=\"PT0S\" duration=\"PT0.4S\">"
        @"    <AdaptationSet>"
        @"      <Representation id=\"v0\">"
        @"        <BaseURL>https://abc.segments.mediatailor.us-east-1.amazonaws.com/v1/dashsegment/x/</BaseURL>"
        @"      </Representation>"
        @"    </AdaptationSet>"
        @"  </Period>"
        @"</MPD>";
    NSData *data = [mpd dataUsingEncoding:NSUTF8StringEncoding];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:data baseURL:nil];
    XCTAssertEqual(result.breaks.count, (NSUInteger)0, @"sub-500ms ad period must be filtered out");
}

#pragma mark - Edge cases

- (void)testParse_nilManifest_returnsEmptyResult {
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:nil baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
    XCTAssertNil(result.trackingURL);
}

- (void)testParse_emptyManifest_returnsEmptyResult {
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:[NSData data] baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

- (void)testParse_invalidUTF8_returnsEmptyResult {
    uint8_t bytes[] = {0xFF, 0xFE, 0x80, 0x81, 0x82};
    NSData *bogus = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:bogus baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

- (void)testParse_malformedXml_returnsEmptyResult {
    NSData *bogus = [@"<?xml version=\"1.0\"?><MPD><Period start=\"PT0S\""
                     dataUsingEncoding:NSUTF8StringEncoding];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:bogus baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, (NSUInteger)0);
}

- (void)testParse_periodMissingDuration_skippedWithoutCrash {
    NSString *mpd =
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        @"<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\" type=\"static\">"
        @"  <Period id=\"no-duration\" start=\"PT0S\">"
        @"    <AdaptationSet>"
        @"      <Representation id=\"v0\">"
        @"        <BaseURL>https://abc.segments.mediatailor.us-east-1.amazonaws.com/v1/dashsegment/x/</BaseURL>"
        @"      </Representation>"
        @"    </AdaptationSet>"
        @"  </Period>"
        @"</MPD>";
    NSData *data = [mpd dataUsingEncoding:NSUTF8StringEncoding];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:data baseURL:nil];
    XCTAssertEqual(result.breaks.count, (NSUInteger)0,
                   @"period without duration must be skipped, not crash");
}

#pragma mark - Period start inferred from prior durations

- (void)testParse_periodWithoutStartAttribute_usesSumOfPriorDurations {
    NSString *mpd =
        @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
        @"<MPD xmlns=\"urn:mpeg:dash:schema:mpd:2011\" type=\"static\">"
        @"  <Period id=\"content-0\" duration=\"PT5S\">"
        @"    <AdaptationSet>"
        @"      <Representation id=\"v0\">"
        @"        <BaseURL>https://cdn.example.com/content/a/</BaseURL>"
        @"      </Representation>"
        @"    </AdaptationSet>"
        @"  </Period>"
        @"  <Period id=\"avail-1\" duration=\"PT7S\">"
        @"    <AdaptationSet>"
        @"      <Representation id=\"v0\">"
        @"        <BaseURL>https://abc.segments.mediatailor.us-east-1.amazonaws.com/v1/dashsegment/y/</BaseURL>"
        @"      </Representation>"
        @"    </AdaptationSet>"
        @"  </Period>"
        @"</MPD>";
    NSData *data = [mpd dataUsingEncoding:NSUTF8StringEncoding];
    MTDashParser *parser = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:data baseURL:nil];

    XCTAssertEqual(result.breaks.count, (NSUInteger)1);
    MTAdBreak *br = result.breaks.firstObject;
    XCTAssertEqualWithAccuracy(br.startTimeMs, 5000.0, 0.001,
                               @"second period's start must be inferred from first period's duration");
    XCTAssertEqualWithAccuracy(br.durationMs, 7000.0, 0.001);
}

@end
