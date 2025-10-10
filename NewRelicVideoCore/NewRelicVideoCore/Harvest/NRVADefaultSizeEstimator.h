//
//  NRVADefaultSizeEstimator.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVASizeEstimator.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of size estimation for video events
 * Optimized for mobile/TV performance with device-specific estimates
 */
@interface NRVADefaultSizeEstimator : NSObject <NRVASizeEstimator>

@end

NS_ASSUME_NONNULL_END