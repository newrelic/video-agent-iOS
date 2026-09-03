//
//  MTTrackingClient.m
//  NRMediaTailorTracker
//

#import "MTTrackingClient.h"
#import "MTTrackingError.h"
#import "MTTrackingResponse.h"

const NSTimeInterval MTTrackingClientDefaultTimeout = 5.0;
const NSInteger MTTrackingClientDefaultMaxRetries = 1;

@interface MTTrackingClient ()

@property (nonatomic, strong) NSURLSession *session;

/// Serializes access to `lastNextToken` and `currentTask`. All mutation
/// happens on this queue.
@property (nonatomic, strong) dispatch_queue_t stateQueue;

/// Bug B1 — pagination token. Carried across calls until cleared by
/// `resetSession` or by an HTTP 400 response.
@property (nonatomic, copy, nullable) NSString *lastNextToken;

/// In-flight task, so `cancel` can interrupt it.
@property (nonatomic, strong, nullable) NSURLSessionDataTask *currentTask;

@end

@implementation MTTrackingClient

#pragma mark - Init

- (instancetype)init {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = MTTrackingClientDefaultTimeout;
    config.timeoutIntervalForResource = MTTrackingClientDefaultTimeout;
    return [self initWithSessionConfiguration:config];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)config {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:config];
        _stateQueue = dispatch_queue_create("com.newrelic.NRMediaTailorTracker.MTTrackingClient.state", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

#pragma mark - Public API

- (void)fetchWithTrackingURL:(NSURL *)url
                  completion:(void (^)(MTTrackingResponse * _Nullable, NSError * _Nullable))completion {
    NSParameterAssert(url);
    NSParameterAssert(completion);

    dispatch_async(self.stateQueue, ^{
        [self.currentTask cancel];

        NSString *token = self.lastNextToken;
        NSURL *requestURL = [self.class urlByAppendingNextToken:token toURL:url];
        NSURLRequest *request = [NSURLRequest requestWithURL:requestURL
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                             timeoutInterval:MTTrackingClientDefaultTimeout];

        [self performRequest:request
              originalURL:url
              attemptsLeft:MTTrackingClientDefaultMaxRetries
        token400Retry:NO
                completion:completion];
    });
}

- (void)cancel {
    dispatch_async(self.stateQueue, ^{
        [self.currentTask cancel];
        self.currentTask = nil;
    });
}

- (void)resetSession {
    dispatch_async(self.stateQueue, ^{
        self.lastNextToken = nil;
    });
}

#pragma mark - Request loop

/// Performs `request` and on response branches into:
///   - 200 OK: parse, store `nextToken`, deliver to caller
///   - 400: drop `lastNextToken`, retry ONCE with no token (B1 / token expiry)
///   - URL session error: timeout / cancel mapping; one retry on transient
///     network failure (`NSURLErrorNotConnectedToInternet`,
///     `NSURLErrorNetworkConnectionLost`)
- (void)performRequest:(NSURLRequest *)request
           originalURL:(NSURL *)originalURL
          attemptsLeft:(NSInteger)attemptsLeft
         token400Retry:(BOOL)token400Retry
            completion:(void (^)(MTTrackingResponse * _Nullable, NSError * _Nullable))completion {

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData * _Nullable data,
                                                                     NSURLResponse * _Nullable response,
                                                                     NSError * _Nullable error) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) {
            [self.class deliverOnMain:^{
                completion(nil, [NSError errorWithDomain:MTTrackingErrorDomain
                                                    code:MTTrackingErrorCodeNetworkFailure
                                                userInfo:nil]);
            }];
            return;
        }

        dispatch_async(self_.stateQueue, ^{
            self_.currentTask = nil;

            // --- Cancellation ---
            if (error.code == NSURLErrorCancelled && [error.domain isEqualToString:NSURLErrorDomain]) {
                NSError *mapped = [NSError errorWithDomain:MTTrackingErrorDomain
                                                      code:MTTrackingErrorCodeCancelled
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            // --- Timeout ---
            if (error.code == NSURLErrorTimedOut && [error.domain isEqualToString:NSURLErrorDomain]) {
                NSError *mapped = [NSError errorWithDomain:MTTrackingErrorDomain
                                                      code:MTTrackingErrorCodeTimeout
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            // --- Other transport-level error (one retry) ---
            if (error) {
                if (attemptsLeft > 0 && [self_ isTransientNetworkError:error]) {
                    [self_ performRequest:request
                              originalURL:originalURL
                             attemptsLeft:attemptsLeft - 1
                            token400Retry:token400Retry
                               completion:completion];
                    return;
                }
                NSError *mapped = [NSError errorWithDomain:MTTrackingErrorDomain
                                                      code:MTTrackingErrorCodeNetworkFailure
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            NSInteger status = http.statusCode;

            // --- HTTP 400: token expired (B1 spec) ---
            if (status == 400) {
                self_.lastNextToken = nil;
                if (!token400Retry) {
                    NSURL *retryURL = [self_.class urlByAppendingNextToken:nil toURL:originalURL];
                    NSURLRequest *retryRequest = [NSURLRequest requestWithURL:retryURL
                                                                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                              timeoutInterval:MTTrackingClientDefaultTimeout];
                    [self_ performRequest:retryRequest
                              originalURL:originalURL
                             attemptsLeft:attemptsLeft
                            token400Retry:YES
                               completion:completion];
                    return;
                }
                NSError *expired = [NSError errorWithDomain:MTTrackingErrorDomain
                                                       code:MTTrackingErrorCodeTokenExpired
                                                   userInfo:nil];
                [self.class deliverOnMain:^{ completion(nil, expired); }];
                return;
            }

            // --- Non-2xx ---
            if (status < 200 || status >= 300) {
                NSError *netErr = [NSError errorWithDomain:MTTrackingErrorDomain
                                                      code:MTTrackingErrorCodeNetworkFailure
                                                  userInfo:@{@"httpStatus": @(status)}];
                [self.class deliverOnMain:^{ completion(nil, netErr); }];
                return;
            }

            if (data.length == 0) {
                NSError *invalid = [NSError errorWithDomain:MTTrackingErrorDomain
                                                       code:MTTrackingErrorCodeInvalidResponse
                                                   userInfo:nil];
                [self.class deliverOnMain:^{ completion(nil, invalid); }];
                return;
            }

            NSError *parseError = nil;
            MTTrackingResponse *parsed = [MTTrackingResponse fromJSONData:data error:&parseError];
            if (!parsed) {
                NSError *fail = [NSError errorWithDomain:MTTrackingErrorDomain
                                                    code:MTTrackingErrorCodeParseFailed
                                                userInfo:parseError ? @{NSUnderlyingErrorKey: parseError} : nil];
                [self.class deliverOnMain:^{ completion(nil, fail); }];
                return;
            }

            // Round-trip: capture the next token (may be nil if server omits).
            self_.lastNextToken = parsed.nextToken;
            [self.class deliverOnMain:^{ completion(parsed, nil); }];
        });
    }];

    self.currentTask = task;
    [task resume];
}

#pragma mark - Helpers

- (BOOL)isTransientNetworkError:(NSError *)error {
    if (![error.domain isEqualToString:NSURLErrorDomain]) return NO;
    switch (error.code) {
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
            return YES;
        default:
            return NO;
    }
}

/// Build the request URL. Drops any `?t=...` cache-bust if present (Bug A1
/// — Android adds it; we deliberately do not). Appends `nextToken=<value>`
/// when `token` is non-nil and non-empty.
+ (NSURL *)urlByAppendingNextToken:(nullable NSString *)token toURL:(NSURL *)url {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (!components) return url;

    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    for (NSURLQueryItem *q in components.queryItems) {
        if ([q.name isEqualToString:@"t"]) continue; // A1: drop wall-clock cache buster
        if ([q.name isEqualToString:@"nextToken"]) continue; // dedupe; we're about to add our own
        [items addObject:q];
    }
    if (token.length > 0) {
        [items addObject:[NSURLQueryItem queryItemWithName:@"nextToken" value:token]];
    }
    components.queryItems = items.count > 0 ? items : nil;
    return components.URL ?: url;
}

+ (void)deliverOnMain:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
