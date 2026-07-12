//
//  MTManifestParserSeamTests.m
//  NRMediaTailorTrackerTests
//
//  T11 — verify the manifest-parser seam.
//
//  Three contract guarantees the tests pin down:
//    1. `MTHlsParser` conforms to `MTManifestParser` and its instance method
//       parses the same HLS body as the legacy class method.
//    2. `MTDashParser` is a no-op stub: returns an empty result regardless of
//       input. (The NSLog warning is observable but not asserted to avoid
//       depending on the log subsystem.)
//    3. `-[NRTrackerMediaTailor setManifestParser:]` accepts any object
//       conforming to `MTManifestParser` without crashing.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTManifestParser.h>
#import <NRMediaTailorTracker/MTHlsParser.h>
#import <NRMediaTailorTracker/MTDashParser.h>
#import <NRMediaTailorTracker/MTManifestParseResult.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/NRTrackerMediaTailor.h>

@interface MTManifestParserSeamTests : XCTestCase
@end

@implementation MTManifestParserSeamTests

#pragma mark - MTHlsParser conformance

- (void)testHlsParser_conformsToMTManifestParser {
    XCTAssertTrue([MTHlsParser conformsToProtocol:@protocol(MTManifestParser)]);
    XCTAssertTrue([[MTHlsParser alloc] respondsToSelector:@selector(parseManifest:baseURL:)]);
}

- (void)testHlsParser_parseManifestBaseURL_handlesAdSegmentManifest {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:6\n"
        @"#EXT-X-TARGETDURATION:6\n"
        @"#EXTINF:6.0,\n"
        @"https://cdn.example.com/content/seg1.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:5.0,\n"
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/hlssegment/abc/0/seg-ad1.ts\n"
        @"#EXTINF:5.0,\n"
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/hlssegment/abc/0/seg-ad2.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:6.0,\n"
        @"https://cdn.example.com/content/seg2.ts\n"
        @"#EXT-X-ENDLIST\n";
    NSData *data = [manifest dataUsingEncoding:NSUTF8StringEncoding];
    id<MTManifestParser> parser = [[MTHlsParser alloc] init];

    MTManifestParseResult *result = [parser parseManifest:data baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 1u, @"one ad break expected");

    MTAdBreak *brk = result.breaks.firstObject;
    XCTAssertEqualWithAccuracy(brk.startTimeMs, 6000.0, 1.0);
    XCTAssertEqualWithAccuracy(brk.durationMs, 10000.0, 1.0);
}

/// P0-110: an ad segment on a non-default (custom-CDN) path is only detected
/// as an ad break when `customSegmentMarkers` is set on the parser instance —
/// this is what `NRTrackerMediaTailor.adSegmentPrefix` plumbs into.
- (void)testHlsParser_customSegmentMarkers_detectsCustomCDNAdSegments {
    NSString *manifest =
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:6\n"
        @"#EXT-X-TARGETDURATION:6\n"
        @"#EXTINF:6.0,\n"
        @"https://cdn.acme.example/content/seg1.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:5.0,\n"
        @"https://cdn.acme.example/ads/seg-ad1.ts\n"
        @"#EXTINF:5.0,\n"
        @"https://cdn.acme.example/ads/seg-ad2.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:6.0,\n"
        @"https://cdn.acme.example/content/seg2.ts\n"
        @"#EXT-X-ENDLIST\n";
    NSData *data = [manifest dataUsingEncoding:NSUTF8StringEncoding];

    // Without the custom marker, the /ads/ path is invisible → no ad break.
    MTHlsParser *plain = [[MTHlsParser alloc] init];
    XCTAssertEqual([plain parseManifest:data baseURL:nil].breaks.count, 0u,
                   @"custom-CDN ad path must not match default markers");

    // With the custom marker set, the same segments are classified as an ad.
    MTHlsParser *custom = [[MTHlsParser alloc] init];
    custom.customSegmentMarkers = @[@"/ads/"];
    MTManifestParseResult *result = [custom parseManifest:data baseURL:nil];
    XCTAssertEqual(result.breaks.count, 1u, @"custom marker should surface the ad break");
    XCTAssertEqualWithAccuracy(result.breaks.firstObject.durationMs, 10000.0, 1.0);
}

- (void)testHlsParser_parseManifestBaseURL_emptyDataReturnsEmptyResult {
    id<MTManifestParser> parser = [[MTHlsParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:[NSData data] baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 0u);
    XCTAssertNil(result.trackingURL);
}

- (void)testHlsParser_parseManifestBaseURL_nilDataReturnsEmptyResult {
    id<MTManifestParser> parser = [[MTHlsParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:nil baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 0u);
}

- (void)testHlsParser_parseManifestBaseURL_invalidUTF8ReturnsEmptyResult {
    // Pure non-UTF-8 bytes — initWithData:encoding:NSUTF8StringEncoding fails.
    uint8_t bytes[] = {0xFF, 0xFE, 0x80, 0x81};
    NSData *bogus = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    id<MTManifestParser> parser = [[MTHlsParser alloc] init];
    MTManifestParseResult *result = [parser parseManifest:bogus baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 0u);
}

#pragma mark - MTDashParser stub

- (void)testDashParser_conformsToMTManifestParser {
    XCTAssertTrue([MTDashParser conformsToProtocol:@protocol(MTManifestParser)]);
}

- (void)testDashParser_returnsEmptyResultForAnyInput {
    id<MTManifestParser> dash = [[MTDashParser alloc] init];
    NSString *mpd = @"<?xml version=\"1.0\"?><MPD></MPD>";
    NSData *data = [mpd dataUsingEncoding:NSUTF8StringEncoding];
    MTManifestParseResult *result = [dash parseManifest:data baseURL:[NSURL URLWithString:@"https://example.com/master.mpd"]];
    XCTAssertNotNil(result, @"stub must return non-nil empty result, not nil");
    XCTAssertEqual(result.breaks.count, 0u);
    XCTAssertNil(result.trackingURL);
}

- (void)testDashParser_returnsEmptyResultForNilInput {
    id<MTManifestParser> dash = [[MTDashParser alloc] init];
    MTManifestParseResult *result = [dash parseManifest:nil baseURL:nil];
    XCTAssertNotNil(result);
    XCTAssertEqual(result.breaks.count, 0u);
}

#pragma mark - Tracker injection

- (void)testTracker_setManifestParser_acceptsAnyConformingObject {
    NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc] init];
    XCTAssertNoThrow([tracker setManifestParser:[[MTHlsParser alloc] init]]);
    XCTAssertNoThrow([tracker setManifestParser:[[MTDashParser alloc] init]]);
}

- (void)testTracker_manifestParser_defaultsLazilyToMTHlsParser {
    NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc] init];
    id<MTManifestParser> parser = tracker.manifestParser;
    XCTAssertNotNil(parser);
    XCTAssertTrue([(NSObject *)parser isKindOfClass:[MTHlsParser class]],
                  @"untouched tracker must default to MTHlsParser");
}

- (void)testTracker_manifestParser_setterOverridesDefault {
    NRTrackerMediaTailor *tracker = [[NRTrackerMediaTailor alloc] init];
    MTDashParser *dash = [[MTDashParser alloc] init];
    tracker.manifestParser = dash;
    XCTAssertEqual(tracker.manifestParser, dash);
}

@end
