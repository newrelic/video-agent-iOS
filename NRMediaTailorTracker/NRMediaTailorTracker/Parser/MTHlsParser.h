//
//  MTHlsParser.h
//  NRMediaTailorTracker
//
//  HLS manifest parser that detects MediaTailor ad breaks and (when present)
//  recovers the tracking URL directly from a manifest marker.
//
//  Bug B4 distinction
//  ──────────────────
//  PRIMARY discovery path:
//    Parse `#EXT-X-DATERANGE` entries. When the entry's `CLASS` attribute is
//    `"com.apple.hls.interstitial"` or `"tracking"`, extract its `URI`
//    attribute as the tracking URL. This is the AWS-canonical path
//    (atomic facts §4 Method 1).
//
//  FALLBACK discovery path (no DATERANGE marker present):
//    Caller derives the tracking URL by URL-rewrite via
//    `+[MTDetector deriveTrackingURL:]`. See `MTDetector.h`.
//
//  Break / pod detection (always run — DATERANGE only carries tracking URL,
//  not break geometry):
//    - Per-segment URL marker match against
//      `segments.mediatailor`, `/v1/hlssegment/`, `/v1/dashsegment/`, `/tm/`,
//      plus the caller's `customSegmentMarkers` extras.
//    - Pod boundaries inside a break via `#EXT-X-DISCONTINUITY` changes.
//    - `#EXT-X-PROGRAM-DATE-TIME` immediately before the first ad segment in
//      a break populates `availProgramDateTime` (Bug A4 / A8 — live identity).
//
//  Filters & guards
//  ────────────────
//    - Min ad duration 500 ms — pods / breaks shorter than that are dropped
//      (Android `MTConstants.MIN_AD_DURATION_MS`, prevents single-segment
//      false positives).
//    - Bug A6 / spec "validate pod fits in break": pods whose `endTimeMs`
//      would exceed the parent break's `endTimeMs` are clamped to the break
//      boundary. The number of clamped pods is exposed via
//      `+[MTHlsParser lastClampedPodCount]` for debug logging.
//
//  iOS / tvOS integration note
//  ───────────────────────────
//  `AVPlayerItemMetadataOutput` surfaces `EXT-X-DATERANGE` entries as
//  `AVTimedMetadataGroup` items at runtime. The tracker wiring (T07/T09)
//  feeds either the raw `.m3u8` text (initial parse) or runtime metadata
//  groups into this parser. Unit tests exercise the text path directly.
//

#import <Foundation/Foundation.h>
#import "MTManifestParser.h"

@class MTManifestParseResult;

NS_ASSUME_NONNULL_BEGIN

@interface MTHlsParser : NSObject <MTManifestParser>

/// `MTManifestParser` conformance (T11 seam). Decodes `manifest` as UTF-8 and
/// delegates to `+parseManifestText:manifestURL:customSegmentMarkers:` with
/// `customSegmentMarkers = nil`. Empty `manifest` returns an empty result.
///
/// Customers needing custom segment markers should keep using the class
/// method directly; the protocol carries no slot for them on purpose so the
/// seam stays manifest-format agnostic.
- (MTManifestParseResult *)parseManifest:(nullable NSData *)manifest
                                 baseURL:(nullable NSURL *)baseURL;

/// Parse an HLS manifest (`.m3u8`) into ad breaks + optional tracking URL.
///
/// @param manifestText Raw manifest body. Nil / empty → returns empty result.
/// @param manifestURL  Manifest URL used to resolve a relative `URI`
///                     attribute in a DATERANGE marker. May be nil; in that
///                     case relative URIs are returned unresolved.
/// @param customSegmentMarkers Optional caller-supplied substrings appended to
///                     the default segment-marker list
///                     (`+[MTDetector defaultSegmentMarkers]`). For non-`/tm/`
///                     CDN paths.
+ (MTManifestParseResult *)parseManifestText:(nullable NSString *)manifestText
                                 manifestURL:(nullable NSURL *)manifestURL
                        customSegmentMarkers:(nullable NSArray<NSString *> *)customSegmentMarkers;

/// Convenience: zero custom markers, nil manifest URL.
+ (MTManifestParseResult *)parseManifestText:(nullable NSString *)manifestText;

/// Number of pods clamped to the break boundary by the most recent parse on
/// this thread (Bug A6 telemetry). Reset to 0 at the start of every parse.
+ (NSInteger)lastClampedPodCount;

@end

@class MTAdBreak;
@class MTAdPod;

/// Bug A6 entry point — exposed for unit tests and for the schedule merger
/// (T06) to reuse the same clamp policy. Not part of the runtime parse path.
/// Increments the thread-local `lastClampedPodCount` when a clamp occurs.
/// Returns YES if the pod was modified (clamped or rejected).
@interface MTHlsParser (PodClampValidation)
+ (BOOL)clampPodIfNeeded:(MTAdPod *)pod toBreak:(MTAdBreak *)br;
@end


NS_ASSUME_NONNULL_END
