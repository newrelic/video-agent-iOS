//
//  NRVASizeEstimator.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for estimating the size of events in bytes
 * Used for batch size calculations in event buffering
 */
@protocol NRVASizeEstimator <NSObject>

/**
 * Estimate the size of an event in bytes
 * @param event The event dictionary to estimate
 * @return Estimated size in bytes
 */
- (NSInteger)estimate:(NSDictionary<NSString *, id> *)event;

@end

NS_ASSUME_NONNULL_END