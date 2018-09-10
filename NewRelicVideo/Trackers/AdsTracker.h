//
//  AdsTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 10/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

@protocol AdsTrackerProtocol <TrackerProtocol>
@optional
- (NSString *)getAdCreativeId;
- (NSString *)getAdPosition;
- (NSString *)getAdPartner;
@end

@interface AdsTracker : Tracker <TrackerProtocol>

- (void)sendAdBreakStart;
- (void)sendAdBreakEnd;
- (void)sendAdQuartile;
- (void)sendAdClick;

@end
