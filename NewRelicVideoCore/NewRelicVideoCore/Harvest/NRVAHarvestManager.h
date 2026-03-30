//
//  NRVAHarvestManager.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAVideoConfiguration;
@protocol NRVAHarvestComponentFactory;


/**
* Crash-safe harvest manager
* - Manages event recording and harvesting.
* - Uses a capacity-based trigger to start the harvest scheduler.
*/
@interface NRVAHarvestManager : NSObject


/**
* Initialize with a video agent configuration.
* @param config The video configuration.
*/
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)config;


/**
* Record an event for harvest.
* @param eventType The event type.
* @param attributes Event attributes.
*/
- (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes;

/**
* Harvest on-demand events with optimized batch sizes from configuration.
*/
- (void)harvestOnDemand;


/**
* Harvest live events with optimized batch sizes from configuration.
*/
- (void)harvestLive;


/**
* Get the underlying component factory.
*/
- (id<NRVAHarvestComponentFactory>)getFactory;


/**
* Get current queue size.
*/
- (NSUInteger)queueSize;


/**
* Get recovery status (if recovering from crash).
*/
- (NSString *)getRecoveryStatus;


@end