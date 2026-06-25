//
//  NRTrackerMediaTailor.h
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//

#import <Foundation/Foundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

@protocol MTManifestParser;
@class MergedSchedule;

NS_ASSUME_NONNULL_BEGIN

/**
 `NRTrackerMediaTailor` detects AWS MediaTailor server-side-stitched ads
 inside an `AVPlayer` stream and emits New Relic ad telemetry events in
 parity with `NRTrackerIMA`. It can be used directly or subclassed.

 Event vocabulary emitted: `AD_BREAK_START`, `AD_REQUEST`, `AD_START`,
 `AD_QUARTILE`, `AD_END`, `AD_BREAK_END`, `AD_ERROR`, `AD_SKIP`.

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

/// Begin tracking against a merged schedule. The tracker installs a
/// `MTPlayheadStateMachine`, subscribes as its delegate, and translates
/// every state transition into the corresponding `NRVideoTracker.sendXxx`
/// call. Call `-stopTracking` to tear down. T09 will wire `-setPlayer:`
/// to attach the state machine to an `AVPlayer`; until then, tests can
/// drive the machine directly via the internal property.
- (void)startTrackingWithSchedule:(MergedSchedule *)schedule;

/// Tear down the state machine and clear tracking state. Idempotent.
- (void)stopTracking;

/// App-invoked: the user dismissed an ad via a UI control. Fires `AD_SKIP`
/// against the current ad's attributes. No-op if not currently in a pod.
- (void)notifyAdSkipped;

@end

NS_ASSUME_NONNULL_END
