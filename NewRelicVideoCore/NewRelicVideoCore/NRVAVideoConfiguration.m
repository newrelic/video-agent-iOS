//
//  NRVAVideoConfiguration.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAVideoConfiguration.h"
#import "NRVAUtils.h"
#import "NRVADeviceInformation.h"
#import "NRVALog.h"

// Performance optimization constants
static const NSInteger kDefaultHarvestCycleSeconds = 5 * 60; // 5 minutes
static const NSInteger kDefaultLiveHarvestCycleSeconds = 30; // 30 seconds
static const NSInteger kDefaultRegularBatchSizeBytes = 64 * 1024; // 64KB
static const NSInteger kDefaultLiveBatchSizeBytes = 32 * 1024; // 32KB
static const NSInteger kDefaultMaxDeadLetterSize = 100;
static const NSInteger kDefaultMaxOfflineStorageSizeMB = 100; // 100MB

// TV-specific optimizations
static const NSInteger kTVHarvestCycleSeconds = 3 * 60; // 3 minutes
static const NSInteger kTVLiveHarvestCycleSeconds = 10; // 10 seconds
static const NSInteger kTVRegularBatchSizeBytes = 128 * 1024; // 128KB
static const NSInteger kTVLiveBatchSizeBytes = 64 * 1024; // 64KB
static const NSInteger kTVMaxOfflineStorageSizeMB = 200; // 200MB

// Memory-optimized settings
static const NSInteger kMemoryOptimizedHarvestCycleSeconds = 60;
static const NSInteger kMemoryOptimizedLiveHarvestCycleSeconds = 15;
static const NSInteger kMemoryOptimizedRegularBatchSizeBytes = 32 * 1024; // 32KB
static const NSInteger kMemoryOptimizedLiveBatchSizeBytes = 16 * 1024; // 16KB
static const NSInteger kMemoryOptimizedMaxDeadLetterSize = 50;
static const NSInteger kMemoryOptimizedMaxOfflineStorageSizeMB = 50; // 50MB

@interface NRVAVideoConfiguration ()
+ (NSString *)tryReadBaseAgentApplicationToken;
+ (NSString *)tryReadBaseAgentApplicationTokenAtPath:(NSString *)path;
@end

@implementation NRVAVideoConfiguration

+ (NRVAVideoConfigurationBuilder *)builder {
    return [[NRVAVideoConfigurationBuilder alloc] init];
}

- (instancetype)initWithBuilder:(NRVAVideoConfigurationBuilder *)builder {
    self = [super init];
    if (self) {
        NSString *resolvedToken = builder.applicationToken;

        // Fall back to the base New Relic iOS agent's licenseKey (bundled
        // newrelic.json) when the caller omits an explicit applicationToken.
        // See +tryReadBaseAgentApplicationToken for why this file specifically.
        if (!resolvedToken || resolvedToken.length == 0) {
            resolvedToken = [NRVAVideoConfiguration tryReadBaseAgentApplicationToken];
        }

        if (!resolvedToken || resolvedToken.length == 0) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:@"Application token cannot be nil or empty"
                                         userInfo:nil];
        }

        _applicationToken = [resolvedToken stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        _region = [self identifyRegion:_applicationToken];
        _harvestCycleSeconds = builder.harvestCycleSeconds;
        _liveHarvestCycleSeconds = builder.liveHarvestCycleSeconds;
        _regularBatchSizeBytes = builder.regularBatchSizeBytes;
        _liveBatchSizeBytes = builder.liveBatchSizeBytes;
        _maxDeadLetterSize = builder.maxDeadLetterSize;
        _maxOfflineStorageSizeMB = builder.maxOfflineStorageSizeMB;
        _memoryOptimized = builder.memoryOptimized;
        _debugLoggingEnabled = builder.debugLoggingEnabled;
        _isTV = builder.isTV;
        _collectorAddress = builder.collectorAddress;
        _qoeAggregateEnabled = builder.qoeAggregateEnabled;
        _qoeAggregateIntervalMultiplier = builder.qoeAggregateIntervalMultiplier;
        _obfuscationRules = [builder.obfuscationRules copy];
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
 * Parse region code from application token prefix
 * Matches NewRelic iOS Agent pattern: extracts region prefix before 'x'
 * Examples: "EUxABCD..." -> "EU", "APxABCD..." -> "AP", "AA..." -> ""
 */
- (NSString *)parseRegionFromToken:(NSString *)applicationToken {
    if (!applicationToken || applicationToken.length < 3) {
        return @"";
    }

    // Use regex to match pattern: ^.+?x (everything up to first 'x')
    NSError *regexError = nil;
    NSRegularExpression *regex = [[NSRegularExpression alloc] initWithPattern:@"^.+?x"
                                                                      options:0
                                                                        error:&regexError];

    if (regexError) {
        NRVA_ERROR_LOG(@"Failed to initialize region parsing regex: %@", regexError.localizedDescription);
        return @"";
    }

    NSTextCheckingResult *match = [regex firstMatchInString:applicationToken
                                                   options:0
                                                     range:NSMakeRange(0, applicationToken.length)];

    if (match == nil || match.range.location == NSNotFound) {
        return @""; // No region prefix found
    }

    NSString *matchString = [applicationToken substringWithRange:match.range];

    // Remove trailing 'x' characters to get the region code
    for (NSInteger i = (NSInteger)matchString.length - 1; i >= 0; i--) {
        if ([matchString characterAtIndex:i] != 'x') {
            return [matchString substringWithRange:NSMakeRange(0, (NSUInteger)i + 1)];
        }
    }

    return @"";
}

/**
 * Identify region with proper token parsing and fallback logic
 * Behavior similar to NewRelic iOS Agent's NRMAAgentConfiguration
 */
- (NSString *)identifyRegion:(NSString *)applicationToken {
    if (!applicationToken || applicationToken.length < 10) {
        return @"US"; // Safe default
    }

    // First, try to parse region from token prefix (e.g., "EUx", "APx")
    NSString *regionCode = [self parseRegionFromToken:applicationToken];

    if (regionCode.length > 0) {
        // Convert region code to uppercase and validate
        NSString *upperRegion = [regionCode uppercaseString];

        // Map region codes to standard regions
        static NSDictionary *regionMappings;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            regionMappings = @{
                @"EU": @"EU",
                @"AP": @"AP",
                @"APAC": @"AP",
                @"GOV": @"GOV",
                @"FED": @"GOV",
                @"JP": @"JP"
            };
        });

        NSString *mappedRegion = regionMappings[upperRegion];
        if (mappedRegion) {
            return mappedRegion;
        }
    }

    // Default to US for standard tokens without region prefix
    return @"US";
}

/**
 * Reads the base New Relic iOS agent's licenseKey from its bundled
 * newrelic.json config file, if present, for use when the caller omits an
 * explicit applicationToken.
 *
 * newrelic.json (at [NSBundle mainBundle]) is the base agent's ONLY
 * credential storage location at runtime — confirmed by reading the base
 * agent's own source: startAgent takes zero parameters, config loading has
 * no branching/override (no Info.plist key, no env var, no alternate
 * filename), and there is no Keychain/UserDefaults/remote-fetch/secondary
 * cache of credentials anywhere. The only other config-setting path is a
 * private, undocumented category (NewRelic+private.h createIAgent:) that is
 * explicitly internal-only and deliberately not used here. So reading this
 * file with public Foundation APIs is reading the same, and only, source of
 * truth the base agent itself would have used — not reaching into anything
 * private.
 *
 * "licenseKey" is the JSON key name the base agent's config file uses for
 * what mobile terminology elsewhere calls "application token" — same
 * AA...-NRMA token format as Android's applicationToken.
 *
 * Returns nil (not throwing) if the file is absent or malformed: that's
 * treated identically to "no base agent configured", same graceful
 * fallback-to-explicit-config behavior as the browser/Android equivalents.
 */
+ (NSString *)tryReadBaseAgentApplicationToken {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"newrelic" ofType:@"json"];
    if (!path) {
        NRVA_DEBUG_LOG(@"No newrelic.json found in the main bundle; no base agent config to fall back to.");
        return nil;
    }
    return [self tryReadBaseAgentApplicationTokenAtPath:path];
}

/**
 * Same as +tryReadBaseAgentApplicationToken, but reads+parses an explicit
 * file path instead of locating it via [NSBundle mainBundle] — so tests can
 * point it at a real temp file without needing a bundle resource. Real
 * callers always go through +tryReadBaseAgentApplicationToken; this exists
 * for testability only.
 */
+ (NSString *)tryReadBaseAgentApplicationTokenAtPath:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        NRVA_ERROR_LOG(@"Found newrelic.json at %@ but could not read its contents.", path);
        return nil;
    }

    NSError *jsonError = nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (jsonError || ![json isKindOfClass:[NSDictionary class]]) {
        NRVA_ERROR_LOG(@"newrelic.json is not valid JSON: %@", jsonError.localizedDescription);
        return nil;
    }

    NSDictionary *config = (NSDictionary *)json;
    NSString *licenseKey = config[@"licenseKey"];
    if (![licenseKey isKindOfClass:[NSString class]] || licenseKey.length == 0) {
        NRVA_ERROR_LOG(@"newrelic.json is missing a valid licenseKey.");
        return nil;
    }

    return licenseKey;
}

@end

@implementation NRVAVideoConfigurationBuilder

- (instancetype)init {
    self = [super init];
    if (self) {
        // Auto-detect device capabilities using centralized device information - FULLY AUTOMATIC
        NRVADeviceInformation *deviceInfo = [NRVADeviceInformation sharedInstance];
        BOOL isTV = deviceInfo.isTV;
        BOOL isLowMemory = deviceInfo.isLowMemoryDevice;
        
        _isTV = isTV;
        _memoryOptimized = isLowMemory;
        
        // Apply appropriate optimizations based on device type and memory
        if (isTV) {
            _harvestCycleSeconds = kTVHarvestCycleSeconds;
            _liveHarvestCycleSeconds = kTVLiveHarvestCycleSeconds;
            _regularBatchSizeBytes = kTVRegularBatchSizeBytes;
            _liveBatchSizeBytes = kTVLiveBatchSizeBytes;
            _maxOfflineStorageSizeMB = kTVMaxOfflineStorageSizeMB;
        } else if (isLowMemory) {
            _harvestCycleSeconds = kMemoryOptimizedHarvestCycleSeconds;
            _liveHarvestCycleSeconds = kMemoryOptimizedLiveHarvestCycleSeconds;
            _regularBatchSizeBytes = kMemoryOptimizedRegularBatchSizeBytes;
            _liveBatchSizeBytes = kMemoryOptimizedLiveBatchSizeBytes;
            _maxOfflineStorageSizeMB = kMemoryOptimizedMaxOfflineStorageSizeMB;
        } else {
            _harvestCycleSeconds = kDefaultHarvestCycleSeconds;
            _liveHarvestCycleSeconds = kDefaultLiveHarvestCycleSeconds;
            _regularBatchSizeBytes = kDefaultRegularBatchSizeBytes;
            _liveBatchSizeBytes = kDefaultLiveBatchSizeBytes;
            _maxOfflineStorageSizeMB = kDefaultMaxOfflineStorageSizeMB;
        }
        
        // Apply memory-specific settings if needed
        if (isLowMemory) {
            _maxDeadLetterSize = kMemoryOptimizedMaxDeadLetterSize;
        } else {
            _maxDeadLetterSize = kDefaultMaxDeadLetterSize;
        }

        _debugLoggingEnabled = NO;
        _collectorAddress = nil; // Will use default based on region
        _qoeAggregateEnabled = YES;
        _qoeAggregateIntervalMultiplier = 2;
        _obfuscationRules = nil;
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
        [self applyTVOptimizations];
    }
    
    return self;
}

- (instancetype)withMemoryOptimization:(BOOL)memoryOptimized {
    self.memoryOptimized = memoryOptimized;
    
    // Apply memory-optimized settings
    if (memoryOptimized) {
        [self applyMemoryOptimizations];
    }
    
    return self;
}

- (instancetype)withDebugLogging:(BOOL)debugLoggingEnabled {
    self.debugLoggingEnabled = debugLoggingEnabled;
    return self;
}

- (instancetype)withHarvestCycle:(NSInteger)harvestCycleSeconds {
    // Input validation: Harvest cycle must be between 5-300 seconds
    if (harvestCycleSeconds < 5 || harvestCycleSeconds > 300) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Harvest cycle must be between 5-300 seconds"
                                     userInfo:nil];
    }
    self.harvestCycleSeconds = harvestCycleSeconds;
    return self;
}

- (instancetype)withLiveHarvestCycle:(NSInteger)liveHarvestCycleSeconds {
    // Input validation: Live harvest cycle must be between 1-60 seconds
    if (liveHarvestCycleSeconds < 1 || liveHarvestCycleSeconds > 60) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Live harvest cycle must be between 1-60 seconds"
                                     userInfo:nil];
    }
    self.liveHarvestCycleSeconds = liveHarvestCycleSeconds;
    return self;
}

- (instancetype)withRegularBatchSize:(NSInteger)regularBatchSizeBytes {
    // Input validation: Regular batch size must be between 1KB-1MB
    if (regularBatchSizeBytes < 1024 || regularBatchSizeBytes > 1024 * 1024) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Regular batch size must be between 1KB-1MB"
                                     userInfo:nil];
    }
    self.regularBatchSizeBytes = regularBatchSizeBytes;
    return self;
}

- (instancetype)withLiveBatchSize:(NSInteger)liveBatchSizeBytes {
    // Input validation: Live batch size must be between 512B-512KB
    if (liveBatchSizeBytes < 512 || liveBatchSizeBytes > 512 * 1024) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Live batch size must be between 512B-512KB"
                                     userInfo:nil];
    }
    self.liveBatchSizeBytes = liveBatchSizeBytes;
    return self;
}

- (instancetype)withMaxDeadLetterSize:(NSInteger)maxDeadLetterSize {
    // Input validation: Max dead letter size must be between 10-1000
    if (maxDeadLetterSize < 10 || maxDeadLetterSize > 1000) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Max dead letter size must be between 10-1000"
                                     userInfo:nil];
    }
    self.maxDeadLetterSize = maxDeadLetterSize;
    return self;
}

- (instancetype)withMaxOfflineStorageSize:(NSInteger)maxOfflineStorageSizeMB {
    // Input validation: Max offline storage size must be greater than 0
    if (maxOfflineStorageSizeMB <= 0) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"Max offline storage size must be greater than 0 MB"
                                     userInfo:nil];
    }
    self.maxOfflineStorageSizeMB = maxOfflineStorageSizeMB;
    return self;
}

- (instancetype)withCollectorAddress:(NSString *)collectorAddress {
    self.collectorAddress = collectorAddress;
    return self;
}

- (instancetype)withQoeAggregateEnabled:(BOOL)enabled {
    self.qoeAggregateEnabled = enabled;
    return self;
}

- (instancetype)withObfuscationRules:(NSArray<NSDictionary *> *)rules {
    for (id rule in rules) {
        if (![rule isKindOfClass:[NSDictionary class]]) continue;
        NSString *pattern = rule[@"regex"];
        if (![pattern isKindOfClass:[NSString class]]) continue;
        NSError *error = nil;
        [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
        if (error) {
            @throw [NSException exceptionWithName:NSInvalidArgumentException
                                           reason:[NSString stringWithFormat:@"Invalid obfuscation regex '%@': %@",
                                                   pattern, error.localizedDescription]
                                         userInfo:nil];
        }
    }
    self.obfuscationRules = rules;
    return self;
}

- (instancetype)withQoeAggregateIntervalMultiplier:(NSInteger)multiplier {
    if (multiplier < 1) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
                                       reason:@"QoE aggregate interval multiplier must be >= 1"
                                     userInfo:nil];
    }
    self.qoeAggregateIntervalMultiplier = multiplier;
    return self;
}

- (void)applyTVOptimizations {
    self.harvestCycleSeconds = kTVHarvestCycleSeconds;
    self.liveHarvestCycleSeconds = kTVLiveHarvestCycleSeconds;
    self.regularBatchSizeBytes = kTVRegularBatchSizeBytes;
    self.liveBatchSizeBytes = kTVLiveBatchSizeBytes;
    self.maxOfflineStorageSizeMB = kTVMaxOfflineStorageSizeMB;
}

- (void)applyMemoryOptimizations {
    self.harvestCycleSeconds = kMemoryOptimizedHarvestCycleSeconds;
    self.liveHarvestCycleSeconds = kMemoryOptimizedLiveHarvestCycleSeconds;
    self.regularBatchSizeBytes = kMemoryOptimizedRegularBatchSizeBytes;
    self.liveBatchSizeBytes = kMemoryOptimizedLiveBatchSizeBytes;
    self.maxDeadLetterSize = kMemoryOptimizedMaxDeadLetterSize;
    self.maxOfflineStorageSizeMB = kMemoryOptimizedMaxOfflineStorageSizeMB;
}

- (NRVAVideoConfiguration *)build {
    return [[NRVAVideoConfiguration alloc] initWithBuilder:self];
}

@end
