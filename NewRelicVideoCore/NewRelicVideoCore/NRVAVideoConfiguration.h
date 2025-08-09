//
//  NRVAVideoConfiguration.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAVideoConfigurationBuilder;

/**
 * Thread-safe, immutable configuration with iOS & tvOS optimizations
 */
@interface NRVAVideoConfiguration : NSObject

@property (nonatomic, readonly) NSString *applicationToken;
@property (nonatomic, readonly) NSString *region;
@property (nonatomic, readonly) NSInteger harvestCycleSeconds;
@property (nonatomic, readonly) NSInteger liveHarvestCycleSeconds;
@property (nonatomic, readonly) NSInteger regularBatchSizeBytes;
@property (nonatomic, readonly) NSInteger liveBatchSizeBytes;
@property (nonatomic, readonly) NSInteger maxDeadLetterSize;
@property (nonatomic, readonly) BOOL memoryOptimized;
@property (nonatomic, readonly) BOOL debugLoggingEnabled;
@property (nonatomic, readonly) BOOL isTV;

/**
 * Get dead letter retry interval in milliseconds
 * Optimized for different device types and network conditions
 */
@property (nonatomic, readonly) NSTimeInterval deadLetterRetryInterval;

/**
 * Builder pattern for thread-safe configuration creation
 */
+ (NRVAVideoConfigurationBuilder *)builder;

/**
 * Initialize configuration with builder
 */
- (instancetype)initWithBuilder:(NRVAVideoConfigurationBuilder *)builder;

@end

/**
 * Builder class for NRVAVideoConfiguration
 */
@interface NRVAVideoConfigurationBuilder : NSObject

@property (nonatomic, strong) NSString *applicationToken;
@property (nonatomic, assign) NSInteger harvestCycleSeconds;
@property (nonatomic, assign) NSInteger liveHarvestCycleSeconds;
@property (nonatomic, assign) NSInteger regularBatchSizeBytes;
@property (nonatomic, assign) NSInteger liveBatchSizeBytes;
@property (nonatomic, assign) NSInteger maxDeadLetterSize;
@property (nonatomic, assign) BOOL memoryOptimized;
@property (nonatomic, assign) BOOL debugLoggingEnabled;
@property (nonatomic, assign) BOOL isTV;

/**
 * Set application token (required)
 */
- (instancetype)withApplicationToken:(NSString *)applicationToken;

/**
 * Configure TV-specific optimizations
 */
- (instancetype)forTVOS:(BOOL)isTV;

/**
 * Enable memory optimization for lower-end devices
 */
- (instancetype)withMemoryOptimization:(BOOL)memoryOptimized;

/**
 * Enable debug logging
 */
- (instancetype)withDebugLogging:(BOOL)debugLoggingEnabled;

/**
 * Set harvest cycle in seconds (optional, defaults applied automatically)
 */
- (instancetype)withHarvestCycle:(NSInteger)harvestCycleSeconds;

/**
 * Set live harvest cycle in seconds (optional, defaults applied automatically)
 */
- (instancetype)withLiveHarvestCycle:(NSInteger)liveHarvestCycleSeconds;

/**
 * Set batch size for regular content (optional, defaults applied automatically)
 */
- (instancetype)withRegularBatchSize:(NSInteger)regularBatchSizeBytes;

/**
 * Set batch size for live content (optional, defaults applied automatically)
 */
- (instancetype)withLiveBatchSize:(NSInteger)liveBatchSizeBytes;

/**
 * Set maximum dead letter queue size (optional, defaults applied automatically)
 */
- (instancetype)withMaxDeadLetterSize:(NSInteger)maxDeadLetterSize;

/**
 * Build the configuration
 */
- (NRVAVideoConfiguration *)build;

@end
