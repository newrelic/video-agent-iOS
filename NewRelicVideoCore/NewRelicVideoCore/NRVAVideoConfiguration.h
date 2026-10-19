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
 * Minimum severity of the agent's buffer-capacity logs (INFO at 85% fill, WARNING at 90%,
 * ERROR when events are dropped). A message is logged when its severity is at or above the level.
 */
typedef NS_ENUM(NSInteger, NRVALoggingLevel) {
    NRVALoggingLevelInfo = 0,
    NRVALoggingLevelWarning = 1,
    NRVALoggingLevelError = 2
};

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
@property (nonatomic, readonly) BOOL loggingEnabled;
@property (nonatomic, readonly) NRVALoggingLevel loggingLevel;
@property (nonatomic, readonly) BOOL isTV;
@property (nonatomic, readonly) NSString *collectorAddress;
@property (nonatomic, readonly) BOOL qoeAggregateEnabled;
@property (nonatomic, readonly) NSInteger qoeAggregateIntervalMultiplier;

/**
 * Obfuscation rules applied to string attribute values before events are transmitted.
 * Each rule is an NSDictionary with @"regex" (NSString) and @"replacement" (NSString) keys.
 * Rules are applied in order; all rules run against every outgoing event's string attributes.
 * Example: @{ @"regex": @"account-\\d+", @"replacement": @"ACCOUNT_ID" }
 */
@property (nonatomic, readonly, nullable) NSArray<NSDictionary *> *obfuscationRules;

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
@property (nonatomic, assign) BOOL loggingEnabled;
@property (nonatomic, assign) NRVALoggingLevel loggingLevel;
@property (nonatomic, assign) BOOL isTV;
@property (nonatomic, strong) NSString *collectorAddress;
@property (nonatomic, assign) BOOL qoeAggregateEnabled;
@property (nonatomic, assign) NSInteger qoeAggregateIntervalMultiplier;
@property (nonatomic, strong, nullable) NSArray<NSDictionary *> *obfuscationRules;

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
 * Enable buffer-capacity logging through os_log, including in release builds (default: NO).
 * Reports the event buffer nearing capacity and events dropped when it overflows.
 */
- (instancetype)withLoggingEnabled:(BOOL)loggingEnabled;

/**
 * Set the minimum level of buffer-capacity logs (default: NRVALoggingLevelInfo).
 * Only applies when logging is enabled with withLoggingEnabled:.
 */
- (instancetype)withLoggingLevel:(NRVALoggingLevel)loggingLevel;

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
 * Enable QoE aggregate event reporting (default: NO)
 */
- (instancetype)withQoeAggregateEnabled:(BOOL)enabled;

/**
 * Set QoE aggregate interval multiplier (>= 1, default: 1)
 * QoE aggregate is sent every N harvest cycles, where N is the multiplier.
 */
- (instancetype)withQoeAggregateIntervalMultiplier:(NSInteger)multiplier;

/**
 * Set obfuscation rules to mask sensitive data in event attribute values before transmission.
 * Rules are applied in order to every string attribute value in outgoing events.
 * Invalid regex patterns are skipped with a warning; other rules continue to apply.
 * Example:
 *   @[ @{ @"regex": @"account-\\d+", @"replacement": @"ACCOUNT_ID" },
 *      @{ @"regex": @"token=[^&\"]+", @"replacement": @"token=REDACTED" } ]
 */
- (instancetype)withObfuscationRules:(NSArray<NSDictionary *> *)rules;

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
