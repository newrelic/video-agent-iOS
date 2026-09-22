//
//  MTManifestFetcher.h
//  NRMediaTailorTracker
//
//  GET-only fetcher for the entry/session manifest URL — the first network
//  call in the self-sufficient auto-activation flow (see
//  `NRTrackerMediaTailor.h`'s "Auto-activation" docs). Mirrors
//  `MTTrackingClient`'s testability convention (`initWithSessionConfiguration:`
//  designated init, one retry on transient network errors, main-queue
//  completion) minus the `nextToken` / HTTP-400-retry logic, which is
//  specific to the `/v1/tracking/...` pagination contract and doesn't apply
//  to a plain manifest GET.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MTManifestFetchErrorDomain;

typedef NS_ERROR_ENUM(MTManifestFetchErrorDomain, MTManifestFetchErrorCode) {
    MTManifestFetchErrorCodeNetworkFailure  = 1,
    MTManifestFetchErrorCodeTimeout         = 2,
    MTManifestFetchErrorCodeCancelled       = 3,
    MTManifestFetchErrorCodeInvalidResponse = 4,   // non-2xx, or an empty 2xx body
};

/// Default request timeout (s). Matches `MTTrackingClientDefaultTimeout`.
FOUNDATION_EXPORT const NSTimeInterval MTManifestFetcherDefaultTimeout;

/// Default retry budget on transient network failure. One retry.
FOUNDATION_EXPORT const NSInteger MTManifestFetcherDefaultMaxRetries;

/// Result of a successful manifest fetch.
@interface MTManifestFetchResult : NSObject

/// Raw manifest bytes as received (HLS `.m3u8` text or DASH MPD XML, still
/// encoded — the caller decodes via `MTManifestParser`).
@property (nonatomic, copy, readonly) NSData *manifestData;

/// The URL the response actually came from, post-redirect. Use this — not
/// the originally requested URL — as the `baseURL` when parsing: relative
/// URIs in the manifest (HLS DATERANGE `URI=`, DASH `BaseURL`) resolve
/// against wherever the manifest actually lives, which a CDN redirect may
/// have moved.
@property (nonatomic, copy, readonly) NSURL *finalURL;

/// `Content-Type` response header, if present. Used to pick HLS vs. DASH
/// parsing when the caller hasn't set an explicit `manifestParser` override.
@property (nonatomic, copy, readonly, nullable) NSString *contentType;

- (instancetype)initWithManifestData:(NSData *)manifestData
                             finalURL:(NSURL *)finalURL
                          contentType:(nullable NSString *)contentType NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MTManifestFetcher : NSObject

/// Designated initializer. Pass a custom `NSURLSessionConfiguration` for
/// tests (e.g. with a `NSURLProtocol` subclass installed in
/// `protocolClasses`).
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)config NS_DESIGNATED_INITIALIZER;

/// Convenience initializer using `defaultSessionConfiguration` with a 5s
/// timeout.
- (instancetype)init;

/// GET the manifest at `url`.
///
/// - On a non-2xx response, or an empty 2xx body, the completion is invoked
///   with `MTManifestFetchErrorCodeInvalidResponse`.
/// - On `NSURLErrorTimedOut`, the error is mapped to
///   `MTManifestFetchErrorCodeTimeout`.
/// - On `NSURLErrorCancelled`, the completion is invoked with
///   `MTManifestFetchErrorCodeCancelled` (callers should swallow these).
/// - Other transient network errors (`NSURLErrorNotConnectedToInternet` /
///   `NSURLErrorNetworkConnectionLost` / `NSURLErrorDNSLookupFailed`) get one
///   automatic retry before mapping to `MTManifestFetchErrorCodeNetworkFailure`.
///
/// The completion handler runs on the main queue. Calling this while a
/// previous fetch is in flight cancels the previous one.
- (void)fetchManifestAtURL:(NSURL *)url
                 completion:(void (^)(MTManifestFetchResult * _Nullable result, NSError * _Nullable error))completion;

/// Cancel any in-flight request. Idempotent. The in-flight completion (if
/// any) fires once with `MTManifestFetchErrorCodeCancelled`.
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
