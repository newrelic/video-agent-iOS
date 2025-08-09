//
//  NRVAVideoConfiguration.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoConfiguration.h"
#import "NRVAUtils.h"

// Performance optimization constants
static const NSInteger kDefaultHarvestCycleSeconds = 5 * 60; // 5 minutes
static const NSInteger kDefaultLiveHarvestCycleSeconds = 30; // 30 seconds
static const NSInteger kDefaultRegularBatchSizeBytes = 64 * 1024; // 64KB
static const NSInteger kDefaultLiveBatchSizeBytes = 32 * 1024; // 32KB
static const NSInteger kDefaultMaxDeadLetterSize = 100;

// TV-specific optimizations
static const NSInteger kTVHarvestCycleSeconds = 3 * 60; // 3 minutes
static const NSInteger kTVLiveHarvestCycleSeconds = 10; // 10 seconds
static const NSInteger kTVRegularBatchSizeBytes = 128 * 1024; // 128KB
static const NSInteger kTVLiveBatchSizeBytes = 64 * 1024; // 64KB

// Memory-optimized settings
static const NSInteger kMemoryOptimizedHarvestCycleSeconds = 60;
static const NSInteger kMemoryOptimizedLiveHarvestCycleSeconds = 15;
static const NSInteger kMemoryOptimizedRegularBatchSizeBytes = 32 * 1024; // 32KB
static const NSInteger kMemoryOptimizedLiveBatchSizeBytes = 16 * 1024; // 16KB
static const NSInteger kMemoryOptimizedMaxDeadLetterSize = 50;

@implementation NRVAVideoConfiguration

+ (NRVAVideoConfigurationBuilder *)builder {
    return [[NRVAVideoConfigurationBuilder alloc] init];
}

- (instancetype)initWithBuilder:(NRVAVideoConfigurationBuilder *)builder {
    self = [super init];
    if (self) {
        if (!builder.applicationToken || builder.applicationToken.length == 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"Application token cannot be nil or empty"
                                         userInfo:nil];
        }
        
        _applicationToken = [builder.applicationToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        _region = [self identifyRegion:_applicationToken];
        _harvestCycleSeconds = builder.harvestCycleSeconds;
        _liveHarvestCycleSeconds = builder.liveHarvestCycleSeconds;
        _regularBatchSizeBytes = builder.regularBatchSizeBytes;
        _liveBatchSizeBytes = builder.liveBatchSizeBytes;
        _maxDeadLetterSize = builder.maxDeadLetterSize;
        _memoryOptimized = builder.memoryOptimized;
        _debugLoggingEnabled = builder.debugLoggingEnabled;
        _isTV = builder.isTV;
    }
    return self;
}

- (NSTimeInterval)deadLetterRetryInterval {
    if (self.isTV) {
        return 120.0; // 2 minutes for TV (more stable network)
    } else if (self.memoryOptimized) {
        return 180.0; // 3 minutes for low-memory devices
    } else {
        return 60.0;  // 1 minute for standard mobile
    }
}

/**
 * Enterprise-grade region identification with multiple fallback strategies
 * Thread-safe and optimized for performance
 */
- (NSString *)identifyRegion:(NSString *)applicationToken {
    if (!applicationToken || applicationToken.length < 10) {
        return @"US"; // Safe default
    }
    
    NSString *cleanToken = [applicationToken.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Thread-safe region mappings
    static NSDictionary *regionMappings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regionMappings = @{
            @"us": @"US",
            @"eu": @"EU",
            @"ap": @"AP",
            @"apac": @"AP",
            @"asia": @"AP",
            @"gov": @"GOV",
            @"fed": @"GOV",
            @"staging": @"STAGING",
            @"dev": @"STAGING",
            @"test": @"STAGING"
        };
    });
    
    // Strategy 1: Direct prefix matching (most reliable)
    for (NSString *regionKey in regionMappings.allKeys) {
        if ([cleanToken hasPrefix:regionKey] || [cleanToken containsString:[NSString stringWithFormat:@"-%@-", regionKey]]) {
            return regionMappings[regionKey];
        }
    }
    
    // Strategy 2: Token structure analysis
    if (cleanToken.length >= 40) { // Standard NR token length
        // EU tokens often have specific patterns
        if ([cleanToken containsString:@"eu"] || [cleanToken containsString:@"europe"]) {
            return @"EU";
        }
        // AP tokens often have specific patterns
        if ([cleanToken containsString:@"ap"] || [cleanToken containsString:@"asia"] || [cleanToken containsString:@"pacific"]) {
            return @"AP";
        }
        // Gov tokens have specific patterns
        if ([cleanToken containsString:@"gov"] || [cleanToken containsString:@"fed"]) {
            return @"GOV";
        }
    }
    
    // Strategy 3: Default to US for production stability
    return @"US";
}

@end

@implementation NRVAVideoConfigurationBuilder

- (instancetype)init {
    self = [super init];
    if (self) {
        // Auto-detect device capabilities and apply defaults
        BOOL isTV = [NRVAUtils isTVDevice];
        _isTV = isTV;
        
        // Apply appropriate defaults based on device type and memory optimization
        if (isTV) {
            _harvestCycleSeconds = kTVHarvestCycleSeconds;
            _liveHarvestCycleSeconds = kTVLiveHarvestCycleSeconds;
            _regularBatchSizeBytes = kTVRegularBatchSizeBytes;
            _liveBatchSizeBytes = kTVLiveBatchSizeBytes;
        } else {
            _harvestCycleSeconds = kDefaultHarvestCycleSeconds;
            _liveHarvestCycleSeconds = kDefaultLiveHarvestCycleSeconds;
            _regularBatchSizeBytes = kDefaultRegularBatchSizeBytes;
            _liveBatchSizeBytes = kDefaultLiveBatchSizeBytes;
        }
        
        _maxDeadLetterSize = kDefaultMaxDeadLetterSize;
        _memoryOptimized = NO;
        _debugLoggingEnabled = NO;
    }
    return self;
}

- (instancetype)withApplicationToken:(NSString *)applicationToken {
    self.applicationToken = applicationToken;
    return self;
}

- (instancetype)forTVOS:(BOOL)isTV {
    self.isTV = isTV;
    
    // Apply TV-specific optimizations
    if (isTV) {
        self.harvestCycleSeconds = kTVHarvestCycleSeconds;
        self.liveHarvestCycleSeconds = kTVLiveHarvestCycleSeconds;
        self.regularBatchSizeBytes = kTVRegularBatchSizeBytes;
        self.liveBatchSizeBytes = kTVLiveBatchSizeBytes;
    }
    
    return self;
}

- (instancetype)withMemoryOptimization:(BOOL)memoryOptimized {
    self.memoryOptimized = memoryOptimized;
    
    // Apply memory-optimized settings
    if (memoryOptimized) {
        self.harvestCycleSeconds = kMemoryOptimizedHarvestCycleSeconds;
        self.liveHarvestCycleSeconds = kMemoryOptimizedLiveHarvestCycleSeconds;
        self.regularBatchSizeBytes = kMemoryOptimizedRegularBatchSizeBytes;
        self.liveBatchSizeBytes = kMemoryOptimizedLiveBatchSizeBytes;
        self.maxDeadLetterSize = kMemoryOptimizedMaxDeadLetterSize;
    }
    
    return self;
}

- (instancetype)withDebugLogging:(BOOL)debugLoggingEnabled {
    self.debugLoggingEnabled = debugLoggingEnabled;
    return self;
}

- (instancetype)withHarvestCycle:(NSInteger)harvestCycleSeconds {
    self.harvestCycleSeconds = harvestCycleSeconds;
    return self;
}

- (instancetype)withLiveHarvestCycle:(NSInteger)liveHarvestCycleSeconds {
    self.liveHarvestCycleSeconds = liveHarvestCycleSeconds;
    return self;
}

- (instancetype)withRegularBatchSize:(NSInteger)regularBatchSizeBytes {
    self.regularBatchSizeBytes = regularBatchSizeBytes;
    return self;
}

- (instancetype)withLiveBatchSize:(NSInteger)liveBatchSizeBytes {
    self.liveBatchSizeBytes = liveBatchSizeBytes;
    return self;
}

- (instancetype)withMaxDeadLetterSize:(NSInteger)maxDeadLetterSize {
    self.maxDeadLetterSize = maxDeadLetterSize;
    return self;
}

- (NRVAVideoConfiguration *)build {
    return [[NRVAVideoConfiguration alloc] initWithBuilder:self];
}

@end
