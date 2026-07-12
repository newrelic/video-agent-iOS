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

/**
 `NRTrackerMediaTailor` detects AWS MediaTailor server-side-stitched ads
 inside an `AVPlayer` stream and emits New Relic ad telemetry events in
 parity with `NRTrackerIMA`. It can be used directly or subclassed.

 Event vocabulary emitted: `AD_BREAK_START`, `AD_REQUEST`, `AD_START`,
 `AD_QUARTILE`, `AD_END`, `AD_BREAK_END`, `AD_ERROR`, `AD_SKIP`,
 `AD_PAUSE`, `AD_RESUME`.

 ## Lifecycle

 1. Initialize the tracker (typically via `NewRelicVideoAgent`).
 2. Call `-setPlayer:` with your `AVPlayer` instance.
 3. Call `-startTrackingWithSchedule:` with the merged schedule (from
    `MTAdScheduleMerger`).
 4. Call `-dispose` when tearing down — this cancels any in-flight
    tracking-API fetch, detaches the state machine, and clears KVO.
    `-dealloc` calls `-dispose` defensively, so simply releasing the
    tracker is sufficient if the host has no other references.

 This is the public entry point of the `NRMediaTailorTracker` module.
 */
@interface NRTrackerMediaTailor : NRVideoTracker

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
/// `mtOptions.adSegmentPrefix` and Android `segmentPrefix`. (P0-110)
///
/// Threading: main-queue only. Set before `-startTrackingWithSchedule:`.
@property (nonatomic, copy, nullable) NSString *adSegmentPrefix;

/// Explicit tracking-API URL override. When non-nil/non-empty it is used
/// verbatim (see `-resolvedTrackingURLForManifestURL:`); otherwise the URL is
/// derived from the manifest URL via `+[MTDetector deriveTrackingURL:]`. Use
/// this for split-hostname / custom-CDN deployments where the derivation
/// heuristic breaks. Parity with VideoJS `mtOptions.trackingUrl` and Android
/// `NRAdConfig.trackingUrl`. (P0-111)
@property (nonatomic, copy, nullable) NSString *trackingUrl;

/// Playhead poll cadence in milliseconds, driving quartile precision and
/// event latency vs. CPU/battery cost. `0` (default) uses 250 ms. Non-zero
/// values are clamped to `100...5000` ms (a warning is logged on clamp).
/// Plumbed to `MTPlayheadStateMachine` at `-startTrackingWithSchedule:`.
/// Parity with Android `pollIntervalMs`. (P0-112)
@property (nonatomic, assign) NSUInteger pollIntervalMs;

/// Resolve the tracking-API URL for a given manifest URL: returns
/// `trackingUrl` verbatim when set (non-empty), else
/// `+[MTDetector deriveTrackingURL:manifestURL]` (may be nil). (P0-111)
- (nullable NSURL *)resolvedTrackingURLForManifestURL:(nullable NSURL *)manifestURL;

/// YES once `-dispose` has been called. After this, `-setPlayer:`,
/// `-startTrackingWithSchedule:`, and the state-machine delegate callbacks
/// all short-circuit. The tracker is single-use; create a new instance for
/// a new playback session.
@property (nonatomic, assign, readonly) BOOL isDisposed;

/// Attach an `AVPlayer`. Installs the periodic-time observer used by the
/// state machine (via the schedule's poll interval) and registers KVO on
/// `timeControlStatus` to emit `AD_PAUSE` / `AD_RESUME` events while
/// inside an ad break. Re-attaching detaches the previous player first.
///
/// Inherits the `NRVideoTracker.setPlayer:` signature so existing
/// integrations can swap trackers transparently.
- (void)setPlayer:(id)player;

/// Begin tracking against a merged schedule. The tracker installs a
/// `MTPlayheadStateMachine`, subscribes as its delegate, and translates
/// every state transition into the corresponding `NRVideoTracker.sendXxx`
/// call. Call `-stopTracking` or `-dispose` to tear down. If a player has
/// already been set via `-setPlayer:`, the state machine is automatically
/// attached to it.
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
