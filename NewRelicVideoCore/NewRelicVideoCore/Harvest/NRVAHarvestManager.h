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

/**
 * Block that returns a fully-formed QoE event dict (with eventType, actionName, timestamp).
 * Called by the harvest manager on qualifying harvest cycles when QoE attributes have changed.
 * Set by the tracker at content start, cleared automatically after the final QoE is collected.
 */
@property (nonatomic, copy, nullable) NSDictionary * (^qoeEventProvider)(void);

/**
 * Enqueue a pre-built final QoE event for delivery on the next harvest.
 * The event is built eagerly at sendEnd time (while tracker state is still valid)
 * and dispatched to the harvestQueue for safe, race-free pickup.
 * Takes priority over the regular qoeEventProvider and auto-clears the provider.
 * @param event Fully-formed QoE event dict (eventType, actionName, timestamp already set).
 */
- (void)enqueueFinalQoeEvent:(NSDictionary *)event;

@end