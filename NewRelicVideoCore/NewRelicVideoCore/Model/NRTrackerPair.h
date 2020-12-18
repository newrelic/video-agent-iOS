//
//  NRTrackerPair.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NRTracker;

/**
 Tracker pair model.
 */
@interface NRTrackerPair : NSObject

/**
 Init a NSTrackerPair with two trackers.
 
 @param first First tracker.
 @param second Second tracker.
 @return Tracker pair instance.
 */
- (instancetype)initWithFirst:(nullable NRTracker *)first second:(nullable NRTracker *)second;

/**
 Get first tracker.
 
 @return First tracker.
 */
- (NRTracker *)first;

/**
 Get second tracker.
 
 @return Second tracker.
 */
- (NRTracker *)second;

@end

NS_ASSUME_NONNULL_END
