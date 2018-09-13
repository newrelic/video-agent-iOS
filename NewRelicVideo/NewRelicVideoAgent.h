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

@interface NewRelicVideoAgent : NSObject

/*!
 Starts New Relic Video data collection for "player"
 
 Call this after having initialized the NewRelicAgent.
 */
+ (void)startWithPlayer:(id)player;

/*!
 Starts New Relic Video data collection for contents tracker.
 
 Call this after having initialized the NewRelicAgent.
 */
+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker;

/*!
 Starts New Relic Video data collection for contents tracker and ads tracker.
 
 Call this after having initialized the NewRelicAgent.
 */
+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker andAds:(AdsTracker<AdsTrackerProtocol> *)adsTracker;

/*!
 Return the tracker instance.
 */
+ (ContentsTracker<ContentsTrackerProtocol> *)trackerInstance;

/*!
 Return the ads tracker instance.
 */
+ (AdsTracker<AdsTrackerProtocol> *)adsTrackerInstance;

@end
