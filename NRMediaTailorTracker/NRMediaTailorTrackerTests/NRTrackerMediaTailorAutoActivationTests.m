//
//  NRTrackerMediaTailorAutoActivationTests.m
//  NRMediaTailorTrackerTests
//
//  Covers the self-sufficient auto-activation flow triggered from
//  `-setPlayer:`: currentItem KVO -> manifest fetch -> parse -> resolve +
//  fetch tracking -> merge -> start tracking, with zero manual
//  `-startTrackingWithSchedule:` call. Mirrors
//  NRTrackerMediaTailorLifecycleTests.m's test-access category pattern to
//  inject stub-backed `manifestFetcher` / `trackingClient`, and
//  MTTrackingClientTests.m's stub-NSURLProtocol pattern to mock the network.
//
//  Fetches are async even against stubs (the fetcher/client always dispatch
//  their own network queue before delivering on main), so every scenario
//  waits via XCTNSPredicateExpectation / XCTWaiter on `activationStatus`
//  rather than asserting synchronously after `-setPlayer:`.
//

#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import <NRMediaTailorTracker/NRTrackerMediaTailor.h>
#import <NRMediaTailorTracker/MTManifestFetcher.h>
#import <NRMediaTailorTracker/MTTrackingClient.h>
#import <NRMediaTailorTracker/MTPlayheadStateMachine.h>
#import <NRMediaTailorTracker/MergedSchedule.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>

#pragma mark - Test-access categories (mirrors NRTrackerMediaTailorLifecycleTests.m)

@interface NRTrackerMediaTailor (AutoActivationTestingAccess)
@property (nonatomic, readonly, nullable) MTPlayheadStateMachine *stateMachine;
@property (nonatomic, strong, nullable) MTManifestFetcher *manifestFetcher;
@property (nonatomic, strong, nullable) MTTrackingClient *trackingClient;

/// Exposes the already-private production methods used to drive the bare
/// direct/implicit flow's second half, so tests can simulate "AVPlayer's
/// access log just revealed this" without needing a real, system-populated
/// `AVPlayerItemAccessLog` (which has no public way to synthesize entries).
- (nullable NSURL *)firstSessionCarryingURLFromMostRecentURIStrings:(NSArray<NSString *> *)uriStrings;
- (void)beginAutoActivationForURL:(NSURL *)url;
@end

@interface MTPlayheadStateMachine (AutoActivationTestingAccess)
@property (nonatomic, strong, readonly) MergedSchedule *schedule;
@end

#pragma mark - Manifest stub

typedef NS_ENUM(NSInteger, MTAAStubMode) {
    MTAAStubModeBody,
    MTAAStubModeHang,
};

@interface MTAAManifestStubProtocol : NSURLProtocol
+ (void)setBodyMode:(NSData *)body status:(NSInteger)status contentType:(nullable NSString *)contentType;
+ (void)setHangMode;
/// Registers a response for any request whose URL ends with `suffix`,
/// checked before the single-mode fallback above — lets a test serve a
/// different body for the top-level master vs. a rendition sub-playlist
/// fetched from within it.
+ (void)setBody:(NSData *)body status:(NSInteger)status contentType:(nullable NSString *)contentType forURLSuffix:(NSString *)suffix;
+ (void)reset;
+ (NSArray<NSURLRequest *> *)requestLog;
@end

static MTAAStubMode gMTAAManifestMode = MTAAStubModeBody;
static NSInteger gMTAAManifestStatus = 200;
static NSData *gMTAAManifestBody = nil;
static NSString *gMTAAManifestContentType = nil;
static NSMutableArray<NSURLRequest *> *gMTAAManifestLog = nil;
static NSMutableArray<NSDictionary *> *gMTAAManifestSuffixResponses = nil;

@implementation MTAAManifestStubProtocol

+ (void)setBodyMode:(NSData *)body status:(NSInteger)status contentType:(NSString *)contentType {
    gMTAAManifestMode = MTAAStubModeBody;
    gMTAAManifestStatus = status;
    gMTAAManifestBody = [body copy];
    gMTAAManifestContentType = [contentType copy];
}

+ (void)setHangMode {
    gMTAAManifestMode = MTAAStubModeHang;
}

+ (void)setBody:(NSData *)body status:(NSInteger)status contentType:(NSString *)contentType forURLSuffix:(NSString *)suffix {
    if (!gMTAAManifestSuffixResponses) { gMTAAManifestSuffixResponses = [NSMutableArray array]; }
    [gMTAAManifestSuffixResponses addObject:@{
        @"suffix": suffix,
        @"body": body ?: [NSData data],
        @"status": @(status),
        @"contentType": contentType ?: @"",
    }];
}

+ (void)reset {
    gMTAAManifestMode = MTAAStubModeBody;
    gMTAAManifestStatus = 200;
    gMTAAManifestBody = nil;
    gMTAAManifestContentType = nil;
    gMTAAManifestLog = [NSMutableArray array];
    gMTAAManifestSuffixResponses = [NSMutableArray array];
}

+ (NSArray<NSURLRequest *> *)requestLog { return [gMTAAManifestLog copy] ?: @[]; }

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!gMTAAManifestLog) gMTAAManifestLog = [NSMutableArray array];
    [gMTAAManifestLog addObject:request];
    return YES;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    if (gMTAAManifestMode == MTAAStubModeHang) { return; }

    NSString *urlString = self.request.URL.absoluteString;
    for (NSDictionary *entry in gMTAAManifestSuffixResponses) {
        if (![urlString hasSuffix:entry[@"suffix"]]) { continue; }
        NSMutableDictionary *headers = [NSMutableDictionary dictionary];
        NSString *contentType = entry[@"contentType"];
        if (contentType.length > 0) { headers[@"Content-Type"] = contentType; }
        NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:[entry[@"status"] integerValue]
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:headers];
        [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:entry[@"body"]];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    if (gMTAAManifestContentType.length > 0) { headers[@"Content-Type"] = gMTAAManifestContentType; }
    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:gMTAAManifestStatus
                                                         HTTPVersion:@"HTTP/1.1"
                                                        headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (gMTAAManifestBody) { [self.client URLProtocol:self didLoadData:gMTAAManifestBody]; }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Tracking stub

@interface MTAATrackingStubProtocol : NSURLProtocol
+ (void)setBodyMode:(NSData *)body status:(NSInteger)status;
+ (void)reset;
+ (NSArray<NSURLRequest *> *)requestLog;
@end

static NSInteger gMTAATrackingStatus = 200;
static NSData *gMTAATrackingBody = nil;
static NSMutableArray<NSURLRequest *> *gMTAATrackingLog = nil;

@implementation MTAATrackingStubProtocol

+ (void)setBodyMode:(NSData *)body status:(NSInteger)status {
    gMTAATrackingStatus = status;
    gMTAATrackingBody = [body copy];
}

+ (void)reset {
    gMTAATrackingStatus = 200;
    gMTAATrackingBody = nil;
    gMTAATrackingLog = [NSMutableArray array];
}

+ (NSArray<NSURLRequest *> *)requestLog { return [gMTAATrackingLog copy] ?: @[]; }

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!gMTAATrackingLog) gMTAATrackingLog = [NSMutableArray array];
    [gMTAATrackingLog addObject:request];
    return YES;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:gMTAATrackingStatus
                                                         HTTPVersion:@"HTTP/1.1"
                                                        headerFields:@{@"Content-Type": @"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (gMTAATrackingBody) { [self.client URLProtocol:self didLoadData:gMTAATrackingBody]; }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Fixtures

static NSData *MTAAEmptyTrackingBody(void) {
    NSDictionary *dict = @{ @"avails": @[], @"nonLinearAvails": @[] };
    return [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
}

/// Segment-markers-only VOD manifest (no DATERANGE tracking marker) — one ad
/// break, two segments, bracketed by content. Mirrors
/// Fixtures/HLS/mediatailor_vod_segment_markers_only.m3u8.
static NSData *MTAASegmentMarkersManifest(void) {
    NSString *text =
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:6\n"
        @"#EXT-X-TARGETDURATION:4\n"
        @"#EXT-X-PLAYLIST-TYPE:VOD\n"
        @"#EXTINF:4.0,\n"
        @"https://cdn.example.com/content/seg-0.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:4.0,\n"
        @"https://segments.mediatailor.us-east-1.amazonaws.com/abcd/ad-pod1-0.ts\n"
        @"#EXTINF:4.0,\n"
        @"https://segments.mediatailor.us-east-1.amazonaws.com/abcd/ad-pod1-1.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:4.0,\n"
        @"https://cdn.example.com/content/seg-1.ts\n"
        @"#EXT-X-ENDLIST\n";
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

/// Bare direct/implicit-flow manifest: the entry URL itself carries no
/// session id, but the first plain (non-`#`) line — a sub-playlist
/// reference MediaTailor would actually serve — does, as a path segment.
/// Same ad break shape as `MTAASegmentMarkersManifest`, with that reference
/// line prepended.
static NSData *MTAAImplicitFlowManifestWithRecoverableSessionId(NSString *sessionId) {
    NSString *text = [NSString stringWithFormat:
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:6\n"
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/cfg/%@/index.m3u8\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:4.0,\n"
        @"https://segments.mediatailor.us-east-1.amazonaws.com/abcd/ad-pod1-0.ts\n"
        @"#EXTINF:4.0,\n"
        @"https://segments.mediatailor.us-east-1.amazonaws.com/abcd/ad-pod1-1.ts\n"
        @"#EXT-X-DISCONTINUITY\n"
        @"#EXTINF:4.0,\n"
        @"https://cdn.example.com/content/seg-1.ts\n"
        @"#EXT-X-ENDLIST\n", sessionId];
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

/// Real-world shape confirmed against a live MediaTailor config: the
/// top-level URL AVPlayer actually plays is a multivariant master listing
/// renditions — no ad markers anywhere. This is the manifest fetched from
/// the *master* URL's request.
static NSData *MTAAMultivariantMasterManifest(void) {
    NSString *text =
        @"#EXTM3U\n"
        @"#EXT-X-VERSION:3\n"
        @"#EXT-X-STREAM-INF:BANDWIDTH=493000,RESOLUTION=224x100\n"
        @"rendition-0.m3u8\n"
        @"#EXT-X-STREAM-INF:BANDWIDTH=932000,RESOLUTION=448x200\n"
        @"rendition-1.m3u8\n";
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Tests

@interface NRTrackerMediaTailorAutoActivationTests : XCTestCase
@end

@implementation NRTrackerMediaTailorAutoActivationTests

- (void)setUp {
    [super setUp];
    [MTAAManifestStubProtocol reset];
    [MTAATrackingStubProtocol reset];
}

#pragma mark Helpers

- (NRTrackerMediaTailor *)makeStubbedTracker {
    NSURLSessionConfiguration *manifestConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    manifestConfig.protocolClasses = @[ [MTAAManifestStubProtocol class] ];
    manifestConfig.timeoutIntervalForRequest = 2.0;

    NSURLSessionConfiguration *trackingConfig = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    trackingConfig.protocolClasses = @[ [MTAATrackingStubProtocol class] ];
    trackingConfig.timeoutIntervalForRequest = 2.0;

    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    t.manifestFetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:manifestConfig];
    t.trackingClient = [[MTTrackingClient alloc] initWithSessionConfiguration:trackingConfig];
    return t;
}

- (void)waitForTracker:(NRTrackerMediaTailor *)tracker
          toReachStatus:(NRMediaTailorTrackingStatus)status
                timeout:(NSTimeInterval)timeout {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ((NRTrackerMediaTailor *)evaluatedObject).activationStatus == status;
    }];
    XCTNSPredicateExpectation *exp = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:tracker];
    XCTWaiter *waiter = [[XCTWaiter alloc] initWithDelegate:self];
    XCTWaiterResult result = [waiter waitForExpectations:@[exp] timeout:timeout];
    XCTAssertEqual(result, XCTWaiterResultCompleted,
                   @"tracker did not reach activationStatus %ld within %.1fs (last status: %ld)",
                   (long)status, timeout, (long)tracker.activationStatus);
}

#pragma mark 1. Explicit resolved-URL shape (?aws.sessionId=)

- (void)testExplicitResolvedURLShape_activatesEndToEndWithSchedulePopulated {
    NSURL *playerURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8?aws.sessionId=SID1"];
    [MTAAManifestStubProtocol setBodyMode:MTAASegmentMarkersManifest() status:200 contentType:@"application/vnd.apple.mpegurl"];
    [MTAATrackingStubProtocol setBodyMode:MTAAEmptyTrackingBody() status:200];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    XCTAssertEqual(t.activationStatus, NRMediaTailorTrackingStatusIdle);

    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusActive timeout:5.0];

    XCTAssertNotNil(t.stateMachine);
    XCTAssertGreaterThan(t.stateMachine.schedule.breaks.count, 0u, @"schedule must be populated");

    NSURL *trackingRequestURL = [MTAATrackingStubProtocol requestLog].firstObject.URL;
    XCTAssertEqualObjects(trackingRequestURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/acct/cfg/SID1");
    [t dispose];
}

#pragma mark 1b. Multivariant master (real-world shape) — resolves a rendition before parsing

// Confirmed against a live MediaTailor config: the top-level URL AVPlayer
// actually plays is a multivariant master with zero ad markers — parsing it
// directly would always find zero breaks, regardless of whether a real ad is
// playing. The tracker must detect this shape and fetch a rendition's media
// playlist (where ad markers actually live) before parsing.
- (void)testMultivariantMaster_resolvesRenditionBeforeFindingAnyBreaks {
    NSURL *playerURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8?aws.sessionId=SID1B"];
    [MTAAManifestStubProtocol setBodyMode:MTAAMultivariantMasterManifest() status:200 contentType:@"application/vnd.apple.mpegurl"];
    [MTAAManifestStubProtocol setBody:MTAASegmentMarkersManifest() status:200 contentType:@"application/vnd.apple.mpegurl"
                         forURLSuffix:@"rendition-0.m3u8"];
    [MTAATrackingStubProtocol setBodyMode:MTAAEmptyTrackingBody() status:200];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusActive timeout:5.0];

    XCTAssertGreaterThan(t.stateMachine.schedule.breaks.count, 0u,
                         @"breaks must be found once the rendition (not the ad-marker-less master) is parsed");

    NSArray<NSURLRequest *> *manifestRequests = [MTAAManifestStubProtocol requestLog];
    XCTAssertEqual(manifestRequests.count, 2u, @"must fetch the master, then exactly one rendition — not the master alone");
    XCTAssertTrue([manifestRequests.firstObject.URL.absoluteString containsString:@"master.m3u8"]);
    XCTAssertTrue([manifestRequests.lastObject.URL.absoluteString hasSuffix:@"rendition-0.m3u8"]);
    [t dispose];
}

#pragma mark 2. Bare direct/implicit shape

// A bare entry URL carries no session id, so fetching it ourselves would
// mint a session distinct from the one AVPlayer's own native HLS engine
// mints when *it* fetches the same URL to actually play the stream — the
// tracker would then track a schedule for a session nothing is playing
// (this was a real, confirmed bug: verified via real device logs showing
// two independent MediaTailor sessions minted from two independent GETs of
// the same bare URL). The fix: never fetch a bare URL directly — wait for
// AVPlayer's own `AVPlayerItemAccessLog` to reveal the session it's actually
// using, then resolve from *that*. `AVPlayerItemAccessLog` has no public way
// to synthesize entries in a unit test, so these tests exercise the two
// halves of that flow separately: (a) attaching a bare-URL player must NOT
// trigger a direct fetch, landing on `AwaitingSessionDiscovery` instead; (b)
// the pure scan helper that would run once a real access-log entry appeared,
// and the production hand-off (`-beginAutoActivationForURL:`) it feeds into,
// both work correctly in isolation. Real end-to-end confirmation (that an
// actual AVPlayerItemAccessLog entry drives this correctly) was done via a
// real device run against a live MediaTailor config, not simulate-able here.

- (void)testBareDirectImplicitShape_doesNotFetchDirectly_awaitsSessionDiscoveryInstead {
    NSURL *playerURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8"];
    // If the tracker fetched this bare URL itself, this body would resolve
    // to SID2-should-never-be-fetched — the point of this test is that it
    // never gets the chance to.
    [MTAAManifestStubProtocol setBodyMode:MTAAImplicitFlowManifestWithRecoverableSessionId(@"SID2-should-never-be-fetched")
                                    status:200 contentType:@"application/vnd.apple.mpegurl"];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    // NSKeyValueObservingOptionInitial delivers synchronously on setPlayer:'s
    // calling thread (main here), so this has already landed by the time
    // setPlayer: returns — mirrors the established assumption in test 5.
    XCTAssertEqual(t.activationStatus, NRMediaTailorTrackingStatusAwaitingSessionDiscovery);

    // Give any wrongly-issued fetch a beat to land, then confirm it never did.
    XCTestExpectation *settle = [self expectationWithDescription:@"settle"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settle fulfill];
    });
    [self waitForExpectations:@[settle] timeout:2.0];

    XCTAssertEqual([MTAAManifestStubProtocol requestLog].count, 0u,
                   @"a bare direct/implicit entry URL must never be fetched directly by the tracker — "
                   @"doing so mints a second, independent MediaTailor session distinct from the one "
                   @"AVPlayer itself mints to actually play the stream");
    XCTAssertEqual(t.activationStatus, NRMediaTailorTrackingStatusAwaitingSessionDiscovery,
                   @"must still be waiting — nothing should have advanced this without a real access-log entry");
    [t dispose];
}

- (void)testSessionDiscoveryScan_picksMostRecentURIWithASessionId {
    NRTrackerMediaTailor *t = [self makeStubbedTracker];

    NSArray<NSString *> *uriStrings = @[
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8", // no session id
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/cfg/SID-OLD/index.m3u8",
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/cfg/SID-NEW/index.m3u8", // most recent
    ];

    NSURL *resolved = [t firstSessionCarryingURLFromMostRecentURIStrings:uriStrings];

    XCTAssertEqualObjects(resolved.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/cfg/SID-NEW/index.m3u8",
                          @"must prefer the most recent (last) URI that carries a session id");
    [t dispose];
}

- (void)testSessionDiscoveryScan_returnsNilWhenNoURICarriesASessionId {
    NRTrackerMediaTailor *t = [self makeStubbedTracker];

    NSArray<NSString *> *uriStrings = @[
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8",
        @"https://cdn.example.com/content/plain-segment.ts",
    ];

    XCTAssertNil([t firstSessionCarryingURLFromMostRecentURIStrings:uriStrings]);
    [t dispose];
}

/// Once a real access-log entry would have revealed the session (simulated
/// here via the exposed `-beginAutoActivationForURL:` hand-off, since that's
/// exactly what `-trySessionDiscoveryFromAccessLogOfItem:originalURL:` calls
/// the moment it finds a qualifying URI), the rest of the pipeline —
/// manifest fetch, parse, tracking fetch, merge, activate — is identical to
/// the explicit-flow path already covered end-to-end by test 1.
- (void)testBareDirectImplicitShape_onceDiscovered_activatesEndToEndAgainstTheDiscoveredSession {
    NSURL *discoveredURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/manifest/acct/cfg/SID2/index.m3u8"];
    [MTAAManifestStubProtocol setBodyMode:MTAASegmentMarkersManifest() status:200 contentType:@"application/vnd.apple.mpegurl"];
    [MTAATrackingStubProtocol setBodyMode:MTAAEmptyTrackingBody() status:200];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    [t beginAutoActivationForURL:discoveredURL];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusActive timeout:5.0];

    NSURL *trackingRequestURL = [MTAATrackingStubProtocol requestLog].firstObject.URL;
    XCTAssertEqualObjects(trackingRequestURL.absoluteString,
                          @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/acct/cfg/SID2",
                          @"tracking request must target the discovered session, not a separately-minted one");
    [t dispose];
}

#pragma mark 3. CDN-fronted custom hostname (no "mediatailor" substring)

- (void)testCDNCustomHostname_eitherShape_stillActivatesEndToEnd {
    NSURL *playerURL = [NSURL URLWithString:@"https://cdn.example.com/v1/master/acct/cfg/master.m3u8?aws.sessionId=SID3"];
    [MTAAManifestStubProtocol setBodyMode:MTAASegmentMarkersManifest() status:200 contentType:@"application/vnd.apple.mpegurl"];
    [MTAATrackingStubProtocol setBodyMode:MTAAEmptyTrackingBody() status:200];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusActive timeout:5.0];

    XCTAssertGreaterThan(t.stateMachine.schedule.breaks.count, 0u);
    NSURL *trackingRequestURL = [MTAATrackingStubProtocol requestLog].firstObject.URL;
    XCTAssertEqualObjects(trackingRequestURL.absoluteString,
                          @"https://cdn.example.com/v1/tracking/acct/cfg/SID3",
                          @"MTDetector's path-convention fallback must drive the whole flow on a non-mediatailor hostname");
    [t dispose];
}

#pragma mark 4. Non-MediaTailor URL -> SkippedNotMediaTailor, no fetch ever issued

- (void)testNonMediaTailorURL_skipsCleanlyWithNoFetchIssued {
    NSURL *playerURL = [NSURL URLWithString:@"https://cdn.example.com/content/plain-video.mp4"];

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusSkippedNotMediaTailor timeout:2.0];

    XCTAssertEqual([MTAAManifestStubProtocol requestLog].count, 0u, @"a non-MediaTailor URL must never trigger a manifest fetch");
    XCTAssertEqual([MTAATrackingStubProtocol requestLog].count, 0u);
    XCTAssertNil(t.stateMachine);
    [t dispose];
}

#pragma mark 5. Manual schedule while an auto-fetch is in flight -> manual wins

- (void)testManualScheduleDuringInFlightAutoFetch_manualWinsAndLaterCompletionIsIgnored {
    NSURL *playerURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8?aws.sessionId=SID5"];
    [MTAAManifestStubProtocol setHangMode]; // the auto-fetch never completes on its own

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    // NSKeyValueObservingOptionInitial delivers synchronously on setPlayer:'s
    // calling thread (main here), so beginAutoActivationForURL: has already
    // run and set FetchingManifest by the time setPlayer: returns.
    XCTAssertEqual(t.activationStatus, NRMediaTailorTrackingStatusFetchingManifest);

    MTAdPod *manualPod = [[MTAdPod alloc] initWithStartTimeMs:1000 durationMs:2000];
    MTAdBreak *manualBreak = [[MTAdBreak alloc] initWithAvailId:@"manual-break" startTimeMs:1000 durationMs:2000];
    [manualBreak.pods addObject:manualPod];
    MergedSchedule *manualSchedule = [[MergedSchedule alloc] initWithBreaks:@[manualBreak] pendingErrors:@[]];

    [t startTrackingWithSchedule:manualSchedule];

    XCTAssertNotNil(t.stateMachine);
    XCTAssertEqualObjects(t.stateMachine.schedule.breaks.firstObject.availId, @"manual-break");

    // Give the cancelled (hung) auto-fetch's completion handler a beat to
    // land, then confirm the manual schedule is still the one in effect —
    // the suppression guard must have dropped the stale completion.
    XCTestExpectation *settle = [self expectationWithDescription:@"settle"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [settle fulfill];
    });
    [self waitForExpectations:@[settle] timeout:2.0];

    XCTAssertNotNil(t.stateMachine);
    XCTAssertEqualObjects(t.stateMachine.schedule.breaks.firstObject.availId, @"manual-break",
                          @"the manual schedule must still be in effect after the stale auto-fetch settles");
    [t dispose];
}

#pragma mark 6. Manifest OK, tracking fetch fails -> TrackingFetchFailed, manifest-only breaks still tracked

- (void)testTrackingFetchFails_manifestOnlyBreaksStillTracked {
    NSURL *playerURL = [NSURL URLWithString:
        @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8?aws.sessionId=SID6"];
    [MTAAManifestStubProtocol setBodyMode:MTAASegmentMarkersManifest() status:200 contentType:@"application/vnd.apple.mpegurl"];
    [MTAATrackingStubProtocol setBodyMode:[NSData data] status:500]; // non-2xx, no retry ambiguity

    NRTrackerMediaTailor *t = [self makeStubbedTracker];
    AVPlayer *player = [AVPlayer playerWithURL:playerURL];
    [t setPlayer:player];

    [self waitForTracker:t toReachStatus:NRMediaTailorTrackingStatusTrackingFetchFailed timeout:5.0];

    XCTAssertNotNil(t.activationStatusMessage);
    XCTAssertTrue([t.activationStatusMessage containsString:@"/v1/tracking/"],
                  @"message must call out the /v1/tracking/ path");
    XCTAssertTrue([t.activationStatusMessage.lowercaseString containsString:@"cdn"],
                  @"message must hint at CDN path-pattern misconfiguration");

    XCTAssertNotNil(t.stateMachine, @"manifest-only ad-break geometry must still be tracked");
    XCTAssertGreaterThan(t.stateMachine.schedule.breaks.count, 0u);
    [t dispose];
}

@end
