//
//  MTTrackingClient.h
//  NRMediaTailorTracker
//
//  HTTP client for the MediaTailor `/v1/tracking/<sessionId>` endpoint.
//
//  Implements three deviations from the Android `MTTrackingClient.java`:
//
//   - Bug A1 (DROPPED): no `?t=<wall-clock>` cache-bust query param. The
//     Android code appends `System.currentTimeMillis()` on every fetch, which
//     defeats the backend's session-stable cache. We rely on the documented
//     pagination contract instead.
//
//   - Bug B1 (FIXED): `nextToken` is round-tripped per atomic facts
//     `f-track-client-113` .. `f-track-client-121`. First call sends no
//     token; the server returns the full window plus a token; every
//     subsequent call MUST echo that token back as a query parameter.
//     HTTP 400 means the token expired — drop it and retry once with
//     no token.
//
//   - Bug B3 (PARITY): HTTP **GET**, not POST. Atomic fact
//     `f-track-client-119` (11b-tracking.yaml:326) documents POST as the
//     canonical method, but Android uses GET via URL rewrite and the
//     user has explicitly chosen to retain Android parity here. Do NOT
//     "fix" this without explicit sign-off — see BUGS_TO_FIX.md group B3.
//
//  The class is `NSObject`-shaped (no Swift `actor`); thread safety is
//  enforced via a private serial dispatch queue that mediates access to
//  `lastNextToken` and the in-flight `NSURLSessionDataTask`. Public
//  methods are safe to call from any queue. The completion handler is
//  invoked on `[NSOperationQueue mainQueue]` so the state machine
//  (T07) doesn't have to thread-hop.
//

#import <Foundation/Foundation.h>

@class MTTrackingResponse;

NS_ASSUME_NONNULL_BEGIN

/// Default request timeout (s). 5s per FEATURE_SPEC §2 "Tracking API Fetch".
FOUNDATION_EXPORT const NSTimeInterval MTTrackingClientDefaultTimeout;

/// Default retry budget on transient network failure. One retry, per spec.
FOUNDATION_EXPORT const NSInteger MTTrackingClientDefaultMaxRetries;

@interface MTTrackingClient : NSObject

/// Designated initializer. Pass a custom `NSURLSessionConfiguration` for tests
/// (e.g. with a `NSURLProtocol` subclass installed in `protocolClasses`).
- (instancetype)initWithSessionConfiguration:(NSURLSessionConfiguration *)config NS_DESIGNATED_INITIALIZER;

/// Convenience initializer using `defaultSessionConfiguration` with a 5s timeout.
- (instancetype)init;

/// Fetch the tracking JSON for the given URL.
///
/// - The URL is sent unmodified (no `?t=` cache bust). If a non-nil
///   `lastNextToken` is held internally, it is appended as `?nextToken=<value>`
///   (or `&nextToken=` if the URL already has query params).
/// - On a `200` response, `MTTrackingResponse.nextToken` is captured into
///   `lastNextToken` for the next call.
/// - On HTTP `400`, the held token is treated as expired and cleared; the
///   completion is invoked with an `MTTrackingErrorCodeTokenExpired` error
///   so the caller (T07) can immediately retry.
/// - On `NSURLErrorTimedOut`, the error is mapped to
///   `MTTrackingErrorCodeTimeout`.
/// - On `NSURLErrorCancelled`, the completion is invoked with
///   `MTTrackingErrorCodeCancelled` (callers should swallow these).
///
/// The completion handler runs on the main queue. Calling `fetch` while a
/// previous fetch is in flight cancels the previous one.
- (void)fetchWithTrackingURL:(NSURL *)url
                  completion:(void (^)(MTTrackingResponse * _Nullable response, NSError * _Nullable error))completion;

/// Cancel any in-flight request. Idempotent. The in-flight completion (if
/// any) fires once with `MTTrackingErrorCodeCancelled`.
- (void)cancel;

/// Drop the cached `nextToken`. Call on player teardown or when the URL
/// changes (new session). Does NOT cancel an in-flight request.
- (void)resetSession;

@end

NS_ASSUME_NONNULL_END
