//
//  MTAdScheduleMerger.m
//  NRMediaTailorTracker
//

#import "MTAdScheduleMerger.h"
#import "MergedSchedule.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"
#import "MTAvail.h"
#import "MTAd.h"
#import "MTTrackingResponse.h"

/// VOD pairing tolerance: a manifest break and an avail are considered the
/// same if their `startTimeMs` differ by ≤ this value. Android used 500 ms;
/// we keep the same value for VOD parity. Live uses the wall-clock dedup
/// key instead so this tolerance never applies there.
static const NSTimeInterval kMTMergerStartTimeToleranceMs = 500.0;

@implementation MTAdScheduleMerger

+ (MergedSchedule *)mergeManifestBreaks:(NSArray<MTAdBreak *> *)manifestBreaks
                       trackingResponse:(MTTrackingResponse *)tracking {
    NSMutableArray<MTAdBreak *> *outBreaks = [NSMutableArray array];
    NSMutableArray<MTMergedScheduleError *> *errors = [NSMutableArray array];

    NSArray<MTAvail *> *avails = tracking.avails ?: @[];
    NSMutableSet<MTAvail *> *consumedAvails = [NSMutableSet set];
    NSMutableSet<NSString *> *seenDedupKeys = [NSMutableSet set];

    // Pass 1: walk the manifest breaks and enrich each one with the best-
    // matching avail. Manifest geometry wins (Bug A3); tracking provides
    // metadata only.
    for (MTAdBreak *manifestBreak in (manifestBreaks ?: @[])) {
        MTAvail *match = [self matchAvailForBreak:manifestBreak in:avails consumed:consumedAvails];
        if (match) {
            [consumedAvails addObject:match];
            [self enrichBreak:manifestBreak withAvail:match outErrors:errors];
        }

        NSString *key = [self dedupKeyForBreak:manifestBreak];
        if (![seenDedupKeys containsObject:key]) {
            [seenDedupKeys addObject:key];
            [outBreaks addObject:manifestBreak];
        }
        // else: A4 — duplicate (live window slide). Drop it.
    }

    // Pass 2: surface avails that did NOT match any manifest break. This
    // covers two cases:
    //   (a) Tracking-API ahead of the manifest (no-fill avail before any
    //       ad segment lands in the player's window).
    //   (b) DATERANGE-only avails synthesized as no-fill by the HLS parser
    //       already arrived in `manifestBreaks` — those got matched above.
    // We still need to emit AD_BREAK_START / AD_BREAK_END for empty avails
    // returned by the tracking API that have no manifest analog (A2).
    for (MTAvail *avail in avails) {
        if ([consumedAvails containsObject:avail]) continue;
        if (avail.ads.count > 0) {
            // Non-empty avail with no manifest counterpart — likely because
            // the player hasn't reached the segments yet. Leave it for a
            // subsequent merge pass when the manifest catches up.
            continue;
        }
        MTAdBreak *synthetic = [self syntheticBreakFromAvail:avail];
        NSString *key = [self dedupKeyForBreak:synthetic];
        if ([seenDedupKeys containsObject:key]) continue;
        [seenDedupKeys addObject:key];

        synthetic.isNoFill = YES;
        [outBreaks addObject:synthetic];
        [errors addObject:[[MTMergedScheduleError alloc] initWithBreak:synthetic
                                                             errorCode:MTAdErrorCodeNoFill
                                                               message:@"avail returned with empty ads"]];
    }

    return [[MergedSchedule alloc] initWithBreaks:outBreaks pendingErrors:errors];
}

#pragma mark - Matching

/// Find the avail that best corresponds to a manifest break.
/// Live (both sides carry wall-clock): match on programDateTime exact equality.
/// VOD (no wall-clock): match by absolute startTimeMs within tolerance.
+ (nullable MTAvail *)matchAvailForBreak:(MTAdBreak *)br
                                      in:(NSArray<MTAvail *> *)avails
                                consumed:(NSSet<MTAvail *> *)consumed {
    // Pass 1 — Live: programDateTime exact equality.
    for (MTAvail *avail in avails) {
        if ([consumed containsObject:avail]) continue;
        if (br.availProgramDateTime.length > 0 &&
            [avail.availProgramDateTime isEqualToString:br.availProgramDateTime]) {
            return avail;
        }
    }
    // Pass 2 — same availId. Lets a manifest break carry an availId from a
    // DATERANGE marker and still find its tracking-API counterpart even when
    // the tracking-API avail is missing startTimeInSeconds (Bug A8 trigger).
    if (br.availId.length > 0) {
        for (MTAvail *avail in avails) {
            if ([consumed containsObject:avail]) continue;
            if ([avail.availId isEqualToString:br.availId]) return avail;
        }
    }
    // Pass 3 — VOD: closest startTimeMs within tolerance among avails that
    // actually have a startTimeInSeconds.
    MTAvail *best = nil;
    NSTimeInterval bestDelta = kMTMergerStartTimeToleranceMs;
    for (MTAvail *avail in avails) {
        if ([consumed containsObject:avail]) continue;
        if (!avail.hasStartTime) continue;
        NSTimeInterval delta = fabs(avail.startTimeMs - br.startTimeMs);
        if (delta <= bestDelta) {
            best = avail;
            bestDelta = delta;
        }
    }
    if (best) return best;
    // Pass 4 — positional fallback for the Bug A8 case: a single unconsumed
    // avail with `hasStartTime == NO` pairs with the current manifest break.
    // Without this, the data-integrity warning would never fire.
    MTAvail *positional = nil;
    for (MTAvail *avail in avails) {
        if ([consumed containsObject:avail]) continue;
        if (avail.hasStartTime) continue;
        if (positional) return nil; // ambiguous — refuse to guess
        positional = avail;
    }
    return positional;
}

#pragma mark - Enrichment

+ (void)enrichBreak:(MTAdBreak *)br
          withAvail:(MTAvail *)avail
          outErrors:(NSMutableArray<MTMergedScheduleError *> *)errors {
    // Carry availId / programDateTime forward when the manifest parse didn't
    // already have them.
    if (br.availId.length == 0) br.availId = avail.availId;
    if (br.availProgramDateTime.length == 0) {
        br.availProgramDateTime = avail.availProgramDateTime;
    }

    // Bug A2: empty ads → no-fill break.
    if (avail.isNoFill) {
        br.isNoFill = YES;
        [errors addObject:[[MTMergedScheduleError alloc] initWithBreak:br
                                                             errorCode:MTAdErrorCodeNoFill
                                                               message:@"avail returned with empty ads"]];
        return;
    }

    // Bug A8: avail missing startTimeInSeconds, but ads are present.
    // Log + queue AD_ERROR + fall back.
    if (!avail.hasStartTime) {
        NSLog(@"[NRMediaTailorTracker] dataIntegrityWarning: avail %@ missing startTimeInSeconds; falling back to first ad startTime",
              avail.availId ?: @"<nil>");
        [errors addObject:[[MTMergedScheduleError alloc] initWithBreak:br
                                                             errorCode:MTAdErrorCodeMissingAvailStart
                                                               message:@"avail missing startTimeInSeconds; inferred from first ad"]];
        MTAd *firstAd = avail.ads.firstObject;
        if (firstAd && br.startTimeMs == 0.0) {
            br.startTimeMs = firstAd.startTimeMs;
        }
    }

    NSUInteger manifestPodCount = br.pods.count;
    NSUInteger trackingAdCount = avail.ads.count;

    if (manifestPodCount == 0) {
        // Manifest didn't carve any pods inside this break (rare — usually
        // the HLS parser always emits at least one pod for a non-empty break).
        // Synthesise pods 1:1 from the avail's ads so downstream code can
        // operate on them.
        for (MTAd *ad in avail.ads) {
            MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:ad.startTimeMs durationMs:ad.durationMs];
            [self applyAd:ad toPod:pod];
            [br.pods addObject:pod];
        }
    } else if (manifestPodCount == trackingAdCount) {
        // Happy path: 1:1 enrichment by index.
        for (NSUInteger i = 0; i < manifestPodCount; i++) {
            [self applyAd:avail.ads[i] toPod:br.pods[i]];
        }
    } else {
        // Bug A3: count mismatch. Keep manifest geometry, enrich each pod
        // with the closest-by-startTime tracking ad, flag the break.
        br.podCountMismatch = YES;
        [errors addObject:[[MTMergedScheduleError alloc] initWithBreak:br
                                                             errorCode:MTAdErrorCodeManifestTrackingMismatch
                                                               message:[NSString stringWithFormat:@"manifest pods=%lu tracking ads=%lu",
                                                                        (unsigned long)manifestPodCount,
                                                                        (unsigned long)trackingAdCount]]];
        for (MTAdPod *pod in br.pods) {
            MTAd *closest = [self closestAdInAvail:avail toStartTimeMs:pod.startTimeMs];
            if (closest) [self applyAd:closest toPod:pod];
        }
    }
}

+ (void)applyAd:(MTAd *)ad toPod:(MTAdPod *)pod {
    // Bug B2: identity = creativeId primary, composite fallback.
    pod.primaryKey = [ad primaryKey];
    pod.creativeId = ad.creativeId;
    pod.adId = ad.adId;
    pod.adTitle = ad.adTitle;
    pod.adSystem = ad.adSystem;
    pod.creativeSequence = ad.creativeSequence;
    pod.vastAdId = ad.vastAdId;
    pod.skipOffset = ad.skipOffset;
    pod.adProgramDateTime = ad.adProgramDateTime;
    pod.isBumper = ad.isBumper;
}

+ (nullable MTAd *)closestAdInAvail:(MTAvail *)avail toStartTimeMs:(NSTimeInterval)startMs {
    MTAd *best = nil;
    NSTimeInterval bestDelta = INFINITY;
    for (MTAd *ad in avail.ads) {
        NSTimeInterval delta = fabs(ad.startTimeMs - startMs);
        if (delta < bestDelta) {
            best = ad;
            bestDelta = delta;
        }
    }
    return best;
}

#pragma mark - Synthetic breaks (avails with no manifest analog)

+ (MTAdBreak *)syntheticBreakFromAvail:(MTAvail *)avail {
    NSTimeInterval startMs = avail.hasStartTime ? avail.startTimeMs : 0.0;
    MTAdBreak *br = [[MTAdBreak alloc] initWithAvailId:avail.availId
                                           startTimeMs:startMs
                                            durationMs:avail.durationMs];
    if (avail.availProgramDateTime.length > 0) {
        br.availProgramDateTime = avail.availProgramDateTime;
    }
    return br;
}

#pragma mark - A4 dedup key

/// Compound key: prefer wall-clock (live), fall back to startTimeMs (VOD).
+ (NSString *)dedupKeyForBreak:(MTAdBreak *)br {
    NSString *availId = br.availId.length > 0 ? br.availId : @"";
    NSString *time = br.availProgramDateTime.length > 0
                         ? br.availProgramDateTime
                         : [NSString stringWithFormat:@"%.0f", br.startTimeMs];
    return [NSString stringWithFormat:@"%@|%@", availId, time];
}

@end
