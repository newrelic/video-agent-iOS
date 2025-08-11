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

/**
 `NRTrackerIMA` is the base class to manage the ad events of the Google IMA library. 
 It can be used directly or subclassed.
 */
@interface NRTrackerIMA : NRVideoTracker

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
 ANDROID PARITY: Simple forwarding methods for user-defined listeners
 These match Android's handleAdEvent/handleAdError exactly
 */

/**
 Forward ad events - matches Android's handleAdEvent  
 @param event The IMA ad event
 @param adsManager The ads manager (can be nil)
 */
- (void)handleAdEvent:(IMAAdEvent *)event adsManager:(IMAAdsManager *)adsManager;

/**
 Forward ad errors - matches Android's handleAdError
 @param error The IMA ad error
 */
- (void)handleAdError:(IMAAdError *)error;

@end
