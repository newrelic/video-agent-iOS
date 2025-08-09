//
//  NRVAHarvestManager.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAVideoConfiguration;
@class NRVAConnection;
@class NRVAOfflineStorage;
@class NRVATokenManager;

/**
 * Manages event harvesting, batching, and transmission
 * Thread-safe singleton with automatic retry and offline storage
 */
@interface NRVAHarvestManager : NSObject

/**
 * Initialize with configuration
 * @param config Video configuration with harvest settings
 */
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)config;

/**
 * Record an event for harvest
 * @param eventType The event type
 * @param attributes Event attributes
 */
- (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes;

/**
 * Start the harvest cycle
 */
- (void)startHarvesting;

/**
 * Stop the harvest cycle
 */
- (void)stopHarvesting;

/**
 * Force immediate harvest (for testing or critical events)
 */
- (void)forceHarvest;

/**
 * Get current queue size
 */
- (NSUInteger)queueSize;

@end
