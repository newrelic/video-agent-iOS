//
//  MTTrackingClientTests.m
//  NRMediaTailorTrackerTests
//
//  Bug B1 (NextToken round-trip), A1 (no `?t=`), B3 (GET) coverage for
//  MTTrackingClient. Uses a stub NSURLProtocol installed via
//  NSURLSessionConfiguration.protocolClasses to mock the network without
//  hitting the real /v1/tracking endpoint.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTTrackingClient.h>
#import <NRMediaTailorTracker/MTTrackingError.h>
#import <NRMediaTailorTracker/MTTrackingResponse.h>

#pragma mark - Stub URLProtocol

typedef NS_ENUM(NSInteger, MTStubMode) {
    MTStubModeBody,         // return data + status
    MTStubModeError,        // fail with NSError
    MTStubModeHang,         // do nothing — caller will hit timeout / cancel
};

/// One-shot HTTP transcript installed via `+setNextMode:...`. Records the
/// request the client made (so tests can assert on the URL / query string)
/// and returns a configured response/body/error.
@interface MTStubProtocol : NSURLProtocol
+ (void)setNextMode:(MTStubMode)mode
             status:(NSInteger)status
               body:(nullable NSData *)body
              error:(nullable NSError *)error;
+ (void)reset;
+ (NSArray<NSURLRequest *> *)requestLog;
@end

/// Two-step stub: first request gets `flipFrom`, second gets `flipTo`. Used
/// for the HTTP-400 → retry-without-token regression for Bug B1.
@interface MTStubFlipProtocol : NSURLProtocol
+ (void)setFreshBody:(NSData *)body flipFromStatus:(NSInteger)from toStatus:(NSInteger)to;
+ (NSInteger)requestCount;
+ (nullable NSURL *)secondRequestURL;
@end

#pragma mark - MTStubProtocol impl

static MTStubMode gMode = MTStubModeBody;
static NSInteger gStatus = 200;
static NSData *gBody = nil;
static NSError *gError = nil;
static NSMutableArray<NSURLRequest *> *gRequestLog = nil;

@implementation MTStubProtocol

+ (void)setNextMode:(MTStubMode)mode
             status:(NSInteger)status
               body:(NSData *)body
              error:(NSError *)error {
    gMode = mode;
    gStatus = status;
    gBody = [body copy];
    gError = error;
}

+ (void)reset {
    gMode = MTStubModeBody;
    gStatus = 200;
    gBody = nil;
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
    if (gMode == MTStubModeHang) {
        return; // never call any client method
    }
    if (gMode == MTStubModeError && gError) {
        [self.client URLProtocol:self didFailWithError:gError];
        return;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                              statusCode:gStatus
                                                             HTTPVersion:@"HTTP/1.1"
                                                            headerFields:@{@"Content-Type": @"application/json"}];
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (gBody) {
        [self.client URLProtocol:self didLoadData:gBody];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - MTStubFlipProtocol impl

static NSInteger gFlipFrom = 400;
static NSInteger gFlipTo   = 200;
static NSData    *gFreshBody = nil;
static NSInteger gFlipCount = 0;
static NSURL     *gSecondURL = nil;

@implementation MTStubFlipProtocol

+ (void)setFreshBody:(NSData *)body flipFromStatus:(NSInteger)from toStatus:(NSInteger)to {
    gFreshBody = [body copy];
    gFlipFrom = from;
    gFlipTo = to;
    gFlipCount = 0;
    gSecondURL = nil;
}

+ (NSInteger)requestCount { return gFlipCount; }
+ (NSURL *)secondRequestURL { return gSecondURL; }

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    gFlipCount++;
    if (gFlipCount == 2) gSecondURL = request.URL;
    return YES;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    NSInteger status = (gFlipCount == 1) ? gFlipFrom : gFlipTo;
    NSData *body = (gFlipCount == 1) ? [NSData data] : gFreshBody;
    NSHTTPURLResponse *resp = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                          statusCode:status
                                                         HTTPVersion:@"HTTP/1.1"
                                                        headerFields:@{}];
    [self.client URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (body.length > 0) {
        [self.client URLProtocol:self didLoadData:body];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)stopLoading {}

@end

#pragma mark - Fixture helper

static NSData *MTBodyWithToken(NSString *token) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"avails"] = @[];
    dict[@"nonLinearAvails"] = @[];
    if (token.length > 0) {
        dict[@"nextToken"] = token;
    }
    return [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
}

#pragma mark - Tests

@interface MTTrackingClientTests : XCTestCase
@property (nonatomic, strong) MTTrackingClient *client;
@property (nonatomic, strong) NSURL *baseURL;
@end

@implementation MTTrackingClientTests

- (void)setUp {
    [super setUp];
    [MTStubProtocol reset];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTStubProtocol class] ];
    config.timeoutIntervalForRequest = 1.0;
    config.timeoutIntervalForResource = 1.0;
    self.client = [[MTTrackingClient alloc] initWithSessionConfiguration:config];
    self.baseURL = [NSURL URLWithString:@"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/session-1"];
}

- (void)tearDown {
    [self.client cancel];
    self.client = nil;
    [MTStubProtocol reset];
    [super tearDown];
}

#pragma mark Helpers

- (NSURL *)lastRequestedURL {
    return [MTStubProtocol requestLog].lastObject.URL;
}

- (NSString *)queryValue:(NSString *)name inURL:(NSURL *)url {
    NSURLComponents *c = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    for (NSURLQueryItem *q in c.queryItems) {
        if ([q.name isEqualToString:name]) return q.value;
    }
    return nil;
}

#pragma mark 1. First call sends no token; second call sends prior token (B1)

- (void)testFirstCallSendsNoToken_secondCallSendsPriorToken {
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(@"abc") error:nil];

    XCTestExpectation *first = [self expectationWithDescription:@"first"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *resp, NSError *err) {
        XCTAssertNil(err);
        XCTAssertEqualObjects(resp.nextToken, @"abc");
        [first fulfill];
    }];
    [self waitForExpectations:@[first] timeout:5.0];

    NSURL *firstURL = [self lastRequestedURL];
    XCTAssertNil([self queryValue:@"nextToken" inURL:firstURL], @"first call must NOT send a token");

    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(@"def") error:nil];
    XCTestExpectation *second = [self expectationWithDescription:@"second"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *resp, NSError *err) {
        XCTAssertNil(err);
        [second fulfill];
    }];
    [self waitForExpectations:@[second] timeout:5.0];

    NSURL *secondURL = [self lastRequestedURL];
    XCTAssertEqualObjects([self queryValue:@"nextToken" inURL:secondURL], @"abc",
                          @"second call must echo the prior nextToken (B1)");
}

#pragma mark 2. HTTP 400 -> retry with no token, then succeed (B1 expiry)

- (void)testHTTP400DropsTokenAndRetriesWithoutOne {
    // Switch this test's client to the flip protocol so we can serve 400 then 200.
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    config.protocolClasses = @[ [MTStubFlipProtocol class] ];
    config.timeoutIntervalForRequest = 1.0;
    self.client = [[MTTrackingClient alloc] initWithSessionConfiguration:config];

    [MTStubFlipProtocol setFreshBody:MTBodyWithToken(nil) flipFromStatus:400 toStatus:200];

    __block NSInteger callCount = 0;
    XCTestExpectation *retry = [self expectationWithDescription:@"retry"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        callCount++;
        XCTAssertNil(e, @"after 400-retry the caller should see success");
        XCTAssertNotNil(r);
        [retry fulfill];
    }];
    [self waitForExpectations:@[retry] timeout:5.0];
    XCTAssertEqual(callCount, 1, @"completion fires exactly once after the retry");
    XCTAssertEqual([MTStubFlipProtocol requestCount], 2, @"client made 2 HTTP requests");

    XCTAssertNil([self queryValue:@"nextToken" inURL:[MTStubFlipProtocol secondRequestURL]],
                 @"after 400, retry must include no nextToken");
}

#pragma mark 3. Timeout -> MTTrackingErrorCodeTimeout

- (void)testTimeoutMapsToMTTrackingErrorCodeTimeout {
    NSError *timeoutErr = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    [MTStubProtocol setNextMode:MTStubModeError status:0 body:nil error:timeoutErr];

    XCTestExpectation *exp = [self expectationWithDescription:@"timeout"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNotNil(e);
        XCTAssertEqualObjects(e.domain, MTTrackingErrorDomain);
        XCTAssertEqual(e.code, MTTrackingErrorCodeTimeout);
        XCTAssertNil(r);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 4. Mid-flight cancel -> MTTrackingErrorCodeCancelled

- (void)testCancelMidFlightDeliversCancelledError {
    [MTStubProtocol setNextMode:MTStubModeHang status:0 body:nil error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"cancel"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNotNil(e);
        XCTAssertEqualObjects(e.domain, MTTrackingErrorDomain);
        XCTAssertEqual(e.code, MTTrackingErrorCodeCancelled);
        [exp fulfill];
    }];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.client cancel];
    });
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 5. Same token returned (no new beacons) -> empty avails OK

- (void)testSameTokenReturnedYieldsEmptyAvailsAndStores {
    NSData *body = MTBodyWithToken(@"same-token");
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:body error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"same"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNil(e);
        XCTAssertNotNil(r);
        XCTAssertEqual(r.avails.count, 0u);
        XCTAssertEqualObjects(r.nextToken, @"same-token");
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark 6. Malformed JSON -> MTTrackingErrorCodeParseFailed

- (void)testMalformedJSONMapsToParseFailed {
    NSData *garbage = [@"this is not json" dataUsingEncoding:NSUTF8StringEncoding];
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:garbage error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"parse"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNil(r);
        XCTAssertNotNil(e);
        XCTAssertEqualObjects(e.domain, MTTrackingErrorDomain);
        XCTAssertEqual(e.code, MTTrackingErrorCodeParseFailed);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];
}

#pragma mark A1: ?t=<wallclock> is dropped

- (void)testWallClockCacheBustQueryIsStripped {
    NSURL *urlWithT = [NSURL URLWithString:
                       @"https://abc.mediatailor.us-east-1.amazonaws.com/v1/tracking/session-1?t=1700000000000"];
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(nil) error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"a1"];
    [self.client fetchWithTrackingURL:urlWithT completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNil(e);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];

    NSURL *out = [self lastRequestedURL];
    XCTAssertNil([self queryValue:@"t" inURL:out], @"A1: ?t=<wallclock> must be removed");
}

#pragma mark B3: HTTP method is GET

- (void)testHTTPMethodIsGET {
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(nil) error:nil];

    XCTestExpectation *exp = [self expectationWithDescription:@"b3"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) {
        XCTAssertNil(e);
        [exp fulfill];
    }];
    [self waitForExpectations:@[exp] timeout:5.0];

    NSURLRequest *req = [MTStubProtocol requestLog].firstObject;
    XCTAssertEqualObjects(req.HTTPMethod, @"GET");
}

#pragma mark resetSession clears the stored token

- (void)testResetSessionClearsToken {
    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(@"prime") error:nil];
    XCTestExpectation *p = [self expectationWithDescription:@"prime"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) { [p fulfill]; }];
    [self waitForExpectations:@[p] timeout:5.0];

    [self.client resetSession];

    [MTStubProtocol setNextMode:MTStubModeBody status:200 body:MTBodyWithToken(@"new") error:nil];
    XCTestExpectation *q = [self expectationWithDescription:@"after reset"];
    [self.client fetchWithTrackingURL:self.baseURL completion:^(MTTrackingResponse *r, NSError *e) { [q fulfill]; }];
    [self waitForExpectations:@[q] timeout:5.0];

    XCTAssertNil([self queryValue:@"nextToken" inURL:[self lastRequestedURL]],
                 @"after resetSession the next call must NOT send a token");
}

@end
