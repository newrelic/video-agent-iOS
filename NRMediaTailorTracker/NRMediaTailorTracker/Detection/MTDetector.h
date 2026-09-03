//
//  MTDetector.h
//  NRMediaTailorTracker
//
//  URL-level heuristics for recognising AWS MediaTailor streams and deriving
//  companion endpoints.
//
//  Ported from Android `MTDetector.java` (lines 27–62):
//    /NRMediaTailorTracker/src/main/java/com/newrelic/videoagent/
//    mediatailor/detection/MTDetector.java
//
//  PRIMARY tracking-URL discovery is via manifest markers (HLS EXT-X-DATERANGE
//  CLASS="tracking", DASH EventStream schemeIdUri=
//  "urn:aws:elemental:mediatailor:tracking").
//  This class is the FALLBACK: URL-rewrite of the playback manifest.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 `MTDetector` provides URL-level heuristics used to gate the MediaTailor
 tracker and derive the `/v1/tracking/<sessionId>` URL when the manifest-
 marker primary path is unavailable.

 All methods are class methods; the class is not meant to be instantiated.
 */
@interface MTDetector : NSObject

/**
 Returns YES when the given URL looks like a MediaTailor playback endpoint.
 Two heuristics, either is sufficient:

   1. Substring match on `mediatailor` in the URL string (true for the raw
      `*.mediatailor.<region>.amazonaws.com` hostname).
   2. The MediaTailor path convention — `/v1/master/`, `/v1/session/`,
      `/v1/dash/`, `/v1/manifest/`, `/v1/segment/` or `/v1/tracking/` —
      regardless of hostname. Needed because AWS's own recommended (and this
      project's planned) deployment shape fronts MediaTailor with CloudFront
      on a custom hostname that never contains "mediatailor" at all, e.g.
      `https://cdn.example.com/v1/master/{account}/{config}/index.m3u8` —
      must detect as YES.

 @param url The candidate playback URL. Nil → NO.
 */
+ (BOOL)isMediaTailorURL:(nullable NSURL *)url;

/**
 Extracts the MediaTailor session identifier from the URL. Supports two
 shapes, covering both MediaTailor session-init flows:

   1. Query string — the *explicit* flow (`POST /v1/session/...`, then GET
      the returned `manifestUrl`): `aws.sessionId=...` (current convention)
      or the legacy `sessionId=...`.
   2. Path segment — the direct/implicit flow (`GET /v1/master/...`
      directly, no session-init call): the entry URL itself never carries a
      session id, but the resolved manifest/segment URLs MediaTailor returns
      do, as a path component:
        `/v1/manifest/{account}/{config}/{sessionId}/{variant}.m3u8`
        `/v1/segment/{account}/{config}/{sessionId}/{variant}/{segment}`

 @param url The MediaTailor URL — entry manifest, resolved manifest, or
        segment URL. Nil → nil.
 @return The session identifier, or nil if the URL has no recognisable
         session-id in either shape. A bare direct/implicit entry URL
         (`/v1/master/{account}/{config}/master.m3u8`, no query) genuinely
         carries no session id — nil is correct there, not a detection gap.
 */
+ (nullable NSString *)extractSessionId:(nullable NSURL *)url;

/**
 Derives the companion tracking-API URL. Handles both session-id shapes
 documented on `+extractSessionId:`:

   - Query-string shape: replaces `/v1/master/`, `/v1/session/` or `/v1/dash/`
     with `/v1/tracking/`, drops the manifest filename's extension, replaces
     it with `/<sessionId>`, and strips any query string.
   - Path-segment shape: replaces `/v1/manifest/` or `/v1/segment/` with
     `/v1/tracking/`, keeps the `{account}/{config}/{sessionId}` prefix, and
     drops everything after the session id (the variant/segment suffix).

 Returns nil if the URL is not a MediaTailor URL or has no extractable
 session identifier — which is expected, not an error, for a bare
 direct/implicit entry URL with no session id anywhere in it.

 NOTE: This is the FALLBACK tracking-URL discovery path. The PRIMARY path
 parses the manifest's tracking marker (HLS DATERANGE / DASH EventStream) —
 but AWS MediaTailor does not always emit that marker, so this fallback is
 frequently the one actually exercised in practice.

 @param url The MediaTailor playback URL.
 */
+ (nullable NSURL *)deriveTrackingURL:(nullable NSURL *)url;

/**
 The default ad-segment marker substrings checked against segment URLs
 and DASH BaseURLs during manifest parsing. Callers can extend the list
 via `NRAdConfig` when their CDN uses a non-default path prefix.

 Order matches Android `MTConstants` for parity.
 */
+ (NSArray<NSString *> *)defaultSegmentMarkers;

@end

NS_ASSUME_NONNULL_END
