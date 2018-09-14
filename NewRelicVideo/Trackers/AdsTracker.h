//
//  AdsTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

@class ContentsTracker;

/**
 `AdsTrackerProtocol` defines the getters every `AdsTracker` must or should implement.
 */
@protocol AdsTrackerProtocol <TrackerProtocol>

@optional

/**
 Get Ad creative ID.
 */
- (NSString *)getAdCreativeId;

/**
 Get Ad position, pre, mid or post.
 */
- (NSString *)getAdPosition;

/**
 Get ad partner name.
 */
- (NSString *)getAdPartner;

@end

/**
 `AdsTracker` is the base class to manage the ads events of a player.
 
 @warning Should never be instantiated directly, but subclassed.
 */

@interface AdsTracker : Tracker <TrackerProtocol>

/**
 Create a `AdsTracker` instance using a `ContentsTracker`, necessary for some Ads related events and attributes.
 
 @param tracker The `ContentsTracker` instance linked to the same player.
 */
- (instancetype)initWithContentsTracker:(ContentsTracker *)tracker;

/**
 Send a `AD_BREAK_START` action.
 */
- (void)sendAdBreakStart;

/**
 Send a `AD_BREAK_END` action.
 */
- (void)sendAdBreakEnd;

/**
 Send a `AD_QUARTILE` action.
 */
- (void)sendAdQuartile;

/**
 Send a `AD_CLICK` action.
 */
- (void)sendAdClick;

@end
