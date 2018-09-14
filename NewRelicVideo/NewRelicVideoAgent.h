//
//  NewRelicVideoAgent.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ContentsTracker;
@class AdsTracker;

@protocol ContentsTrackerProtocol;
@protocol AdsTrackerProtocol;

/**
 `NewRelicVideoAgent` contains the methods to start the Video Agent and access tracker instances.
 
 @warning Before using it NewRelicAgent must be initialized.
*/

@interface NewRelicVideoAgent : NSObject

/**
 Starts New Relic Video data collection for "player".
 
 @param player The player object.
*/
+ (void)startWithPlayer:(id)player;

/**
 Starts New Relic Video data collection for contents tracker.
 
 @param tracker The contents tracker instance.
 */
+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker;

/**
 Starts New Relic Video data collection for contents tracker and ads tracker.
 
 @param tracker The contents tracker instance.
 @param adsTracker The ads tracker instance.
 */
+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker andAds:(AdsTracker<AdsTrackerProtocol> *)adsTracker;

/**
 Returns the contents tracker instance created with `startWithXXX` methods.
 
 @return The contents tracker instance.
 */
+ (ContentsTracker<ContentsTrackerProtocol> *)trackerInstance;

/**
 Returns the ads tracker instance created with `startWithXXX` methods.
 
 @return The ads tracker instance.
 */
+ (AdsTracker<AdsTrackerProtocol> *)adsTrackerInstance;

@end
