//
//  NRVAIntegratedDeadLetterHandler.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAIntegratedDeadLetterHandler.h"
#import "NRVACrashSafeEventBuffer.h"
#import "NRVAVideoConfiguration.h"
#import "NRVAHttpClientInterface.h"
#import "NRVADeadLetterEventBuffer.h"
#import "NRVADefaultSizeEstimator.h" 
#import "NRVALog.h"
#import <os/lock.h>

// NOTE: The following properties are assumed to exist on your NRVAVideoConfiguration class
@interface NRVAVideoConfiguration (DeadLetter)
@property (nonatomic, readonly) NSInteger regularBatchSizeBytes;
@property (nonatomic, readonly) NSInteger liveBatchSizeBytes;
@property (nonatomic, readonly) NSTimeInterval deadLetterRetryInterval; // in Milliseconds
@property (nonatomic, readonly) NSInteger maxDeadLetterQueueSize;
@property (nonatomic, readonly) BOOL isMemoryOptimized;
@end

@interface NRVAIntegratedDeadLetterHandler ()

@property (nonatomic, strong) id<NRVAEventBufferInterface> inMemoryQueue;
@property (nonatomic, strong) NRVACrashSafeEventBuffer *mainBuffer;
@property (nonatomic, strong) id<NRVAHttpClientInterface> httpClient;
@property (nonatomic, strong) NRVAVideoConfiguration *configuration;

// Configuration-driven properties
@property (nonatomic, assign) NSInteger maxRetries;
@property (nonatomic, assign) NSInteger maxDeadLetterSize;
@property (nonatomic, assign) NSInteger regularBatchSizeForRetry;
@property (nonatomic, assign) NSInteger liveBatchSizeForRetry;
@property (nonatomic, assign) NSTimeInterval retryInterval;
@property (nonatomic, assign) NSTimeInterval liveRetryInterval;

// Thread safety
@property (nonatomic, assign) os_unfair_lock processingLock;
@property (nonatomic, assign) BOOL isProcessing;

@end

@implementation NRVAIntegratedDeadLetterHandler

- (instancetype)initWithMainBuffer:(NRVACrashSafeEventBuffer *)mainBuffer
                        httpClient:(id<NRVAHttpClientInterface>)httpClient
                     configuration:(NRVAVideoConfiguration *)configuration {
    self = [super init];
    if (self) {
        _mainBuffer = mainBuffer;
        _httpClient = httpClient;
        _configuration = configuration;
        _processingLock = OS_UNFAIR_LOCK_INIT;
        
        _inMemoryQueue = [[NRVADeadLetterEventBuffer alloc] initWithIsTV:configuration.isTV];
        
        _maxDeadLetterSize = 100;
        _regularBatchSizeForRetry = configuration.regularBatchSizeBytes;
        _liveBatchSizeForRetry = configuration.liveBatchSizeBytes;
        _retryInterval = configuration.deadLetterRetryInterval / 1000.0;
        _liveRetryInterval = MAX(_retryInterval / 2.0, 30.0);

        if (configuration.isTV) {
            _maxRetries = configuration.memoryOptimized ? 3 : 5;
        } else {
            _maxRetries = configuration.memoryOptimized ? 2 : 3;
        }

        NRVA_DEBUG_LOG(@"Dead letter handler initialized - MaxRetries: %ld, RegularBatchSize: %ld, LiveBatchSize: %ld, RetryInterval: %.0fs, LiveRetryInterval: %.0fs",
                 (long)_maxRetries,
                 (long)_regularBatchSizeForRetry,
                 (long)_liveBatchSizeForRetry,
                 _retryInterval,
                 _liveRetryInterval);
    }
    return self;
}

- (void)handleFailedEvents:(NSArray<NSDictionary<NSString *, id> *> *)failedEvents harvestType:(NSString *)harvestType {
    if (failedEvents == nil || failedEvents.count == 0) {
        return;
    }
    
    os_unfair_lock_lock(&_processingLock);
    if (_isProcessing) {
        os_unfair_lock_unlock(&_processingLock);
        NRVA_DEBUG_LOG(@"Dead letter handler is already processing.");
        return;
    }
    _isProcessing = YES;
    os_unfair_lock_unlock(&_processingLock);
    
    @try {
        NSMutableArray *toRetry = [NSMutableArray array];
        NSMutableArray *toBackup = [NSMutableArray array];

        for (NSDictionary<NSString *, id> *event in failedEvents) {
            int retryCount = [self getRetryCount:event];

            if (retryCount < self.maxRetries && [self hasMemoryCapacity]) {
                NSDictionary *retryEvent = [self addRetryMetadata:event harvestType:harvestType retryCount:(retryCount + 1)];
                [toRetry addObject:retryEvent];
            } else {
                [toBackup addObject:[self cleanEvent:event]];
            }
        }

        [self queueRetryEvents:toRetry];

        if (toBackup.count > 0) {
            [self.mainBuffer backupFailedEvents:toBackup];
            NRVA_DEBUG_LOG(@"Dead letter handler: Retrying %lu events, Backing up %lu events.", (unsigned long)toRetry.count, (unsigned long)toBackup.count);
        }
    } @finally {
        os_unfair_lock_lock(&_processingLock);
        _isProcessing = NO;
        os_unfair_lock_unlock(&_processingLock);
    }
}

- (void)emergencyBackup {
    @try {
        // Calculate the batch size exactly as Android does, based on configuration.
        NSInteger emergencyBatchSize;
        if (self.configuration.isTV) {
            emergencyBatchSize = self.maxDeadLetterSize * 3; // TV can handle more
        } else {
            emergencyBatchSize = self.maxDeadLetterSize * 2;   // Mobile is conservative
        }
        
        // Poll a batch of pending events using the calculated size and specific priority.
        NSArray *pendingEvents = [self.inMemoryQueue pollBatchByPriority:emergencyBatchSize
                                                            sizeEstimator:nil
                                                                 priority:@"ondemand"];
        
        if (pendingEvents.count > 0) {
            NSMutableArray *cleanEvents = [NSMutableArray array];
            for (NSDictionary *event in pendingEvents) {
                [cleanEvents addObject:[self cleanEvent:event]];
            }
            
            // Delegate backup to the main crash-safe buffer
            [self.mainBuffer backupFailedEvents:cleanEvents];
            NRVA_DEBUG_LOG(@"Dead letter emergency backup: %lu events saved.", (unsigned long)cleanEvents.count);
        }
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Dead letter emergency backup failed: %@", exception.reason);
    }
}

- (NSInteger)inMemoryRetryQueueSize {
    return [self.inMemoryQueue getEventCount];
}

#pragma mark - Private Helper Methods

- (void)queueRetryEvents:(NSArray<NSDictionary<NSString *, id> *> *)toRetry {
    for (NSDictionary<NSString *, id> *event in toRetry) {
        // If the queue is full, make room by removing a percentage of the oldest events.
        if ([self.inMemoryQueue getEventCount] >= self.maxDeadLetterSize) {
            // Calculate number of events to remove (5% for mobile, 10% for TV, minimum 1).
            NSInteger eventsToRemove = MAX(self.maxDeadLetterSize / 20, 1);
            if (self.configuration.isTV) {
                eventsToRemove *= 2;
            }

            // Poll events one by one to remove them.
            for (int i = 0; i < eventsToRemove; i++) {
                NSArray *removed = [self.inMemoryQueue pollBatchByPriority:1
                                                              sizeEstimator:[[NRVADefaultSizeEstimator alloc] init]
                                                                   priority:@"ondemand"];
                if (removed.count == 0) {
                    break; // Stop if the queue becomes empty.
                }
            }
        }
        [self.inMemoryQueue addEvent:event];
    }
}

- (BOOL)hasMemoryCapacity {
    NSInteger currentSize = [self.inMemoryQueue getEventCount];
    NSInteger maxSize = self.maxDeadLetterSize;

    // Configuration-driven memory capacity check, mirroring Android's logic
    if (self.configuration.isTV && !self.configuration.memoryOptimized) {
        // TV with plenty of memory, allow 90% usage
        return currentSize < (maxSize * 0.9);
    } else if (!self.configuration.memoryOptimized) {
        // Non-memory-optimized mobile, allow 80% usage
        return currentSize < (maxSize * 0.8);
    } else {
        // Memory-optimized device, be conservative at 65% usage
        return currentSize < (maxSize * 0.65);
    }
}

- (int)getRetryCount:(NSDictionary<NSString *, id> *)event {
    NSDictionary *metadata = event[@"_retryMetadata"];
    if ([metadata isKindOfClass:[NSDictionary class]]) {
        NSNumber *count = metadata[@"retryCount"];
        if ([count isKindOfClass:[NSNumber class]]) {
            return [count intValue];
        }
    }
    return 0;
}

- (NSDictionary<NSString *, id> *)addRetryMetadata:(NSDictionary<NSString *, id> *)event harvestType:(NSString *)harvestType retryCount:(int)retryCount {
    NSMutableDictionary *retryEvent = [event mutableCopy];
    
    // Get platform-specific values, matching the data provided by the Android version
    NSString *deviceType = self.configuration.isTV ? @"tvOS" : @"iOS";
    long long timestamp = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
    
    NSDictionary *metadata = @{
        @"retryCount": @(retryCount),
        @"category": harvestType ?: @"unknown",
        @"deviceType": deviceType,
    };
    
    retryEvent[@"retryMetadata"] = metadata;
    return [retryEvent copy];
}

- (NSDictionary<NSString *, id> *)cleanEvent:(NSDictionary<NSString *, id> *)event {
    NSMutableDictionary *cleanEvent = [event mutableCopy];
    [cleanEvent removeObjectForKey:@"_retryMetadata"];
    return [cleanEvent copy];
}

@end