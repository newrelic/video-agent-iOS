//
//  MTManifestFetcher.m
//  NRMediaTailorTracker
//

#import "MTManifestFetcher.h"

NSErrorDomain const MTManifestFetchErrorDomain = @"com.newrelic.NRMediaTailorTracker.manifestFetch";

const NSTimeInterval MTManifestFetcherDefaultTimeout = 5.0;
const NSInteger MTManifestFetcherDefaultMaxRetries = 1;

@implementation MTManifestFetchResult

- (instancetype)initWithManifestData:(NSData *)manifestData
                             finalURL:(NSURL *)finalURL
                          contentType:(nullable NSString *)contentType {
    if ((self = [super init])) {
        _manifestData = [manifestData copy];
        _finalURL = [finalURL copy];
        _contentType = [contentType copy];
    }
    return self;
}

@end

@interface MTManifestFetcher ()

@property (nonatomic, strong) NSURLSession *session;

/// Serializes access to `currentTask`. All mutation happens on this queue.
@property (nonatomic, strong) dispatch_queue_t stateQueue;

/// In-flight task, so `cancel` can interrupt it.
@property (nonatomic, strong, nullable) NSURLSessionDataTask *currentTask;

@end

@implementation MTManifestFetcher

#pragma mark - Init

- (instancetype)init {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = MTManifestFetcherDefaultTimeout;
    config.timeoutIntervalForResource = MTManifestFetcherDefaultTimeout;
    return [self initWithSessionConfiguration:config];
}

- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)config {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:config];
        _stateQueue = dispatch_queue_create("com.newrelic.NRMediaTailorTracker.MTManifestFetcher.state", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self.session invalidateAndCancel];
}

#pragma mark - Public API

- (void)fetchManifestAtURL:(NSURL *)url
                 completion:(void (^)(MTManifestFetchResult * _Nullable, NSError * _Nullable))completion {
    NSParameterAssert(url);
    NSParameterAssert(completion);

    dispatch_async(self.stateQueue, ^{
        [self.currentTask cancel];

        NSURLRequest *request = [NSURLRequest requestWithURL:url
                                                 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                             timeoutInterval:MTManifestFetcherDefaultTimeout];

        [self performRequest:request
                attemptsLeft:MTManifestFetcherDefaultMaxRetries
                  completion:completion];
    });
}

- (void)cancel {
    dispatch_async(self.stateQueue, ^{
        [self.currentTask cancel];
        self.currentTask = nil;
    });
}

#pragma mark - Request loop

/// Performs `request` and on response branches into:
///   - 2xx with a non-empty body: build a `MTManifestFetchResult`, deliver.
///   - non-2xx, or an empty 2xx body: `InvalidResponse`.
///   - URL session error: timeout / cancel mapping; one retry on transient
///     network failure.
- (void)performRequest:(NSURLRequest *)request
           attemptsLeft:(NSInteger)attemptsLeft
             completion:(void (^)(MTManifestFetchResult * _Nullable, NSError * _Nullable))completion {

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
                                                 completionHandler:^(NSData * _Nullable data,
                                                                     NSURLResponse * _Nullable response,
                                                                     NSError * _Nullable error) {
        __strong typeof(weakSelf) self_ = weakSelf;
        if (!self_) {
            [self.class deliverOnMain:^{
                completion(nil, [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                    code:MTManifestFetchErrorCodeNetworkFailure
                                                userInfo:nil]);
            }];
            return;
        }

        dispatch_async(self_.stateQueue, ^{
            self_.currentTask = nil;

            // --- Cancellation ---
            if (error.code == NSURLErrorCancelled && [error.domain isEqualToString:NSURLErrorDomain]) {
                NSError *mapped = [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                      code:MTManifestFetchErrorCodeCancelled
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            // --- Timeout ---
            if (error.code == NSURLErrorTimedOut && [error.domain isEqualToString:NSURLErrorDomain]) {
                NSError *mapped = [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                      code:MTManifestFetchErrorCodeTimeout
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            // --- Other transport-level error (one retry) ---
            if (error) {
                if (attemptsLeft > 0 && [self_ isTransientNetworkError:error]) {
                    [self_ performRequest:request
                             attemptsLeft:attemptsLeft - 1
                               completion:completion];
                    return;
                }
                NSError *mapped = [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                      code:MTManifestFetchErrorCodeNetworkFailure
                                                  userInfo:@{NSUnderlyingErrorKey: error}];
                [self.class deliverOnMain:^{ completion(nil, mapped); }];
                return;
            }

            NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
            NSInteger status = http.statusCode;

            // --- 409 Conflict (one delayed retry) ---
            // Observed against a real MediaTailor deployment: fetching a
            // resolved sub-manifest URL that AVPlayer's own native engine is
            // *concurrently* also reading (the direct/implicit flow's
            // discovered-from-access-log case) can race MediaTailor's
            // per-session request handling and get rejected with 409 —
            // sequential requests to the same URL don't reproduce this, only
            // truly concurrent ones do. A short delay before retrying once
            // is a standard, safe mitigation for exactly this class of
            // transient lock-contention conflict.
            if (status == 409 && attemptsLeft > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), self_.stateQueue, ^{
                    [self_ performRequest:request attemptsLeft:attemptsLeft - 1 completion:completion];
                });
                return;
            }

            // --- Non-2xx ---
            if (status < 200 || status >= 300) {
                NSError *invalid = [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                       code:MTManifestFetchErrorCodeInvalidResponse
                                                   userInfo:@{@"httpStatus": @(status)}];
                [self.class deliverOnMain:^{ completion(nil, invalid); }];
                return;
            }

            if (data.length == 0) {
                NSError *invalid = [NSError errorWithDomain:MTManifestFetchErrorDomain
                                                       code:MTManifestFetchErrorCodeInvalidResponse
                                                   userInfo:nil];
                [self.class deliverOnMain:^{ completion(nil, invalid); }];
                return;
            }

            NSURL *finalURL = response.URL ?: request.URL;
            NSString *contentType = [http valueForHTTPHeaderField:@"Content-Type"];
            MTManifestFetchResult *result = [[MTManifestFetchResult alloc] initWithManifestData:data
                                                                                          finalURL:finalURL
                                                                                       contentType:contentType];
            [self.class deliverOnMain:^{ completion(result, nil); }];
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

+ (void)deliverOnMain:(dispatch_block_t)block {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

@end
