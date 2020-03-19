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
@protocol TrackerBuilder;

/**
 `NewRelicVideoAgent` contains the methods to start the Video Agent and access tracker instances.
 
 @warning Before using it NewRelicAgent must be initialized.
*/
@interface NewRelicVideoAgent : NSObject

/**
 Starts New Relic Video data collection for "player" using a specific tracker builder.
 
 @param player The player object.
 @param trackerBuilderClass The tracker builder class.
 @return Tracker ID.
 */
+ (NSNumber *)startWithPlayer:(id)player usingBuilder:(Class<TrackerBuilder>)trackerBuilderClass;

/**
 Starts New Relic Video data collection for contents tracker.
 
 @param tracker The contents tracker instance.
 @return Tracker ID.
 */
+ (NSNumber *)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker;

/**
 Starts New Relic Video data collection for contents tracker and ads tracker.
 
 @param tracker The contents tracker instance.
 @param adsTracker The ads tracker instance.
 @return Tracker ID.
 */
+ (NSNumber *)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker andAds:(AdsTracker<AdsTrackerProtocol> *)adsTracker;

/**
 Returns the contents tracker instance created with `startWithXXX` methods.
 
 @param trackerId The contents tracker ID.
 @return The contents tracker instance.
 */
+ (ContentsTracker<ContentsTrackerProtocol> *)getContentsTracker:(NSNumber *)trackerId;

/**
 Returns the ads tracker instance created with `startWithXXX` methods.
 
 @param trackerId The ads tracker ID.
 @return The ads tracker instance.
 */
+ (AdsTracker<AdsTrackerProtocol> *)getAdsTracker:(NSNumber *)trackerId;

@end
