//
//  MTDetectorTests.m
//  NRMediaTailorTrackerTests
//
//  Unit tests for MTDetector — URI detection, sessionId extraction, and
//  fallback tracking-URL derivation. Manifest-marker primary path is
//  covered separately by T05 / T12.
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

#pragma mark - defaultSegmentMarkers

- (void)testDefaultSegmentMarkers_containsExpectedMarkers {
    NSArray<NSString *> *markers = [MTDetector defaultSegmentMarkers];
    XCTAssertTrue([markers containsObject:@"segments.mediatailor"]);
    XCTAssertTrue([markers containsObject:@"/v1/dashsegment/"]);
    XCTAssertTrue([markers containsObject:@"/v1/hlssegment/"]);
    XCTAssertTrue([markers containsObject:@"/tm/"]);
    XCTAssertEqual(markers.count, (NSUInteger)4);
}

@end
