//
//  NRVAMultiTaskHarvestScheduler.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVASchedulerInterface.h"

@class NRVAVideoConfiguration;

NS_ASSUME_NONNULL_BEGIN

/**
 * iOS-optimized harvest scheduler using DispatchSourceTimer and GCD.
 * Better for mobile/TV environments - respects iOS lifecycle and power management.
 * Uses NRVAVideoConfiguration for device type detection.
 */
@interface NRVAMultiTaskHarvestScheduler : NSObject <NRVASchedulerInterface>

/**
 * Initialize with harvest tasks and configuration.
 * @param onDemandTask Task for on-demand content harvesting.
 * @param liveTask Task for live content harvesting.
 * @param configuration Video configuration for device-specific settings.
 */
- (instancetype)initWithOnDemandTask:(void(^)(void))onDemandTask
                            liveTask:(void(^)(void))liveTask
                       configuration:(NRVAVideoConfiguration *)configuration;

/**
 * Starts both the on-demand and live schedulers.
 */
- (void)start;

/**
 * Starts a specific scheduler by its buffer type ("live" or "ondemand").
 * @param bufferType The type of scheduler to start.
 */
- (void)startWithBufferType:(NSString *)bufferType;

/**
 * Shuts down the scheduler, performing a final harvest.
 */
- (void)shutdown;

/**
 * Triggers an immediate, synchronous harvest of all buffered events.
 */
- (void)forceHarvest;

/**
 * Checks if the scheduler is currently running.
 * @return YES if either the live or on-demand scheduler is active.
 */
- (BOOL)isRunning;

/**
 * Pauses all timers, halting harvests until resumed.
 */
- (void)pause;

/**
 * Resumes scheduling after being paused.
 * @param useExtendedIntervals If YES and on a TV device, timers will resume with a longer interval.
 */
- (void)resume:(BOOL)useExtendedIntervals;

@end

NS_ASSUME_NONNULL_END