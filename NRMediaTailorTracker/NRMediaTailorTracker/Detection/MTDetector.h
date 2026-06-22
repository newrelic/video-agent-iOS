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
//  "urn:aws:elemental:mediatailor:tracking"). See task T05 / Bug B4.
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
 Heuristic: substring match on the marker `mediatailor` in the URL string.

 @param url The candidate playback URL. Nil → NO.
 */
+ (BOOL)isMediaTailorURL:(nullable NSURL *)url;

/**
 Extracts the MediaTailor session identifier from the URL's query string.
 Supports both `aws.sessionId=...` (current MediaTailor convention) and the
 legacy `sessionId=...` query parameter.

 @param url The MediaTailor playback URL. Nil → nil.
 @return The session identifier, or nil if the URL has no recognisable
         session-id query parameter.
 */
+ (nullable NSString *)extractSessionId:(nullable NSURL *)url;

/**
 Derives the companion tracking-API URL by rewriting the manifest URL's
 path. Replaces `/v1/master/` or `/v1/session/` with `/v1/tracking/`, drops
 the manifest filename's extension, replaces it with `/<sessionId>`, and
 strips any query string.

 Returns nil if the URL is not a MediaTailor URL or has no extractable
 session identifier.

 NOTE: This is the FALLBACK tracking-URL discovery path. The PRIMARY path
 parses the manifest's tracking marker (HLS DATERANGE / DASH EventStream)
 and is implemented in task T05.

 @param url The MediaTailor playback URL.
 */
+ (nullable NSURL *)deriveTrackingURL:(nullable NSURL *)url;

/**
 The default ad-segment marker substrings checked against segment URLs
 and DASH BaseURLs during manifest parsing. T05 consumes this; callers
 can extend the list via `NRAdConfig` when their CDN uses a non-default
 path prefix.

 Order matches Android `MTConstants` for parity.
 */
+ (NSArray<NSString *> *)defaultSegmentMarkers;

@end

NS_ASSUME_NONNULL_END
