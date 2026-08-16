//
//  NRTrackerMediaTailor.m
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//  Subclasses NRVideoTracker (NewRelicVideoCore). Mirrors NRTrackerIMA's
//  role: a passive observer that detects MediaTailor ads inside an
//  AVPlayer stream and emits AD_BREAK_START / AD_START / AD_QUARTILE /
//  AD_END / AD_BREAK_END / AD_ERROR.
//
//  ---------------------------------------------------------------------------
//  SDK-Boundary Anti-Pattern Guardrails (do NOT do these)
//  ---------------------------------------------------------------------------
//  1. Do NOT fire VAST tracking beacons. Server-side mode = MediaTailor fires
//     them. Client-side mode = customer's player fires them. We observe; we do
//     not transmit ad-server beacons.
//  2. Do NOT resolve VAST wrappers. MediaTailor returns final ad metadata.
//  3. Do NOT implement ad personalization or targeting.
//  4. Do NOT cache ads across sessions.
//  5. Do NOT modify manifest query parameters.
//  6. Do NOT implement avail suppression (`BEHIND_LIVE_EDGE` etc.) logic.
//  7. Do NOT render ad UI, pause the player, or call back into customer
//     business logic.
//  8. Do NOT assume every avail has ads (empty = no-fill, handle explicitly).
//  9. Do NOT pre-fire impression beacons before confirming the ad played.
//  10. Do NOT perform OMID / viewability handoff. That's an app-layer concern.
//  ---------------------------------------------------------------------------
//

#import "NRTrackerMediaTailor.h"
#import "MTManifestParser.h"
#import "MTHlsParser.h"
#import "MTDashParser.h"
#import "MTManifestParseResult.h"
#import "MTPlayheadStateMachine.h"
#import "MergedSchedule.h"
#import "MTAdScheduleMerger.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"
#import "MTAdErrorCode.h"
#import "MTTrackingClient.h"
#import "MTManifestFetcher.h"
#import "MTDetector.h"

NSString * const NRMediaTailorTrackerErrorDomain = @"NRMediaTailorTracker";

/// KVO context for the `timeControlStatus` observation. Using a static
/// context pointer prevents accidental delivery of unrelated observations
/// from being interpreted as the player's pause/resume.
static void * const kTrackerTimeControlStatusContext = (void *)&kTrackerTimeControlStatusContext;

/// KVO context for the `currentItem` observation that drives auto-activation
/// (see `NRTrackerMediaTailor.h`'s "Auto-activation" docs).
static void * const kTrackerCurrentItemContext = (void *)&kTrackerCurrentItemContext;

/// Ceiling on how long to wait for AVPlayer's access log to reveal a
/// resolved session for a direct/implicit entry URL before giving up. Not a
/// tuning knob (no property) — this only fires when playback itself never
/// makes progress, which is a diagnosable failure, not a timing edge case
/// worth exposing as configuration.
static const NSTimeInterval kAccessLogDiscoveryTimeout = 20.0;

@interface NRTrackerMediaTailor () <MTPlayheadStateMachineDelegate>

@property (nonatomic, strong, nullable, readwrite) MTPlayheadStateMachine *stateMachine;
@property (nonatomic, strong, nullable) MTTrackingClient *trackingClient;
@property (nonatomic, strong, nullable) MTManifestFetcher *manifestFetcher;

@property (nonatomic, weak, nullable) AVPlayer *avPlayer;
@property (nonatomic, assign) BOOL hasInstalledTimeControlObserver;
@property (nonatomic, assign) BOOL hasInstalledCurrentItemObserver;

/// The `AVPlayerItem` currently being watched via
/// `AVPlayerItemNewAccessLogEntryNotification` while waiting for a
/// direct/implicit entry URL's real session to reveal itself (see
/// `-beginAccessLogDiscoveryForItem:originalURL:`). Nil when no discovery is
/// in flight. `weak` — this class does not own the item's lifecycle.
@property (nonatomic, weak, nullable) AVPlayerItem *accessLogObservedItem;

/// Fires `-accessLogDiscoveryTimedOutForURL:` if AVPlayer's access log never
/// reveals a resolved session within `kAccessLogDiscoveryTimeout` — without
/// this, a stream that never actually starts playing would leave
/// auto-activation silently stuck in `AwaitingSessionDiscovery` forever.
@property (nonatomic, strong, nullable) NSTimer *accessLogDiscoveryTimeoutTimer;

@property (nonatomic, weak, nullable) MTAdBreak *currentBreak;
@property (nonatomic, weak, nullable) MTAdPod *currentPod;
@property (nonatomic, assign) NSInteger currentQuartileNumber;

@property (nonatomic, assign, readwrite) BOOL isDisposed;

@property (nonatomic, assign, readwrite) NRMediaTailorTrackingStatus activationStatus;
@property (nonatomic, copy, nullable, readwrite) NSString *activationStatusMessage;

/// The `currentItem` asset URL auto-activation last began fetching for.
/// Dedupes redundant KVO fires (e.g. `NSKeyValueObservingOptionInitial` plus
/// a same-URL `-replaceCurrentItemWithPlayerItem:`) and, on every
/// auto-activation completion handler, confirms the completing fetch is
/// still the most recent one before acting — a later `currentItem` change
/// silently supersedes an in-flight fetch rather than racing it.
@property (nonatomic, strong, nullable) NSURL *lastAutoActivationURL;

/// Sticky: once a manual `-startTrackingWithSchedule:` call happens, this is
/// permanently YES for the remainder of the instance's lifetime, so
/// auto-activation never overwrites a manual schedule — regardless of
/// whether the manual call landed before, during, or after an in-flight
/// auto-activation fetch.
@property (nonatomic, assign) BOOL autoActivationSuppressed;

@end

@implementation NRTrackerMediaTailor

#pragma mark - Init / dealloc

- (instancetype)init {
    self = [super init];
    if (self) {
        _trackingClient = [[MTTrackingClient alloc] init];
        _manifestFetcher = [[MTManifestFetcher alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self dispose];
}

- (id<MTManifestParser>)manifestParser {
    if (_manifestParser == nil) {
        MTHlsParser *hls = [[MTHlsParser alloc] init];
        hls.customSegmentMarkers = [self customSegmentMarkers];
        _manifestParser = hls;
    }
    return _manifestParser;
}

#pragma mark - Config plumbing

- (void)setAdSegmentPrefix:(NSString *)adSegmentPrefix {
    _adSegmentPrefix = [adSegmentPrefix copy];
    // Push into an already-created HLS parser; the lazy getter covers the
    // not-yet-created case.
    if ([_manifestParser isKindOfClass:[MTHlsParser class]]) {
        ((MTHlsParser *)_manifestParser).customSegmentMarkers = [self customSegmentMarkers];
    }
}

/// The configured prefix as the parser's extra-markers array (nil when unset).
- (nullable NSArray<NSString *> *)customSegmentMarkers {
    return _adSegmentPrefix.length > 0 ? @[_adSegmentPrefix] : nil;
}

- (nullable NSURL *)resolvedTrackingURLForManifestURL:(nullable NSURL *)manifestURL {
    if (self.trackingUrl.length > 0) {
        return [NSURL URLWithString:self.trackingUrl];
    }
    return [MTDetector deriveTrackingURL:manifestURL];
}

/// `pollIntervalMs` as seconds for the state machine: 0 → 250 ms default;
/// otherwise clamped to [100, 5000] ms with a warning on out-of-range.
- (NSTimeInterval)resolvedPlayheadPollInterval {
    NSUInteger ms = self.pollIntervalMs;
    if (ms == 0) { return 0.250; }
    if (ms < 100) {
        NSLog(@"[NRMediaTailorTracker] pollIntervalMs %lu below 100ms floor; clamping to 100.", (unsigned long)ms);
        ms = 100;
    } else if (ms > 5000) {
        NSLog(@"[NRMediaTailorTracker] pollIntervalMs %lu above 5000ms ceiling; clamping to 5000.", (unsigned long)ms);
        ms = 5000;
    }
    return (NSTimeInterval)ms / 1000.0;
}

#pragma mark - NRAdTrackerConfigurable

- (void)configureWithAdConfig:(NRAdConfig *)adConfig player:(nullable id)player {
    if (self.isDisposed) { return; }
    if (player) {
        [self setPlayer:player];
    }
    if (adConfig.adSegmentPrefix.length > 0) {
        self.adSegmentPrefix = adConfig.adSegmentPrefix;
    }
    if (adConfig.trackingUrl.length > 0) {
        self.trackingUrl = adConfig.trackingUrl;
    }
}

#pragma mark - Player attachment / KVO

- (void)setPlayer:(id)player {
    if (self.isDisposed) { return; }
    if (![player isKindOfClass:[AVPlayer class]]) {
        [super setPlayer:player];
        return;
    }
    AVPlayer *newPlayer = (AVPlayer *)player;

    [self detachFromCurrentPlayer];

    self.avPlayer = newPlayer;
    [self installTimeControlStatusObserver];
    [self installCurrentItemObserver];

    if (self.stateMachine != nil) {
        [self.stateMachine attachToPlayer:newPlayer];
    }

    [super setPlayer:player];
}

- (void)installTimeControlStatusObserver {
    if (self.avPlayer == nil) { return; }
    if (self.hasInstalledTimeControlObserver) { return; }
    [self.avPlayer addObserver:self
                    forKeyPath:@"timeControlStatus"
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                       context:kTrackerTimeControlStatusContext];
    self.hasInstalledTimeControlObserver = YES;
}

- (void)removeTimeControlStatusObserver {
    if (!self.hasInstalledTimeControlObserver) { return; }
    AVPlayer *player = self.avPlayer;
    if (player != nil) {
        @try {
            [player removeObserver:self
                        forKeyPath:@"timeControlStatus"
                           context:kTrackerTimeControlStatusContext];
        } @catch (NSException *exception) {
            // Defensive: removing an observer that wasn't installed throws.
            // We track our own install flag, so this should not happen, but
            // we keep the @try to harden against subclasses or unusual
            // lifecycles.
        }
    }
    self.hasInstalledTimeControlObserver = NO;
}

/// `NSKeyValueObservingOptionInitial` covers the common case
/// (`[AVPlayer playerWithURL:]` sets `currentItem` synchronously, so the
/// observer fires immediately with the item already in place); the `New`
/// delivery option covers a later `-replaceCurrentItemWithPlayerItem:`.
- (void)installCurrentItemObserver {
    if (self.avPlayer == nil) { return; }
    if (self.hasInstalledCurrentItemObserver) { return; }
    [self.avPlayer addObserver:self
                    forKeyPath:@"currentItem"
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                       context:kTrackerCurrentItemContext];
    self.hasInstalledCurrentItemObserver = YES;
}

- (void)removeCurrentItemObserver {
    if (!self.hasInstalledCurrentItemObserver) { return; }
    AVPlayer *player = self.avPlayer;
    if (player != nil) {
        @try {
            [player removeObserver:self
                        forKeyPath:@"currentItem"
                           context:kTrackerCurrentItemContext];
        } @catch (NSException *exception) {
            // Defensive, see removeTimeControlStatusObserver.
        }
    }
    self.hasInstalledCurrentItemObserver = NO;
}

- (void)detachFromCurrentPlayer {
    [self.stateMachine detachFromPlayer];
    [self removeTimeControlStatusObserver];
    [self removeCurrentItemObserver];
    [self stopAccessLogDiscovery];
    self.avPlayer = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context {
    if (context == kTrackerCurrentItemContext) {
        // Mirrors the timeControlStatus hop below: AVFoundation does not
        // guarantee currentItem KVO lands on the main thread, and
        // activationStatus / lastAutoActivationURL are main-queue-only state.
        if (!NSThread.isMainThread) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self observeValueForKeyPath:keyPath ofObject:object change:change context:context];
            });
            return;
        }
        if (self.isDisposed) { return; }
        [self handlePossibleCurrentItemChange:change[NSKeyValueChangeNewKey]];
        return;
    }
    if (context != kTrackerTimeControlStatusContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    // AVFoundation does not guarantee timeControlStatus KVO notifications
    // land on the main thread, but currentBreak/currentPod are written only
    // on the main queue (MTPlayheadStateMachine's delegate callbacks run on
    // its main-queue-only periodic time observer). Hop over before touching
    // them to avoid a TOCTOU race against a break/pod exiting mid-read.
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        });
        return;
    }
    if (self.isDisposed) { return; }
    // Only emit pause / resume while inside an ad break — main-content
    // pause/resume is the customer's content tracker's concern.
    if (self.currentBreak == nil) { return; }

    AVPlayerTimeControlStatus newStatus =
        (AVPlayerTimeControlStatus)[change[NSKeyValueChangeNewKey] integerValue];
    AVPlayerTimeControlStatus oldStatus =
        (AVPlayerTimeControlStatus)[change[NSKeyValueChangeOldKey] integerValue];

    if (newStatus == AVPlayerTimeControlStatusPaused &&
        oldStatus != AVPlayerTimeControlStatusPaused) {
        [self sendPause];
    } else if (newStatus == AVPlayerTimeControlStatusPlaying &&
               oldStatus == AVPlayerTimeControlStatusPaused) {
        [self sendResume];
    }
}

#pragma mark - Auto-activation (triggered from the currentItem KVO above)

/// `newItemValue` is the KVO change dictionary's `NSKeyValueChangeNewKey`
/// entry for `currentItem` — an `AVPlayerItem`, or `NSNull` when the player
/// has no item. The `isKindOfClass:` checks below make both that case and a
/// bare `[[AVPlayer alloc] init]` (no item ever set) harmless no-ops.
- (void)handlePossibleCurrentItemChange:(id)newItemValue {
    // Any prior discovery was watching a now-superseded item/URL — including
    // the case where this fires again for a genuinely different item after a
    // non-MediaTailor detour, so also reset the dedup guard rather than leave
    // it pointing at a URL whose discovery was just torn down.
    [self stopAccessLogDiscovery];
    self.lastAutoActivationURL = nil;

    if (![newItemValue isKindOfClass:[AVPlayerItem class]]) { return; }
    AVPlayerItem *item = (AVPlayerItem *)newItemValue;
    AVAsset *asset = item.asset;
    if (![asset isKindOfClass:[AVURLAsset class]]) { return; }

    NSURL *url = ((AVURLAsset *)asset).URL;
    if (![MTDetector isMediaTailorURL:url]) {
        self.activationStatus = NRMediaTailorTrackingStatusSkippedNotMediaTailor;
        self.activationStatusMessage = nil;
        return;
    }

    if ([MTDetector extractSessionId:url] != nil) {
        // Already session-tagged (explicit flow's resolved URL, or a
        // resolved sub-manifest/segment URL) — fetching this directly is
        // safe. It reads within the existing session; it does not mint a
        // new one.
        [self beginAutoActivationForURL:url];
        return;
    }

    // Bare direct/implicit entry URL: see the class doc's "Auto-activation"
    // section for why we deliberately do not fetch this ourselves.
    [self beginAccessLogDiscoveryForItem:item originalURL:url];
}

- (void)beginAutoActivationForURL:(NSURL *)url {
    if (self.autoActivationSuppressed) { return; }
    if ([self.lastAutoActivationURL isEqual:url]) { return; } // already fetching/fetched this exact URL
    self.lastAutoActivationURL = url;

    self.activationStatus = NRMediaTailorTrackingStatusFetchingManifest;
    self.activationStatusMessage = nil;

    __weak typeof(self) weakSelf = self;
    [self.manifestFetcher fetchManifestAtURL:url completion:^(MTManifestFetchResult * _Nullable result, NSError * _Nullable error) {
        [weakSelf handleManifestFetchResult:result error:error forURL:url];
    }];
}

#pragma mark - Direct/implicit-flow session discovery (via AVPlayerItemAccessLog)

/// A bare entry URL carries no session id, so fetching it ourselves would
/// mint a session distinct from the one AVPlayer's own native HLS engine
/// mints when *it* fetches the same URL to actually play the stream (see the
/// class doc's "Auto-activation" section). Instead, watch for AVPlayer's own
/// requests — surfaced via `AVPlayerItemAccessLog` — to reveal the session
/// actually in use, then resolve everything from that.
- (void)beginAccessLogDiscoveryForItem:(AVPlayerItem *)item originalURL:(NSURL *)originalURL {
    if (self.autoActivationSuppressed) { return; }
    if ([self.lastAutoActivationURL isEqual:originalURL]) { return; } // already discovering this exact bare URL
    self.lastAutoActivationURL = originalURL;

    self.activationStatus = NRMediaTailorTrackingStatusAwaitingSessionDiscovery;
    self.activationStatusMessage = nil;

    self.accessLogObservedItem = item;
    [NSNotificationCenter.defaultCenter addObserver:self
                                            selector:@selector(handleNewAccessLogEntryNotification:)
                                                name:AVPlayerItemNewAccessLogEntryNotification
                                              object:item];

    // Covers the unlikely case where an access-log entry already exists by
    // the time we start observing.
    if ([self trySessionDiscoveryFromAccessLogOfItem:item originalURL:originalURL]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    self.accessLogDiscoveryTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kAccessLogDiscoveryTimeout
                                                                           repeats:NO
                                                                             block:^(NSTimer * _Nonnull timer) {
        [weakSelf accessLogDiscoveryTimedOutForURL:originalURL];
    }];
}

- (void)handleNewAccessLogEntryNotification:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleNewAccessLogEntryNotification:notification];
        });
        return;
    }
    if (self.isDisposed) { return; }
    AVPlayerItem *item = notification.object;
    if (![item isKindOfClass:[AVPlayerItem class]]) { return; }
    NSURL *originalURL = self.lastAutoActivationURL;
    if (originalURL == nil) { return; }
    [self trySessionDiscoveryFromAccessLogOfItem:item originalURL:originalURL];
}

/// Walks the item's access-log events and looks for one `MTDetector` can
/// read a session id from. Returns YES (and hands off to
/// `-beginAutoActivationForURL:`) the moment it finds one.
- (BOOL)trySessionDiscoveryFromAccessLogOfItem:(AVPlayerItem *)item originalURL:(NSURL *)originalURL {
    if (self.isDisposed || self.autoActivationSuppressed) { return NO; }
    if (![self.lastAutoActivationURL isEqual:originalURL]) { return NO; } // superseded by a later currentItem change

    NSMutableArray<NSString *> *uriStrings = [NSMutableArray array];
    for (AVPlayerItemAccessLogEvent *event in item.accessLog.events) {
        if (event.URI.length > 0) { [uriStrings addObject:event.URI]; }
    }
    NSURL *resolvedURL = [self firstSessionCarryingURLFromMostRecentURIStrings:uriStrings];
    if (resolvedURL == nil) { return NO; }

    [self stopAccessLogDiscovery];
    // `-beginAutoActivationForURL:` dedupes against `lastAutoActivationURL`,
    // which currently holds the bare entry URL, not this resolved one —
    // clear it first so the real fetch below isn't mistaken for a no-op
    // duplicate of the (different) bare URL.
    self.lastAutoActivationURL = nil;
    [self beginAutoActivationForURL:resolvedURL];
    return YES;
}

/// Pure core of the access-log scan, factored out from
/// `-trySessionDiscoveryFromAccessLogOfItem:originalURL:` so it's testable
/// without a real, system-populated `AVPlayerItemAccessLog` (which has no
/// public way to synthesize entries in a unit test). Walks `uriStrings` from
/// most-recent to least-recent — the freshest resolved URI is the most
/// reliable signal of the session actually in use right now — looking for
/// one `MTDetector` can read a session id from. A manifest-shaped URI (one
/// this tracker can actually fetch-and-parse as a playlist) is preferred
/// over a segment-shaped one (binary media — carries a usable session id,
/// but fetching it as a manifest would just fail); a segment URI is only
/// returned if no manifest-shaped candidate exists at all, since a usable
/// session id is still better than none.
- (nullable NSURL *)firstSessionCarryingURLFromMostRecentURIStrings:(NSArray<NSString *> *)uriStrings {
    NSURL *segmentFallback = nil;
    for (NSInteger i = (NSInteger)uriStrings.count - 1; i >= 0; i--) {
        NSString *uriString = uriStrings[i];
        if (uriString.length == 0) { continue; }
        NSURL *resolvedURL = [NSURL URLWithString:uriString];
        if (resolvedURL == nil) { continue; }
        if ([MTDetector extractSessionId:resolvedURL] == nil) { continue; }

        if ([self urlLooksLikeASegment:resolvedURL]) {
            if (segmentFallback == nil) { segmentFallback = resolvedURL; }
            continue;
        }
        return resolvedURL;
    }
    return segmentFallback;
}

/// Matches `MTDetector`'s own segment markers plus the raw AWS `/v1/segment/`
/// and `/v1/dashsegment/` conventions those markers don't cover (they
/// classify *stitched-manifest* ad segments, a different, narrower purpose).
- (BOOL)urlLooksLikeASegment:(NSURL *)url {
    NSString *s = url.absoluteString;
    if (s.length == 0) { return NO; }
    for (NSString *marker in [MTDetector defaultSegmentMarkers]) {
        if ([s containsString:marker]) { return YES; }
    }
    return [s containsString:@"/v1/segment/"] || [s containsString:@"/v1/dashsegment/"];
}

- (void)accessLogDiscoveryTimedOutForURL:(NSURL *)originalURL {
    if (self.isDisposed || self.autoActivationSuppressed) { return; }
    if (![self.lastAutoActivationURL isEqual:originalURL]) { return; } // already resolved or superseded

    [self stopAccessLogDiscovery];
    self.activationStatus = NRMediaTailorTrackingStatusManifestFetchFailed;
    self.activationStatusMessage = [NSString stringWithFormat:
        @"MediaTailor auto-activation timed out after %.0fs waiting for playback to reveal a resolved "
        @"session for the direct/implicit entry URL %@ (a bare entry URL carries no session id until "
        @"AVPlayer actually requests something). This usually means playback itself never made progress — "
        @"check that the player is actually loading/playing, not that the tracker failed to detect it.",
        kAccessLogDiscoveryTimeout, originalURL.absoluteString];
}

- (void)stopAccessLogDiscovery {
    [self.accessLogDiscoveryTimeoutTimer invalidate];
    self.accessLogDiscoveryTimeoutTimer = nil;
    if (self.accessLogObservedItem != nil) {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                        name:AVPlayerItemNewAccessLogEntryNotification
                                                      object:self.accessLogObservedItem];
    }
    self.accessLogObservedItem = nil;
}

- (void)handleManifestFetchResult:(nullable MTManifestFetchResult *)result
                             error:(nullable NSError *)error
                            forURL:(NSURL *)requestURL {
    if (self.isDisposed) { return; }
    if (self.autoActivationSuppressed) { return; }
    // A later currentItem change may have started a newer auto-activation
    // fetch while this one was in flight; that newer fetch owns the state
    // machine now, so this stale completion is dropped rather than racing it.
    if (![self.lastAutoActivationURL isEqual:requestURL]) { return; }

    if (error != nil) {
        self.activationStatus = NRMediaTailorTrackingStatusManifestFetchFailed;
        self.activationStatusMessage = [NSString stringWithFormat:
            @"MediaTailor manifest fetch failed (%@); ad tracking cannot start until the manifest can be "
            @"fetched. Confirm the player's manifest URL is reachable and returns a 2xx response.",
            error.localizedDescription ?: @"unknown error"];
        return;
    }

    // HLS: the URL AVPlayer actually plays is very often the top-level
    // multivariant master (#EXT-X-STREAM-INF listing renditions) — which
    // structurally CANNOT contain ad-break markers; those only exist inside
    // the per-rendition media playlists it references. Fetching one
    // rendition's media playlist instead is required to find any ad breaks
    // at all — this is not MediaTailor-specific, it's true of any
    // multivariant HLS stream. DASH has no such indirection (an MPD is
    // self-contained), so this never triggers for DASH content.
    if ([self manifestDataLooksLikeMultivariantMaster:result.manifestData]) {
        NSURL *renditionURL = [self firstRenditionURLFromMultivariantMaster:result.manifestData
                                                                      baseURL:result.finalURL];
        if (renditionURL != nil) {
            __weak typeof(self) weakSelf = self;
            [self.manifestFetcher fetchManifestAtURL:renditionURL completion:^(MTManifestFetchResult * _Nullable renditionResult, NSError * _Nullable renditionError) {
                // A rendition-fetch failure degrades to the (ad-marker-less)
                // top-level result rather than failing auto-activation
                // outright — tracking nothing is worse than tracking
                // manifest-only geometry from what we already have.
                [weakSelf continueAutoActivationWithManifestResult:(renditionResult ?: result) forRequestURL:requestURL];
            }];
            return;
        }
        // No rendition reference found in an otherwise-multivariant
        // document — fall through and parse it as-is; MTHlsParser will
        // correctly find zero breaks, which is an honest result for a
        // malformed/empty master, not a crash.
    }

    [self continueAutoActivationWithManifestResult:result forRequestURL:requestURL];
}

/// Detects an HLS multivariant/master playlist (see `-handleManifestFetchResult:...`
/// above) by the presence of `#EXT-X-STREAM-INF` — a tag that only ever
/// appears in that shape, never in a media playlist or a DASH MPD.
- (BOOL)manifestDataLooksLikeMultivariantMaster:(NSData *)manifestData {
    if (manifestData.length == 0) { return NO; }
    NSString *text = [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding];
    return [text containsString:@"#EXT-X-STREAM-INF"];
}

/// First plain (non-`#`, non-empty) line in a multivariant master — every
/// such line in a well-formed HLS multivariant playlist is itself a
/// rendition reference, so any one is equally valid: MediaTailor's ad
/// stitching (break timing/geometry) is identical across renditions, only
/// bitrate/resolution differs.
- (nullable NSURL *)firstRenditionURLFromMultivariantMaster:(NSData *)manifestData baseURL:(nullable NSURL *)baseURL {
    if (manifestData.length == 0) { return nil; }
    NSString *text = [[NSString alloc] initWithData:manifestData encoding:NSUTF8StringEncoding];
    if (text.length == 0) { return nil; }

    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0 || [line hasPrefix:@"#"]) { continue; }
        NSURL *resolved = [NSURL URLWithString:line relativeToURL:baseURL].absoluteURL;
        if (resolved != nil) { return resolved; }
    }
    return nil;
}

/// Continuation of `-handleManifestFetchResult:error:forURL:` — parse,
/// resolve the tracking URL, fetch tracking data, merge, activate. Factored
/// out so the multivariant-master branch above can re-enter it with a
/// rendition's fetch result instead of the top-level master's.
- (void)continueAutoActivationWithManifestResult:(MTManifestFetchResult *)result forRequestURL:(NSURL *)requestURL {
    if (self.isDisposed) { return; }
    if (self.autoActivationSuppressed) { return; }
    if (![self.lastAutoActivationURL isEqual:requestURL]) { return; }

    self.activationStatus = NRMediaTailorTrackingStatusFetchingTracking;

    id<MTManifestParser> parser = [self parserForFetchResult:result];
    MTManifestParseResult *parsed = [parser parseManifest:result.manifestData baseURL:result.finalURL];

    NSURL *trackingURL = [self resolveTrackingURLForParseResult:parsed
                                                     originalURL:requestURL
                                                        finalURL:result.finalURL
                                                     rawManifest:result.manifestData];

    if (trackingURL == nil) {
        // No tracking URL resolvable by any of the three paths — not a
        // failure, just nothing to fetch. Manifest-only ad-break geometry
        // still tracks.
        [self finishAutoActivationWithBreaks:parsed.breaks trackingResponse:nil forURL:requestURL];
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self.trackingClient fetchWithTrackingURL:trackingURL completion:^(MTTrackingResponse * _Nullable response, NSError * _Nullable trackingError) {
        [weakSelf handleTrackingFetchResponse:response error:trackingError breaks:parsed.breaks forURL:requestURL];
    }];
}

/// Parser selection: an explicitly-set `manifestParser` override always
/// wins (checked via the `_manifestParser` ivar directly — going through the
/// `manifestParser` getter would lazily create and cache the default HLS
/// parser on first access, making "never explicitly set" indistinguishable
/// from "explicitly set to the default"). Otherwise pick DASH vs. HLS by the
/// fetched manifest's extension / Content-Type.
- (id<MTManifestParser>)parserForFetchResult:(MTManifestFetchResult *)result {
    if (_manifestParser == nil && [self fetchResultLooksLikeDash:result]) {
        return [[MTDashParser alloc] init];
    }
    return self.manifestParser; // explicit override, or the lazy-default HLS parser (with adSegmentPrefix wired)
}

- (BOOL)fetchResultLooksLikeDash:(MTManifestFetchResult *)result {
    if ([result.finalURL.path.lowercaseString hasSuffix:@".mpd"]) { return YES; }
    NSString *contentType = result.contentType.lowercaseString;
    return contentType != nil && [contentType containsString:@"dash+xml"];
}

/// Resolve the tracking URL, in order:
///   (a) the manifest's own embedded tracking marker (HLS DATERANGE / DASH
///       EventStream), if present — the PRIMARY path (see `MTHlsParser.h`);
///   (b) `-resolvedTrackingURLForManifestURL:` against the *original*
///       request URL — handles the explicit-flow query-string session id;
///   (c) the bare direct/implicit case: recover a session-id-carrying URL
///       from inside the manifest body, then re-derive from THAT.
/// Returns nil if none of the three resolve — genuinely no tracking URL
/// available, not an error (e.g. a manifest with no ads at all).
- (nullable NSURL *)resolveTrackingURLForParseResult:(MTManifestParseResult *)parsed
                                          originalURL:(NSURL *)originalURL
                                             finalURL:(nullable NSURL *)finalURL
                                          rawManifest:(NSData *)rawManifest {
    if (parsed.trackingURL != nil) {
        return parsed.trackingURL;
    }
    NSURL *fromOriginal = [self resolvedTrackingURLForManifestURL:originalURL];
    if (fromOriginal != nil) {
        return fromOriginal;
    }
    NSURL *recovered = [self recoverSessionCarryingURLFromManifest:rawManifest baseURL:finalURL];
    if (recovered == nil) {
        return nil;
    }
    return [self resolvedTrackingURLForManifestURL:recovered];
}

/// Direct/implicit-flow gap-fill: a bare entry URL carries no session id
/// anywhere, and when the manifest has no tracking marker either,
/// `-resolvedTrackingURLForManifestURL:` has nothing to derive one from. But
/// every URL *inside* the manifest MediaTailor actually served (sub-playlist
/// / segment references) carries the session id as a path segment (see
/// `MTDetector.h`). This scans for the first plain (non-`#`, non-empty)
/// line, resolves it against `baseURL`, and returns it only if `MTDetector`
/// can read a session id out of the result. HLS-line-based; degrades
/// gracefully to nil (never crashes) for DASH or content this heuristic
/// can't parse — DASH's own EventStream tracking-URL discovery in
/// `MTDashParser` is unaffected by this method returning nil.
- (nullable NSURL *)recoverSessionCarryingURLFromManifest:(NSData *)rawManifest baseURL:(nullable NSURL *)baseURL {
    if (rawManifest.length == 0) { return nil; }
    NSString *text = [[NSString alloc] initWithData:rawManifest encoding:NSUTF8StringEncoding];
    if (text.length == 0) { return nil; }

    for (NSString *rawLine in [text componentsSeparatedByString:@"\n"]) {
        NSString *line = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length == 0 || [line hasPrefix:@"#"]) { continue; }

        NSURL *candidate = [NSURL URLWithString:line relativeToURL:baseURL].absoluteURL;
        if (candidate == nil) { continue; }
        if ([MTDetector extractSessionId:candidate] != nil) {
            return candidate;
        }
    }
    return nil;
}

- (void)handleTrackingFetchResponse:(nullable MTTrackingResponse *)response
                               error:(nullable NSError *)error
                              breaks:(NSArray<MTAdBreak *> *)breaks
                              forURL:(NSURL *)requestURL {
    if (self.isDisposed) { return; }
    if (self.autoActivationSuppressed) { return; }
    if (![self.lastAutoActivationURL isEqual:requestURL]) { return; }

    if (error != nil) {
        // Distinct from ManifestFetchFailed — this is the "ads play but
        // nothing tracks" diagnostic. Still merge + start with a nil
        // tracking response so manifest-only ad-break geometry tracks;
        // don't go fully dark just because tracking metadata specifically
        // failed to fetch.
        self.activationStatus = NRMediaTailorTrackingStatusTrackingFetchFailed;
        self.activationStatusMessage = [NSString stringWithFormat:
            @"MediaTailor tracking-API fetch failed (%@). Manifest-only ad-break geometry will still be "
            @"tracked, but ad metadata (creative id, ad system, etc.) will be missing. If ads play but "
            @"nothing tracks, verify your CDN forwards the /v1/tracking/ path — some CDN configs proxy "
            @"/v1/master|manifest|segment/* correctly but omit /v1/tracking/*, since only this SDK ever "
            @"calls it.", error.localizedDescription ?: @"unknown error"];
        [self finishAutoActivationWithBreaks:breaks trackingResponse:nil forURL:requestURL];
        return;
    }

    [self finishAutoActivationWithBreaks:breaks trackingResponse:response forURL:requestURL];
}

- (void)finishAutoActivationWithBreaks:(NSArray<MTAdBreak *> *)breaks
                       trackingResponse:(nullable MTTrackingResponse *)trackingResponse
                                 forURL:(NSURL *)requestURL {
    if (self.isDisposed) { return; }
    if (self.autoActivationSuppressed) { return; }
    if (![self.lastAutoActivationURL isEqual:requestURL]) { return; }

    MergedSchedule *schedule = [MTAdScheduleMerger mergeManifestBreaks:breaks trackingResponse:trackingResponse];
    [self startTrackingWithScheduleImpl:schedule];

    // Leave a TrackingFetchFailed status/message (already set by the caller)
    // in place rather than overwriting it with Active — manifest-only
    // tracking is still "started", but the diagnostic distinction matters.
    if (self.activationStatus != NRMediaTailorTrackingStatusTrackingFetchFailed) {
        self.activationStatus = NRMediaTailorTrackingStatusActive;
        self.activationStatusMessage = nil;
    }
}

#pragma mark - Public lifecycle

/// Thin public wrapper — the double-tracking guard. Sets a sticky
/// `autoActivationSuppressed` and cancels any in-flight auto-activation
/// fetch before deferring to `-startTrackingWithScheduleImpl:` (the
/// original body of this method). See `NRTrackerMediaTailor.h`.
- (void)startTrackingWithSchedule:(MergedSchedule *)schedule {
    if (self.isDisposed) { return; }
    NSParameterAssert(schedule != nil);
    self.autoActivationSuppressed = YES;
    [self stopAccessLogDiscovery];
    [self.manifestFetcher cancel];
    [self.trackingClient cancel];
    [self startTrackingWithScheduleImpl:schedule];
}

- (void)startTrackingWithScheduleImpl:(MergedSchedule *)schedule {
    if (self.isDisposed) { return; }
    NSParameterAssert(schedule != nil);
    [self stopTracking];
    self.stateMachine = [[MTPlayheadStateMachine alloc] initWithSchedule:schedule
                                                    playheadPollInterval:[self resolvedPlayheadPollInterval]];
    self.stateMachine.delegate = self;
    if (self.avPlayer != nil) {
        [self.stateMachine attachToPlayer:self.avPlayer];
    }
}

// `stopTracking` (called from `dispose`) nils `stateMachine`, which drops the
// state machine's own strong self-reference and structurally prevents any
// further `MTPlayheadStateMachineDelegate` callback from firing — so the
// `isDisposed` guard on those six callbacks mainly protects against a callback
// already in flight on the call stack when `dispose` runs. The guard on the
// public entry points (`setPlayer:`, `startTrackingWithSchedule:`,
// `notifyAdSkipped`) is the one that matters for a host still calling in
// after teardown, since nothing else prevents that.
- (void)stopTracking {
    [self.stateMachine detachFromPlayer];
    self.stateMachine = nil;
    self.currentBreak = nil;
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)dispose {
    if (self.isDisposed) { return; }
    self.isDisposed = YES;

    [self.manifestFetcher cancel];
    self.manifestFetcher = nil;

    [self.trackingClient cancel];
    [self.trackingClient resetSession];
    self.trackingClient = nil;

    [self stopTracking];
    [self detachFromCurrentPlayer];

    [super dispose];
}

- (void)notifyAdSkipped {
    if (self.isDisposed) { return; }
    if (self.currentPod == nil) { return; }
    [self sendVideoAdEvent:@"AD_SKIP"];
}

#pragma mark - MTPlayheadStateMachineDelegate

- (void)stateMachine:(MTPlayheadStateMachine *)sm enteredBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentBreak = brk;
    [self sendAdBreakStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
          enteredPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentPod = pod;
    self.currentQuartileNumber = 0;
    [self sendRequest];
    [self sendStart];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
     crossedQuartile:(NSInteger)quartile
               inPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    self.currentQuartileNumber = quartile;
    [self sendAdQuartile];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
           exitedPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    [self sendEnd];
    self.currentPod = nil;
    self.currentQuartileNumber = 0;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm exitedBreak:(MTAdBreak *)brk {
    if (self.isDisposed) { return; }
    [self sendAdBreakEnd];
    self.currentBreak = nil;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
         raisedError:(MTMergedScheduleError *)error {
    if (self.isDisposed) { return; }
    NSString *codeName = NSStringFromMTAdErrorCode(error.errorCode);
    NSDictionary *attrs = @{
        @"errorCode": codeName ?: @"UNKNOWN",
        @"errorMessage": error.message ?: codeName ?: @"",
    };
    [self sendVideoErrorEvent:@"AD_ERROR" attributes:attrs];
}

#pragma mark - NRVideoTracker attribute overrides

- (NSNumber *)getIsAd {
    return @1;
}

- (NSString *)getAdBreakId {
    return self.currentBreak.availId ?: @"";
}

- (NSString *)getAdCreativeId {
    return self.currentPod.creativeId ?: @"";
}

- (NSNumber *)getAdQuartile {
    return @(self.currentQuartileNumber);
}

- (NSString *)getAdPartner {
    return self.currentPod.adSystem ?: @"";
}

- (NSString *)getTrackerName {
    return @"NRMediaTailorTracker";
}

- (NSString *)getTrackerVersion {
    return @"4.2.0";
}

- (NSMutableDictionary *)getAttributes:(NSString *)action
                            attributes:(NSDictionary *)attributes {
    NSMutableDictionary *attrs = [super getAttributes:action attributes:attributes];

    MTAdBreak *brk = self.currentBreak;
    MTAdPod *pod = self.currentPod;

    // Break-level attributes. Always emit programDateTime keys, even
    // when empty, so live-stream consumers can reliably correlate.
    if (brk != nil) {
        attrs[@"availId"]              = brk.availId ?: @"";
        attrs[@"availProgramDateTime"] = brk.availProgramDateTime ?: @"";
        attrs[@"noFill"]               = @(brk.isNoFill);
        attrs[@"podCountMismatch"]     = @(brk.podCountMismatch);
    } else {
        attrs[@"availId"]              = @"";
        attrs[@"availProgramDateTime"] = @"";
    }

    // Pod-level attributes.
    if (pod != nil) {
        attrs[@"adId"]              = pod.adId ?: @"";
        attrs[@"creativeId"]        = pod.creativeId ?: @"";
        attrs[@"adTitle"]           = pod.adTitle ?: @"";
        attrs[@"adSystem"]          = pod.adSystem ?: @"";
        attrs[@"creativeSequence"]  = pod.creativeSequence ?: @"";
        attrs[@"vastAdId"]          = pod.vastAdId ?: @"";
        attrs[@"skipOffset"]        = pod.skipOffset ?: @"";
        attrs[@"adProgramDateTime"] = pod.adProgramDateTime ?: @"";
        attrs[@"isBumper"]          = @(pod.isBumper);
    } else {
        attrs[@"adProgramDateTime"] = @"";
    }

    return attrs;
}

@end
