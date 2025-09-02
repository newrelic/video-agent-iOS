//
//  NRVAVideoLifecycleObserver.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NRVAHarvestComponentFactory;

NS_ASSUME_NONNULL_BEGIN

/**
 * Simplified iOS lifecycle observer optimized for video observability
 * Focuses on core responsibilities:
 * - App background/foreground detection
 * - Immediate harvest on background (regardless of harvest cycle)
 * - Crash detection and emergency storage
 * - Device-specific optimizations (Mobile vs TV)
 */
@interface NRVAVideoLifecycleObserver : NSObject

/**
 * Initialize with crash-safe factory for emergency operations
 * @param crashSafeFactory Factory for harvest components
 */
- (instancetype)initWithCrashSafeFactory:(id<NRVAHarvestComponentFactory>)crashSafeFactory;

/**
 * Start observing lifecycle events
 */
- (void)startObserving;

/**
 * Stop observing lifecycle events
 */
- (void)stopObserving;

@end

NS_ASSUME_NONNULL_END