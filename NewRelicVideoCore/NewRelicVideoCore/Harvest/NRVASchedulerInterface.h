//
//  NRVASchedulerInterface.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for harvest scheduling implementations
 * Includes lifecycle control methods for proper iOS lifecycle management
 */
@protocol NRVASchedulerInterface <NSObject>

/**
 * Start the scheduled harvest tasks
 */
- (void)start;

/**
 * Start a specific harvest task based on buffer type
 * @param bufferType The type of buffer ("live" or "ondemand")
 */
- (void)startWithBufferType:(NSString *)bufferType;

/**
 * Stop and shutdown the scheduled harvest tasks
 * Should perform immediate harvest before shutdown to prevent data loss
 */
- (void)shutdown;

/**
 * Force immediate harvest of all pending events
 * Used for manual triggering or emergency harvesting
 */
- (void)forceHarvest;

/**
 * Check if scheduler is currently running
 */
- (BOOL)isRunning;

/**
 * Pause all scheduled harvests (used during app lifecycle changes)
 */
- (void)pause;

/**
 * Resume scheduled harvests with optional extended intervals
 * @param useExtendedIntervals YES for background/TV behavior, NO for normal intervals
 */
- (void)resume:(BOOL)useExtendedIntervals;

@end

NS_ASSUME_NONNULL_END