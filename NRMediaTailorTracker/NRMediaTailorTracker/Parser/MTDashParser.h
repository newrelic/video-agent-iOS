//
//  MTDashParser.h
//  NRMediaTailorTracker
//
//  DASH MPD manifest parser. Conforms to `MTManifestParser` (T11 seam) and
//  ships as the default DASH adapter alongside `MTHlsParser`.
//
//  Bug A7 fix
//  ──────────
//  The Android `MTDashParser.java` classified a `<Period>` as "ad" based on
//  the *first* `<Representation>`'s BaseURL. That is wrong: a DASH period can
//  legitimately mix representations with different BaseURLs (e.g. per-rendition
//  re-hosting via Segment Templates). The iOS parser resolves every
//  representation's effective URL (period → adaptation-set → representation
//  BaseURL inheritance) and only classifies a period as ad when **every**
//  representation matches an ad-segment marker. Mixed → content (no break).
//  Mixed-classification periods are counted on the parser instance — see
//  `-mixedPeriodCount` — so tests can pin the A7 fix down.
//
//  SCTE-35 EventStream
//  ───────────────────
//  Periods carrying `<EventStream schemeIdUri="urn:scte:scte35:2014:xml">` or
//  `urn:aws:elemental:mediatailor:tracking` are treated as ad-break markers
//  regardless of BaseURL classification — they're the DASH analogue of the
//  HLS DATERANGE tracking marker. Each `<Event>` produces an `MTAdBreak`
//  whose start / duration are scaled by the parent `EventStream`'s
//  `timescale`.
//
//  Tracking URL
//  ────────────
//  Recovered from a top-level `<Location>` element when present (DASH
//  equivalent of HLS DATERANGE `CLASS="tracking"` URI). Nil if absent — the
//  caller falls back to `+[MTDetector deriveTrackingURL:]` (Bug B4 fallback).
//
//  Filters & guards
//  ────────────────
//  Same min-ad-duration filter as HLS: periods with `durationMs < 500` are
//  dropped. Periods without a `duration` attribute are skipped (with a
//  warning log). Malformed XML, non-UTF-8 bytes, nil/empty input — all
//  return `[MTManifestParseResult empty]` rather than crashing.
//

#import <Foundation/Foundation.h>
#import "MTManifestParser.h"

@class MTManifestParseResult;

NS_ASSUME_NONNULL_BEGIN

@interface MTDashParser : NSObject <MTManifestParser>

- (instancetype)init;

/// `MTManifestParser` conformance. Decodes `manifest` as UTF-8 and parses it
/// as a DASH MPD via `NSXMLParser`. Empty / nil / non-UTF-8 / malformed input
/// returns `[MTManifestParseResult empty]`.
- (MTManifestParseResult *)parseManifest:(nullable NSData *)manifest
                                 baseURL:(nullable NSURL *)baseURL;

/// Bug A7 telemetry — number of `<Period>`s seen across the lifetime of this
/// parser instance where representations disagreed on ad-vs-content
/// classification (and were therefore classified as content). Unit tests
/// assert against this to verify the A7 fix actually triggers on mixed
/// fixtures. Per-instance, not per-thread.
- (NSUInteger)mixedPeriodCount;

@end

NS_ASSUME_NONNULL_END
