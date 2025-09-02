//
//  NRVACrashSafeHarvestFactory.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAHarvestComponentFactory.h"

@class NRVAVideoConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * Clean integration factory for crash-safe storage
 * Drop-in replacement that adds crash safety with zero performance impact
 */
@interface NRVACrashSafeHarvestFactory : NSObject <NRVAHarvestComponentFactory>

/**
 * Initialize with configuration and callback blocks
 * @param configuration Video configuration
 * @param overflowCallback Callback for overflow events
 * @param capacityCallback Callback for capacity threshold
 * @param onDemandTask On-demand harvest task
 * @param liveTask Live harvest task
 */
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration
                      overflowCallback:(void(^)(NSString *bufferType))overflowCallback
                      capacityCallback:(void(^)(double capacity, NSString *bufferType))capacityCallback
                         onDemandTask:(void(^)(void))onDemandTask
                             liveTask:(void(^)(void))liveTask;

@end

NS_ASSUME_NONNULL_END