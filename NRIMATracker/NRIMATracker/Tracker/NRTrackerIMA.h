//
//  NRTrackerIMA.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 02/03/21.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

@class IMAAdEvent;
@class IMAAdsManager;
@class IMAAdError;
@class IMAStreamManager;

/**
 `NRTrackerIMA` is the base class to manage the ad events of the Google IMA library. 
 It can be used directly or subclassed.

 It tracks both client-side ads (`IMAAdsManager`, CSAI) and Dynamic Ad Insertion
 (`IMAStreamManager`, server-side stitched ads, DAI). A tracker created from
 `[NRAdConfig dai]` is in DAI mode and adds the attribute `adStreamType=DAI` to its events.
 */
@interface NRTrackerIMA : NRVideoTracker <NRAdTrackerConfigurable>

/**
 Report an ad event to the tracker.
 
 @param event An IMAAdEvent.
 @param manager An IMAAdsManager.
 */
- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager;

/**
 Report an ad error to the tracker.
 
 @param message Error message.
 @param code Error code.
 */
- (void)adError:(NSString *)message code:(int)code;

/**
 Simple forwarding methods for user-defined listeners
 */

/**
 Forward ad events
 @param event The IMA ad event
 @param adsManager The ads manager (can be nil)
 */
- (void)handleAdEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)adsManager;

/**
 Forward ad errors
 @param error The IMA ad error
 */
- (void)handleAdError:(IMAAdError *)error;

#pragma mark - Dynamic Ad Insertion (IMAStreamManager)

/**
 Report a DAI ad event. Call from `-streamManager:didReceiveAdEvent:`.
 Same ad vocabulary as `adEvent:adsManager:`; additionally maps `AD_BREAK_STARTED`
 and `AD_BREAK_ENDED` to `AD_BREAK_START` / `AD_BREAK_END`.

 @param event An IMAAdEvent.
 @param manager The IMAStreamManager (can be nil).
 */
- (void)streamAdEvent:(IMAAdEvent *)event streamManager:(IMAStreamManager *)manager;

/**
 Forwarding variant of `streamAdEvent:streamManager:` for user-defined delegates.
 */
- (void)handleStreamAdEvent:(IMAAdEvent *)event streamManager:(IMAStreamManager *)manager;

/**
 Report a DAI ad error. Call from `-streamManager:didReceiveAdError:`.
 Keeps domain `com.newrelic.video.IMA` and the IMA error code and message, and
 carries the `IMAAdError` type and code in the NSError userInfo.
 */
- (void)handleStreamAdError:(IMAAdError *)error;

/**
 Report ad playback progress. Call from the optional
 `-streamManager:adDidProgressToTime:adDuration:adPosition:totalAds:adBreakDuration:adPeriodDuration:`.
 DAI has no `IMAAdsManager`, so this is the source of the ad playhead.
 */
- (void)handleStreamAdProgressToTime:(NSTimeInterval)time
                          adDuration:(NSTimeInterval)adDuration
                          adPosition:(NSInteger)adPosition
                            totalAds:(NSInteger)totalAds
                     adBreakDuration:(NSTimeInterval)adBreakDuration;

@end
