//
//  NRTrackerMediaTailor.h
//  NRMediaTailorTracker
//
//  New Relic Video Agent — AWS MediaTailor ad tracker for AVPlayer.
//

#import <Foundation/Foundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

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

@end

NS_ASSUME_NONNULL_END
