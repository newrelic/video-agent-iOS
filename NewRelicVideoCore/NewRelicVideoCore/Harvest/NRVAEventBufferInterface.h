//
//  NRVAEventBufferInterface.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NRVASizeEstimator;

/**
 * Interface for overflow notification callback.
 */
@protocol NRVAOverflowCallback <NSObject>
- (void)onBufferNearFull:(NSString *)bufferType;
@end

/**
 * Interface for capacity monitoring callback.
 */
@protocol NRVACapacityCallback <NSObject>
- (void)onCapacityThresholdReached:(double)currentCapacity bufferType:(NSString *)bufferType;
@end

/**
 * Protocol defining the contract for event buffer implementations.
 * Supports capacity monitoring and overflow handling for optimal performance.
 * This version is aligned with the Android interface.
 */
@protocol NRVAEventBufferInterface <NSObject>

#pragma mark - Required Methods

/**
 * Add an event to the buffer.
 * @param event The event dictionary to add.
 */
- (void)addEvent:(NSDictionary<NSString *, id> *)event;

/**
 * Poll a batch of events based on priority and size constraints.
 * @param maxSizeBytes Maximum size of the batch in bytes.
 * @param sizeEstimator Size estimator for calculating event sizes.
 * @param priority Priority level to filter ("live" or "ondemand").
 * @return Array of events matching the criteria.
 */
- (NSArray<NSDictionary<NSString *, id> *> *)pollBatchByPriority:(NSInteger)maxSizeBytes
                                                    sizeEstimator:(id<NRVASizeEstimator>)sizeEstimator
                                                         priority:(NSString *)priority;

/**
 * Get total number of events in buffer.
 */
- (NSInteger)getEventCount;

/**
 * Check if buffer is empty.
 */
- (BOOL)isEmpty;

/**
 * Clean up resources.
 */
- (void)cleanup;

#pragma mark - Optional Methods

@optional

/**
 * Set overflow callback for buffers that support overflow prevention.
 */
- (void)setOverflowCallback:(id<NRVAOverflowCallback>)callback;

/**
 * Set capacity callback for monitoring buffer fill levels.
 */
- (void)setCapacityCallback:(id<NRVACapacityCallback>)callback;

/**
 * Called after a successful harvest to trigger any pending recovery operations.
 * Only crash-safe implementations need to implement this.
 */
- (void)onSuccessfulHarvest;

@end

NS_ASSUME_NONNULL_END