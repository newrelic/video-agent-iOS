//
//  MTAdScheduleMerger.h
//  NRMediaTailorTracker
//
//  Stateless merger that combines manifest-detected ad breaks
//  (`MTHlsParser` output) with tracking-API enrichment (`MTTrackingResponse`).
//
//  Bug fixes carried by this stage
//  ────────────────────────────────
//  * **A2 — Empty avails are no-fill.** When `MTAvail.ads.count == 0`, the
//    matching break is flagged `isNoFill = YES` and a queued
//    `MTAdErrorCodeNoFill` is appended to `pendingErrors`. T08 emits
//    AD_BREAK_START → AD_ERROR(NO_FILL) → AD_BREAK_END; AD_START / quartiles
//    are suppressed by the state machine (T07).
//  * **A3 — Pod-count mismatch keeps manifest geometry.** When manifest pod
//    count and tracking ad count disagree, manifest pod boundaries are
//    PRESERVED. Each pod is enriched with metadata from the closest-by-
//    startTime tracking ad. `podCountMismatch = YES` is set, and a queued
//    `MTAdErrorCodeManifestTrackingMismatch` is appended.
//  * **A4 — Compound de-dup key.** Identity is
//    `(availId, adProgramDateTime ?? startTimeMs)`. For VOD this collapses
//    to startTimeMs; for live the wall-clock keeps identity stable across
//    HLS sliding-window rotation.
//  * **A8 — Missing avail start is logged and surfaced.** When
//    `MTAvail.hasStartTime == NO` and `ads.count > 0`, the merger logs a
//    `dataIntegrityWarning`, queues `MTAdErrorCodeMissingAvailStart`, and
//    THEN falls back to the first ad's `startTimeMs`.
//  * **B2 — `creativeId` primary identity.** Pod `primaryKey` is set via
//    `-[MTAd primaryKey]` (creativeId if present, else `<availId>:<adId>`).
//

#import <Foundation/Foundation.h>

@class MergedSchedule;
@class MTAdBreak;
@class MTTrackingResponse;

NS_ASSUME_NONNULL_BEGIN

@interface MTAdScheduleMerger : NSObject

/// Merge manifest-detected ad breaks with tracking-API enrichment.
///
/// @param manifestBreaks Ordered list of breaks from `MTHlsParser` (pod
///                       boundaries + absolute timing). May be empty.
/// @param tracking       Decoded tracking response (avails with rich ad
///                       metadata). May be nil; merger treats nil as a
///                       fresh response with no avails.
/// @return Merged schedule. Never nil.
+ (MergedSchedule *)mergeManifestBreaks:(nullable NSArray<MTAdBreak *> *)manifestBreaks
                       trackingResponse:(nullable MTTrackingResponse *)tracking;

@end

NS_ASSUME_NONNULL_END
