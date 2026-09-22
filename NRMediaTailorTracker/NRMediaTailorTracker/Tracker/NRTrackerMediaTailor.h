//
//  NRTrackerMediaTailor.h
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

@protocol MTManifestParser;
@class MergedSchedule;

NS_ASSUME_NONNULL_BEGIN

/// Progress of the auto-activation flow triggered from `-setPlayer:` (see
/// `NRTrackerMediaTailor`'s "Auto-activation" docs). Starts at `Idle` and
/// only ever moves forward for a given player attachment — there is no
/// transition back to `Idle` short of a fresh `-setPlayer:` with a new URL.
typedef NS_ENUM(NSInteger, NRMediaTailorTrackingStatus) {
    /// No MediaTailor URL has been observed yet.
    NRMediaTailorTrackingStatusIdle = 0,
    /// A direct/implicit entry URL was detected (no session id present in
    /// the URL itself). Waiting for AVPlayer's own playback to reveal the
    /// real, resolved session via its access log — the tracker deliberately
    /// does not fetch this URL itself, since doing so would mint a second,
    /// independent MediaTailor session distinct from the one AVPlayer is
    /// about to create when it fetches the same URL to actually play it.
    /// See "Auto-activation" below.
    NRMediaTailorTrackingStatusAwaitingSessionDiscovery,
    /// A MediaTailor URL was detected; fetching its manifest.
    NRMediaTailorTrackingStatusFetchingManifest,
    /// Manifest fetched and parsed; resolving and fetching tracking data.
    NRMediaTailorTrackingStatusFetchingTracking,
    /// Auto-activation completed; the tracker is tracking a merged schedule.
    NRMediaTailorTrackingStatusActive,
    /// The observed `currentItem` URL was not a MediaTailor URL. Clean
    /// no-op — not an error.
    NRMediaTailorTrackingStatusSkippedNotMediaTailor,
    /// The manifest GET failed (network / timeout / non-2xx). No breaks
    /// were ever detected, so nothing is tracked for this player attachment.
    NRMediaTailorTrackingStatusManifestFetchFailed,
    /// Manifest fetch succeeded, but the tracking-API fetch specifically
    /// failed. Distinct from `ManifestFetchFailed`: this is the "ads play
    /// but nothing tracks" diagnostic — manifest-only ad-break geometry is
    /// still merged and tracked (see `activationStatusMessage`), just
    /// without tracking-API ad metadata.
    NRMediaTailorTrackingStatusTrackingFetchFailed,
};

/**
 `NRTrackerMediaTailor` detects AWS MediaTailor server-side-stitched ads
 inside an `AVPlayer` stream and emits New Relic ad telemetry events in
 parity with `NRTrackerIMA`. It can be used directly or subclassed.

 Event vocabulary emitted: `AD_BREAK_START`, `AD_REQUEST`, `AD_START`,
 `AD_QUARTILE`, `AD_END`, `AD_BREAK_END`, `AD_ERROR`, `AD_SKIP`,
 `AD_PAUSE`, `AD_RESUME`.

 ## Lifecycle

 1. Initialize the tracker (typically via `NewRelicVideoAgent`).
 2. Call `-setPlayer:` with your `AVPlayer` instance. That's it — see
    "Auto-activation" below; no further calls are required for full ad
    tracking against a MediaTailor stream.
 3. Call `-dispose` when tearing down — this cancels any in-flight
    manifest / tracking-API fetch, detaches the state machine, and clears
    KVO. `-dealloc` calls `-dispose` defensively, so simply releasing the
    tracker is sufficient if the host has no other references.

 ## Auto-activation

 `-setPlayer:` installs a KVO observer on the player's `currentItem`. When
 the item's `AVURLAsset` URL looks like a MediaTailor stream
 (`+[MTDetector isMediaTailorURL:]`), the tracker fetches the manifest,
 parses it, resolves and fetches the companion tracking data, merges the
 two, and starts tracking — automatically, with zero further calls. Progress
 is observable via `activationStatus` / `activationStatusMessage`. A
 non-MediaTailor URL is a clean no-op (`NRMediaTailorTrackingStatusSkippedNotMediaTailor`).

 **Direct/implicit entry URLs are handled differently, deliberately.** A
 bare entry URL (`/v1/master/{account}/{config}/master.m3u8`, no query) has
 no session id anywhere in it — MediaTailor mints a fresh session on every
 independent `GET`. If the tracker fetched that URL itself to resolve a
 session, it would mint a session distinct from the one AVPlayer's own
 native HLS engine mints when *it* fetches the same URL to actually play the
 stream — the tracker would then track a schedule for a session nothing is
 playing. Instead, for this shape only, the tracker waits for AVPlayer's own
 `AVPlayerItemAccessLog` (`AVPlayerItemNewAccessLogEntryNotification`) to
 reveal a request AVPlayer actually made — a resolved sub-manifest or
 segment URL, which does carry a session id — and resolves everything from
 that URL instead. This costs nothing extra on the network (AVPlayer was
 always going to make that request), but it does mean activation for this
 flow can't begin until playback has made real progress; an ad break
 starting at the very first instant of the stream may be tracked a beat
 late, or missed, if it resolves before the first access-log entry lands.
 The explicit session-init flow (a resolved URL already carrying
 `?aws.sessionId=...`) has no such delay — fetching a URL that already
 carries a session id doesn't mint a new one, so it's fetched directly, as
 before.

 Calling `-startTrackingWithSchedule:` explicitly (e.g. because the host
 already fetched and merged a schedule itself) always takes precedence: it
 cancels any in-flight auto-activation fetch and permanently suppresses
 auto-activation for the remainder of this tracker instance's lifetime —
 consistent with the class being single-use per playback session.

 This is the public entry point of the `NRMediaTailorTracker` module.
 */
@interface NRTrackerMediaTailor : NRVideoTracker <NRAdTrackerConfigurable>

/// The active manifest parser. Defaults lazily to a shared `MTHlsParser`
/// instance when `-setManifestParser:` has never been called. Set this to
/// plug in a DASH adapter for streams played by a third-party DASH player
/// such as THEOplayer, Bitmovin, or Shaka — see `MTManifestParser.h` and
/// `MTDashParser.h`.
///
/// Threading: setter is main-queue only. Implementations of
/// `-parseManifest:baseURL:` may be invoked on a background queue, so the
/// parser must be safe to call from non-main queues.
@property (nonatomic, strong) id<MTManifestParser> manifestParser;

/// Custom ad-segment URL marker for CDNs that don't use the default AWS
/// MediaTailor paths (`segments.mediatailor`, `/v1/hlssegment/`,
/// `/v1/dashsegment/`, `/tm/`). When non-nil/non-empty, it is appended to the
/// default marker list used during HLS manifest parsing so matching segments
/// are classified as ads. Nil/empty → default behavior. Parity with VideoJS
/// `mtOptions.adSegmentPrefix` and Android `segmentPrefix`.
///
/// Threading: main-queue only. Set before `-startTrackingWithSchedule:`.
@property (nonatomic, copy, nullable) NSString *adSegmentPrefix;

/// Explicit tracking-API URL override. When non-nil/non-empty it is used
/// verbatim (see `-resolvedTrackingURLForManifestURL:`); otherwise the URL is
/// derived from the manifest URL via `+[MTDetector deriveTrackingURL:]`. Use
/// this for split-hostname / custom-CDN deployments where the derivation
/// heuristic breaks. Parity with VideoJS `mtOptions.trackingUrl` and Android
/// `NRAdConfig.trackingUrl`.
@property (nonatomic, copy, nullable) NSString *trackingUrl;

/// Playhead poll cadence in milliseconds, driving quartile precision and
/// event latency vs. CPU/battery cost. `0` (default) uses 250 ms. Non-zero
/// values are clamped to `100...5000` ms (a warning is logged on clamp).
/// Plumbed to `MTPlayheadStateMachine` at `-startTrackingWithSchedule:`.
/// Parity with Android `pollIntervalMs`.
@property (nonatomic, assign) NSUInteger pollIntervalMs;

/// Resolve the tracking-API URL for a given manifest URL: returns
/// `trackingUrl` verbatim when set (non-empty), else
/// `+[MTDetector deriveTrackingURL:manifestURL]` (may be nil).
- (nullable NSURL *)resolvedTrackingURLForManifestURL:(nullable NSURL *)manifestURL;

/// YES once `-dispose` has been called. After this, `-setPlayer:`,
/// `-startTrackingWithSchedule:`, and the state-machine delegate callbacks
/// all short-circuit. The tracker is single-use; create a new instance for
/// a new playback session.
@property (nonatomic, assign, readonly) BOOL isDisposed;

/// Progress of the `-setPlayer:`-triggered auto-activation flow. See
/// `NRMediaTailorTrackingStatus` and the class's "Auto-activation" docs.
/// KVO-observable like any other property; there is no delegate/notification
/// convention elsewhere in this SDK, so this plain property matches
/// `isDisposed`'s existing idiom.
@property (nonatomic, assign, readonly) NRMediaTailorTrackingStatus activationStatus;

/// A human-readable, actionable explanation of the current
/// `activationStatus`. Populated for the two failure statuses
/// (`ManifestFetchFailed` / `TrackingFetchFailed`); nil otherwise.
@property (nonatomic, copy, readonly, nullable) NSString *activationStatusMessage;

/// Attach an `AVPlayer`. Installs the periodic-time observer used by the
/// state machine (via the schedule's poll interval) and registers KVO on
/// `timeControlStatus` to emit `AD_PAUSE` / `AD_RESUME` events while
/// inside an ad break. Also registers KVO on `currentItem` to drive
/// auto-activation (see "Auto-activation" above). Re-attaching detaches the
/// previous player first.
///
/// Inherits the `NRVideoTracker.setPlayer:` signature so existing
/// integrations can swap trackers transparently.
- (void)setPlayer:(id)player;

/// Begin tracking against a merged schedule, overriding auto-activation.
/// The tracker installs a `MTPlayheadStateMachine`, subscribes as its
/// delegate, and translates every state transition into the corresponding
/// `NRVideoTracker.sendXxx` call. Call `-stopTracking` or `-dispose` to tear
/// down. If a player has already been set via `-setPlayer:`, the state
/// machine is automatically attached to it.
///
/// Calling this cancels any in-flight auto-activation manifest / tracking
/// fetch and permanently suppresses auto-activation for the rest of this
/// tracker instance's lifetime — a manual call always wins, whether it
/// happens before, during, or after an auto-activation fetch. Most
/// integrations never need to call this: `-setPlayer:` alone is sufficient
/// for a MediaTailor stream (see "Auto-activation" above). Call it directly
/// only when the host app has already resolved its own schedule.
- (void)startTrackingWithSchedule:(MergedSchedule *)schedule;

/// Tear down the state machine and clear tracking state. Idempotent.
/// Leaves the player attachment and KVO in place; use `-dispose` for full
/// teardown.
- (void)stopTracking;

/// App-invoked: the user dismissed an ad via a UI control. Fires `AD_SKIP`
/// against the current ad's attributes. No-op if not currently in a pod.
- (void)notifyAdSkipped;

@end

NS_ASSUME_NONNULL_END
