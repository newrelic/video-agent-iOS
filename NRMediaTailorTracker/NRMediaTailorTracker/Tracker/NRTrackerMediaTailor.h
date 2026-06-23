//
//  NRTrackerMediaTailor.h
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//

#import <Foundation/Foundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

@protocol MTManifestParser;

NS_ASSUME_NONNULL_BEGIN

/**
 `NRTrackerMediaTailor` detects AWS MediaTailor server-side-stitched ads
 inside an `AVPlayer` stream and emits New Relic ad telemetry events in
 parity with `NRTrackerIMA`. It can be used directly or subclassed.

 This is the public entry point of the `NRMediaTailorTracker` module.
 Full tracker behavior lands across tasks T02–T09; this scaffold compiles
 as a stub.
 */
@interface NRTrackerMediaTailor : NRVideoTracker

/// Inject a custom manifest parser. Defaults to `MTHlsParser` when unset
/// (set lazily by the tracker before its first parse). Use this seam to plug
/// in a DASH adapter for streams played by a third-party DASH player such as
/// THEOplayer, Bitmovin, or Shaka — see `MTManifestParser.h` and
/// `MTDashParser.h`.
///
/// Threading: setter is main-queue only. Implementations of
/// `-parseManifest:baseURL:` may be invoked on a background queue, so the
/// parser must be safe to call from non-main queues.
- (void)setManifestParser:(id<MTManifestParser>)parser;

@end

NS_ASSUME_NONNULL_END
