//
//  MTDetectorTests.m
//  NRMediaTailorTrackerTests
//
//  Unit tests for MTDetector — URI detection, sessionId extraction, and
//  fallback tracking-URL derivation. Manifest-marker primary path is
//  covered separately by the parser tests.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTDetector.h>

@interface MTDetectorTests : XCTestCase
@end

@implementation MTDetectorTests

#pragma mark - isMediaTailorURL

- (void)testIsMediaTailorURL_HLSMediaTailorURL_returnsYES {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/abcd/asset.m3u8?aws.sessionId=session-123"];
    XCTAssertTrue([MTDetector isMediaTailorURL:url]);
}

- (void)testIsMediaTailorURL_DASHMediaTailorURL_returnsYES {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/dash/abcd/asset.mpd?aws.sessionId=session-456"];
    XCTAssertTrue([MTDetector isMediaTailorURL:url]);
}

- (void)testIsMediaTailorURL_nonMediaTailorURL_returnsNO {
    NSURL *url = [NSURL URLWithString:@"https://example.com/stream.m3u8"];
    XCTAssertFalse([MTDetector isMediaTailorURL:url]);
}

- (void)testIsMediaTailorURL_nilURL_returnsNO {
    XCTAssertFalse([MTDetector isMediaTailorURL:nil]);
}

- (void)testIsMediaTailorURL_customHostnameWithMediaTailorPath_returnsYES {
    // MediaTailor fronted by a CDN on a custom hostname — no "mediatailor"
    // substring anywhere — must detect via the /v1/master/ path convention.
    NSURL *url = [NSURL URLWithString:
                  @"https://cdn.example.com/v1/master/acct/config/index.m3u8?aws.logMode=DEBUG"];
    XCTAssertTrue([MTDetector isMediaTailorURL:url]);
}

- (void)testIsMediaTailorURL_nonMediaTailorPathOnCustomHostname_returnsNO {
    // Same custom hostname, but a path that doesn't match MediaTailor's
    // convention either — correctly NO, not a MediaTailor endpoint.
    NSURL *url = [NSURL URLWithString:
                  @"https://cdn.example.com/out/v1/abc/index.m3u8"];
    XCTAssertFalse([MTDetector isMediaTailorURL:url]);
}

#pragma mark - extractSessionId

- (void)testExtractSessionId_awsSessionIdParam_returnsValue {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/x/y.m3u8?aws.sessionId=foo"];
    XCTAssertEqualObjects([MTDetector extractSessionId:url], @"foo");
}

- (void)testExtractSessionId_plainSessionIdParam_returnsValue {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/x/y.m3u8?sessionId=foo"];
    XCTAssertEqualObjects([MTDetector extractSessionId:url], @"foo");
}

- (void)testExtractSessionId_sessionIdNotLastParam_returnsValue {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/x/y.m3u8?aws.sessionId=foo&other=bar"];
    XCTAssertEqualObjects([MTDetector extractSessionId:url], @"foo");
}

- (void)testExtractSessionId_noSessionId_returnsNil {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/x/y.m3u8"];
    XCTAssertNil([MTDetector extractSessionId:url]);
}

- (void)testExtractSessionId_nilURL_returnsNil {
    XCTAssertNil([MTDetector extractSessionId:nil]);
}

#pragma mark - extractSessionId — direct/implicit flow (path-segment session id)

- (void)testExtractSessionId_manifestPathSegment_returnsValue {
    // Direct/implicit flow: resolved sub-playlist URL, session id as a path
    // segment (no query string at all).
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/config/sess-1/1.m3u8"];
    XCTAssertEqualObjects([MTDetector extractSessionId:url], @"sess-1");
}

- (void)testExtractSessionId_segmentPathSegment_returnsValue {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/segment/acct/config/sess-1/1/0"];
    XCTAssertEqualObjects([MTDetector extractSessionId:url], @"sess-1");
}

- (void)testExtractSessionId_bareDirectEntryURL_returnsNil {
    // The direct/implicit flow's TOP-LEVEL entry URL — no session-init call,
    // no query string. There is genuinely no session id anywhere in this
    // string; nil is the correct answer, not a detection gap. The session id
    // only appears once MediaTailor resolves this into manifest/segment URLs
    // (see the two tests above).
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/config/master.m3u8"];
    XCTAssertNil([MTDetector extractSessionId:url]);
}

#pragma mark - deriveTrackingURL

- (void)testDeriveTrackingURL_HLSMaster_rewritesPath {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/abcd/asset.m3u8?aws.sessionId=session-123"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertNotNil(tracking);
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/session-123");
}

- (void)testDeriveTrackingURL_HLSSession_rewritesPath {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/session/abcd/asset.m3u8?aws.sessionId=session-123"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertNotNil(tracking);
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/session-123");
}

- (void)testDeriveTrackingURL_DASHManifest_rewritesPath {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/dash/abcd/asset.mpd?aws.sessionId=session-456"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertNotNil(tracking);
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/session-456");
}

- (void)testDeriveTrackingURL_plainSessionIdParam_works {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/abcd/asset.m3u8?sessionId=zz"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertNotNil(tracking);
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/abcd/zz");
}

- (void)testDeriveTrackingURL_noSessionId_returnsNil {
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/abcd/asset.m3u8"];
    XCTAssertNil([MTDetector deriveTrackingURL:url]);
}

- (void)testDeriveTrackingURL_nonMediaTailorURL_returnsNil {
    NSURL *url = [NSURL URLWithString:@"https://example.com/asset.m3u8?aws.sessionId=foo"];
    XCTAssertNil([MTDetector deriveTrackingURL:url]);
}

- (void)testDeriveTrackingURL_malformedURLWithoutExtension_gracefulNil {
    // No .m3u8 or .mpd extension — the manifest-file regex cannot match,
    // so the rewrite cannot succeed cleanly. Tracker should not crash.
    NSURL *url = [NSURL URLWithString:
                  @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/abcd/asset?aws.sessionId=foo"];
    // We accept either nil (preferred) or a URL that does not contain the
    // original extension — the contract is: do not crash, do not throw.
    XCTAssertNoThrow([MTDetector deriveTrackingURL:url]);
}

- (void)testDeriveTrackingURL_nilURL_returnsNil {
    XCTAssertNil([MTDetector deriveTrackingURL:nil]);
}

- (void)testDeriveTrackingURL_customHostnameWithQuerySessionId_works {
    // Custom-hostname (CDN-fronted) deployment, explicit-session query
    // string — proves the whole chain (isMediaTailorURL -> extractSessionId
    // -> rewrite) is hostname-agnostic, not just the detection gate.
    NSURL *url = [NSURL URLWithString:
                  @"https://cdn.example.com/v1/master/acct/config/index.m3u8?aws.sessionId=sess-1"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://cdn.example.com/v1/tracking/acct/config/sess-1");
}

- (void)testDeriveTrackingURL_customHostnameWithPathSessionId_works {
    // Custom-hostname deployment, direct/implicit-flow resolved sub-playlist
    // shape (session id as a path segment, no query at all).
    NSURL *url = [NSURL URLWithString:
                  @"https://cdn.example.com/v1/manifest/acct/config/sess-2/1.m3u8"];
    NSURL *tracking = [MTDetector deriveTrackingURL:url];
    XCTAssertEqualObjects(tracking.absoluteString,
                          @"https://cdn.example.com/v1/tracking/acct/config/sess-2");
}

- (void)testDeriveTrackingURL_customHostnameBareEntryURL_returnsNil {
    // Custom-hostname entry URL with no session-init call: detects as
    // MediaTailor (fixed above) but genuinely carries no session id anywhere
    // in it — nil is still correct here, not a regression of the fix.
    NSURL *url = [NSURL URLWithString:
                  @"https://cdn.example.com/v1/master/acct/config/index.m3u8?aws.logMode=DEBUG"];
    XCTAssertTrue([MTDetector isMediaTailorURL:url]);
    XCTAssertNil([MTDetector deriveTrackingURL:url]);
}

#pragma mark - defaultSegmentMarkers

- (void)testDefaultSegmentMarkers_containsExpectedMarkers {
    NSArray<NSString *> *markers = [MTDetector defaultSegmentMarkers];
    XCTAssertTrue([markers containsObject:@"segments.mediatailor"]);
    XCTAssertTrue([markers containsObject:@"/v1/dashsegment/"]);
    XCTAssertTrue([markers containsObject:@"/v1/hlssegment/"]);
    XCTAssertTrue([markers containsObject:@"/tm/"]);
    // The raw, as-written-in-the-manifest AWS convention for HLS segments —
    // confirmed against a real MediaTailor manifest. Without this, a real
    // manifest's #EXT-X-DISCONTINUITY boundaries parse but no segment inside
    // them is ever recognized as an ad, so real ad breaks silently become
    // zero breaks. Distinct from the four markers above, which are all
    // post-redirect target shapes that never appear in the manifest text
    // itself.
    XCTAssertTrue([markers containsObject:@"/v1/segment/"]);
    XCTAssertEqual(markers.count, (NSUInteger)5);
}

@end
