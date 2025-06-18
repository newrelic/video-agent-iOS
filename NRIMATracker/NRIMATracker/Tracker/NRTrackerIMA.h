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
@class IMAStreamManager;

/**
 `NRTrackerIMA` is the base class to manage the ad events of the Google IMA library. It can be used directly or subclassed.
 */
@interface NRTrackerIMA : NRVideoTracker

/**
 Report an ad event to the tracker.
 
 @param event An IMAAdEvent.
 @param manager An IMAAdsManager.
 */
- (void)adEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)manager;
- (void)streamAdEvent:(IMAAdEvent *)event streamManager:(IMAStreamManager *)manager;

/**
 Report an ad error to the tracker.
 
 @param message Error message.
 @param code Error code.
 */
- (void)adError:(NSString *)message code:(int)code;

@end
