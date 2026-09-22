//
//  MTManifestFetcherTests.m
//  NRMediaTailorTrackerTests
//
//  Coverage for MTManifestFetcher: success (data/finalURL/contentType),
//  non-2xx / empty-body -> InvalidResponse, transient-error retry, mid-flight
//  cancel, and redirect -> finalURL reflects the post-redirect URL. Uses a
//  stub NSURLProtocol installed via NSURLSessionConfiguration.protocolClasses
//  to mock the network, mirroring MTTrackingClientTests.m's MTStubProtocol.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTManifestFetcher.h>

#pragma mark - Stub URLProtocol

typedef NS_ENUM(NSInteger, MTFetcherStubMode) {
    MTFetcherStubModeBody,    // return data + status (optionally from a distinct "final" URL, for redirect)
    MTFetcherStubModeError,   // fail with NSError
    MTFetcherStubModeHang,    // do nothing — caller will hit timeout / cancel
};

/// One-shot HTTP transcript installed via `+setNextMode:...`. Records the
/// request the fetcher made (so tests can assert on the requested URL) and
/// returns a configured response/body/error. `responseURL` lets a test
/// simulate a redirect: the response is constructed against `responseURL`
/// (the "final" URL) even though the request was made against a different
/// URL — the same technique `MTStubProtocol` would use if it needed it.
@interface MTFetcherStubProtocol : NSURLProtocol
+ (void)setNextMode:(MTFetcherStubMode)mode
             status:(NSInteger)status
               body:(nullable NSData *)body
        contentType:(nullable NSString *)contentType
        responseURL:(nullable NSURL *)responseURL
              error:(nullable NSError *)error;
+ (void)reset;
+ (NSArray<NSURLRequest *> *)requestLog;
@end

static MTFetcherStubMode gMode = MTFetcherStubModeBody;
static NSInteger gStatus = 200;
static NSData *gBody = nil;
static NSString *gContentType = nil;
static NSURL *gResponseURL = nil;
static NSError *gError = nil;
static NSMutableArray<NSURLRequest *> *gRequestLog = nil;

@implementation MTFetcherStubProtocol

+ (void)setNextMode:(MTFetcherStubMode)mode
             status:(NSInteger)status
               body:(NSData *)body
        contentType:(NSString *)contentType
        responseURL:(NSURL *)responseURL
              error:(NSError *)error {
    gMode = mode;
    gStatus = status;
    gBody = [body copy];
    gContentType = [contentType copy];
    gResponseURL = responseURL;
    gError = error;
}

+ (void)reset {
    gMode = MTFetcherStubModeBody;
    gStatus = 200;
    gBody = nil;
    gContentType = nil;
    gResponseURL = nil;
    gError = nil;
    gRequestLog = [NSMutableArray array];
}

+ (NSArray<NSURLRequest *> *)requestLog {
    return [gRequestLog copy] ?: @[];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!gRequestLog) gRequestLog = [NSMutableArray array];
    [gRequestLog addObject:request];
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    if (gMode == MTFetcherStubModeHang) {
        return; // never call any client method
    }
    if (gMode == MTFetcherStubModeError && gError) {
        [self.client URLProtocol:self didFailWithError:gError];
        return;
    }
    NSURL *responseURL = gResponseURL ?: self.request.URL;
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    if (gContentType.length > 0) {
        headers[@"Content-Type"] = gContentType;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:responseURL
                                                              statusCode:gStatus
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:headers];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (gBody) {
        [self.client URLProtocol:self didLoadData:gBody];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Flip stub (deterministic retry coverage)

/// Fails the first `failCount` requests with `error`, then succeeds with
/// `successBody` (status 200). Counter-based rather than timer-based —
/// MTManifestFetcher retries immediately with no delay, so a wall-clock flip
/// would race the retry. Mirrors MTTrackingClientTests.m's MTStubFlipProtocol.
@interface MTFetcherFlipProtocol : NSURLProtocol
+ (void)configureWithFailCount:(NSInteger)failCount error:(NSError *)error successBody:(nullable NSData *)successBody;
/// Fails the first `failCount` requests with HTTP `failStatus` (no NSError —
/// a real, if unusual, HTTP response) instead of a transport-level error,
/// then succeeds. Covers the 409-then-retry-succeeds path distinctly from
/// the transport-error flip above.
+ (void)configureWithFailStatus:(NSInteger)failStatus count:(NSInteger)failCount successBody:(nullable NSData *)successBody;
+ (NSInteger)requestCount;
@end

static NSInteger gFlipFailCount = 0;
static NSError *gFlipError = nil;
static NSInteger gFlipFailStatus = 0;
static NSData *gFlipSuccessBody = nil;
static NSInteger gFlipRequestCount = 0;

@implementation MTFetcherFlipProtocol

+ (void)configureWithFailCount:(NSInteger)failCount error:(NSError *)error successBody:(NSData *)successBody {
    gFlipFailCount = failCount;
    gFlipError = error;
    gFlipFailStatus = 0;
    gFlipSuccessBody = [successBody copy];
    gFlipRequestCount = 0;
}

+ (void)configureWithFailStatus:(NSInteger)failStatus count:(NSInteger)failCount successBody:(NSData *)successBody {
    gFlipFailCount = failCount;
    gFlipError = nil;
    gFlipFailStatus = failStatus;
    gFlipSuccessBody = [successBody copy];
    gFlipRequestCount = 0;
}

+ (NSInteger)requestCount { return gFlipRequestCount; }

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    gFlipRequestCount++;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    if (gFlipRequestCount <= gFlipFailCount) {
        if (gFlipError != nil) {
            [self.client URLProtocol:self didFailWithError:gFlipError];
            return;
        }
        NSHTTPURLResponse *failResponse = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                       statusCode:gFlipFailStatus
                                                                      HTTPVersion:@"HTTP/1.1"
                                                                     headerFields:@{}];
        [self.client URLProtocol:self didReceiveResponse:failResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:200
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (gFlipSuccessBody.length > 0) {
        [self.client URLProtocol:self didLoadData:gFlipSuccessBody];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Tests

@interface MTManifestFetcherTests : XCTestCase
@property (nonatomic, strong) MTManifestFetcher *fetcher;
@property (nonatomic, strong) NSURL *manifestURL;
@end

@implementation MTManifestFetcherTests

- (void)setUp {
    [super setUp];
    [MTFetcherStubProtocol reset];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTFetcherStubProtocol class] ];
    config.timeoutIntervalForRequest = 1.0;
    config.timeoutIntervalForResource = 1.0;
    self.fetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:config];
    self.manifestURL = [NSURL URLWithString:@"https://abc.mediatailor.us-east-1.amazonaws.com/v1/master/acct/cfg/master.m3u8"];
}

- (void)tearDown {
    [self.fetcher cancel];
    self.fetcher = nil;
    [MTFetcherStubProtocol reset];
    [super tearDown];
}

#pragma mark 1. Success -> correct data / finalURL / contentType

- (void)testSuccess_returnsDataFinalURLAndContentType {
    NSData *body = [@"#EXTM3U\n#EXT-X-VERSION:3\n" dataUsingEncoding:NSUTF8StringEncoding];
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeBody status:200 body:body
                            contentType:@"application/vnd.apple.mpegurl" responseURL:nil error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"success"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.manifestData, body);
        XCTAssertEqualObjects(result.finalURL, self.manifestURL);
        XCTAssertEqualObjects(result.contentType, @"application/vnd.apple.mpegurl");
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 2. Non-2xx -> InvalidResponse

- (void)testNon2xx_mapsToInvalidResponse {
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeBody status:404 body:[NSData data]
                            contentType:nil responseURL:nil error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"404"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeInvalidResponse);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 3. Empty 200 body -> InvalidResponse

- (void)testEmptyBody_mapsToInvalidResponse {
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeBody status:200 body:nil
                            contentType:nil responseURL:nil error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"empty"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeInvalidResponse);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 4. Timeout -> MTManifestFetchErrorCodeTimeout

- (void)testTimeout_mapsToTimeout {
    NSError *timeoutErr = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeError status:0 body:nil
                            contentType:nil responseURL:nil error:timeoutErr];

    XCTestExpectation *exp = [self expectationWithDescription:@"timeout"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeTimeout);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 5. Transient network error -> one retry -> success

- (void)testTransientError_retriesThenSucceeds {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTFetcherFlipProtocol class] ];
    config.timeoutIntervalForRequest = 1.0;
    self.fetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:config];

    NSError *transientErr = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
    NSData *body = [@"#EXTM3U\n" dataUsingEncoding:NSUTF8StringEncoding];
    [MTFetcherFlipProtocol configureWithFailCount:1 error:transientErr successBody:body];

    XCTestExpectation *exp = [self expectationWithDescription:@"retry-success"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.manifestData, body);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
    XCTAssertEqual([MTFetcherFlipProtocol requestCount], 2, @"the first attempt failed; the retry succeeded");
}

#pragma mark 6. Transient network error persists -> NetworkFailure after the retry budget

- (void)testTransientError_persistsAfterRetry_mapsToNetworkFailure {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTFetcherFlipProtocol class] ];
    config.timeoutIntervalForRequest = 1.0;
    self.fetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:config];

    NSError *transientErr = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
    // failCount=2: both the initial attempt and the one retry fail.
    [MTFetcherFlipProtocol configureWithFailCount:2 error:transientErr successBody:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"persists"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeNetworkFailure);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
    XCTAssertEqual([MTFetcherFlipProtocol requestCount], 2,
                   @"exactly the initial attempt + one retry, then give up");
}

#pragma mark 6b. 409 Conflict -> one delayed retry -> success

// Observed against a real MediaTailor deployment: fetching a resolved
// sub-manifest URL that AVPlayer's own native engine is concurrently also
// reading can race MediaTailor's per-session handling and get rejected with
// 409, even though sequential requests to the same URL don't reproduce it.
- (void)test409Conflict_retriesAfterDelayThenSucceeds {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTFetcherFlipProtocol class] ];
    config.timeoutIntervalForRequest = 2.0;
    self.fetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:config];

    NSData *body = [@"#EXTM3U\n" dataUsingEncoding:NSUTF8StringEncoding];
    [MTFetcherFlipProtocol configureWithFailStatus:409 count:1 successBody:body];

    XCTestExpectation *exp = [self expectationWithDescription:@"409-retry-success"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.manifestData, body);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
    XCTAssertEqual([MTFetcherFlipProtocol requestCount], 2, @"the first attempt got 409; the delayed retry succeeded");
}

#pragma mark 6c. 409 Conflict persists -> InvalidResponse after the retry budget

- (void)test409Conflict_persistsAfterRetry_mapsToInvalidResponse {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTFetcherFlipProtocol class] ];
    config.timeoutIntervalForRequest = 2.0;
    self.fetcher = [[MTManifestFetcher alloc] initWithSessionConfiguration:config];

    // failCount=2: both the initial attempt and the one retry get 409.
    [MTFetcherFlipProtocol configureWithFailStatus:409 count:2 successBody:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"409-persists"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeInvalidResponse);
        XCTAssertEqualObjects(error.userInfo[@"httpStatus"], @409);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
    XCTAssertEqual([MTFetcherFlipProtocol requestCount], 2,
                   @"exactly the initial attempt + one retry, then give up");
}

#pragma mark 7. Mid-flight cancel -> MTManifestFetchErrorCodeCancelled

- (void)testCancelMidFlight_deliversCancelledError {
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeHang status:0 body:nil
                            contentType:nil responseURL:nil error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"cancel"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(result);
        XCTAssertNotNil(error);
        XCTAssertEqualObjects(error.domain, MTManifestFetchErrorDomain);
        XCTAssertEqual(error.code, MTManifestFetchErrorCodeCancelled);
        [exp fulfill];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.fetcher cancel];
    });
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 8. Redirect -> finalURL reflects the final URL, not the requested URL

- (void)testRedirect_finalURLReflectsPostRedirectURL {
    NSURL *redirectedURL = [NSURL URLWithString:@"https://cdn.example.com/v1/master/acct/cfg/master.m3u8"];
    NSData *body = [@"#EXTM3U\n" dataUsingEncoding:NSUTF8StringEncoding];
    [MTFetcherStubProtocol setNextMode:MTFetcherStubModeBody status:200 body:body
                            contentType:nil responseURL:redirectedURL error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"redirect"];
    [self.fetcher fetchManifestAtURL:self.manifestURL completion:^(MTManifestFetchResult *result, NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(result);
        XCTAssertEqualObjects(result.finalURL, redirectedURL);
        XCTAssertNotEqualObjects(result.finalURL, self.manifestURL);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

@end
