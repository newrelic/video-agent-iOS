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
@property (nonatomic, readonly) NSInteger maxOfflineStorageSizeMB;
@property (nonatomic, readonly) BOOL memoryOptimized;
@property (nonatomic, readonly) BOOL debugLoggingEnabled;
@property (nonatomic, readonly) BOOL isTV;
@property (nonatomic, readonly) NSString *collectorAddress;

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
@property (nonatomic, assign) NSInteger maxOfflineStorageSizeMB;
@property (nonatomic, assign) BOOL memoryOptimized;
@property (nonatomic, assign) BOOL debugLoggingEnabled;
@property (nonatomic, assign) BOOL isTV;
@property (nonatomic, strong) NSString *collectorAddress;

/**
 * Auto-detect platform capabilities and apply optimizations
 * DEPRECATED: Auto-detection now happens automatically during initialization
 * This method is kept for backward compatibility but is no longer required
 */
- (instancetype)autoDetectPlatform __attribute__((deprecated("Auto-detection now happens automatically. This method is no longer needed.")));

/**
 * Set application token (required)
 */
- (instancetype)withApplicationToken:(NSString *)applicationToken;

/**
 * Configure TV-specific optimizations (overrides auto-detection)
 */
- (instancetype)forTVOS:(BOOL)isTV;

/**
 * Enable memory optimization for lower-end devices (overrides auto-detection)
 */
- (instancetype)withMemoryOptimization:(BOOL)memoryOptimized;

/**
 * Enable debug logging
 */
- (instancetype)withDebugLogging:(BOOL)debugLoggingEnabled;

/**
 * Set harvest cycle in seconds (5-300 seconds, validated)
 */
- (instancetype)withHarvestCycle:(NSInteger)harvestCycleSeconds;

/**
 * Set live harvest cycle in seconds (1-60 seconds, validated)
 */
- (instancetype)withLiveHarvestCycle:(NSInteger)liveHarvestCycleSeconds;

/**
 * Set batch size for regular content (1KB-1MB, validated)
 */
- (instancetype)withRegularBatchSize:(NSInteger)regularBatchSizeBytes;

/**
 * Set batch size for live content (512B-512KB, validated)
 */
- (instancetype)withLiveBatchSize:(NSInteger)liveBatchSizeBytes;

/**
 * Set maximum dead letter queue size (10-1000, validated)
 */
- (instancetype)withMaxDeadLetterSize:(NSInteger)maxDeadLetterSize;

/**
 * Set maximum offline storage size in MB (> 0 MB)
 */
- (instancetype)withMaxOfflineStorageSize:(NSInteger)maxOfflineStorageSizeMB;

/**
 * Set custom collector domain address for /connect and /data endpoints (optional)
 * Example: @"staging-mobile-collector.newrelic.com" or @"mobile-collector.newrelic.com"
 * If not set, will be auto-detected from application token region
 */
- (instancetype)withCollectorAddress:(NSString *)collectorAddress;

/**
 * Build the configuration
 */
- (NRVAVideoConfiguration *)build;

@end
