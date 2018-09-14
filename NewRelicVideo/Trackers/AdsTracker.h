//
//  AdsTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

@class ContentsTracker;

@protocol AdsTrackerProtocol <TrackerProtocol>
@optional
- (NSString *)getAdCreativeId;
- (NSString *)getAdPosition;
- (NSString *)getAdPartner;
@end

/**
 `AdsTracker` is the base class to manage the ads events of a player.
 
 @warning Should never be instantiated directly, but subclassed.
 */

@interface AdsTracker : Tracker <TrackerProtocol>

- (instancetype)initWithContentsTracker:(ContentsTracker *)tracker;

- (void)sendAdBreakStart;
- (void)sendAdBreakEnd;
- (void)sendAdQuartile;
- (void)sendAdClick;

@end
