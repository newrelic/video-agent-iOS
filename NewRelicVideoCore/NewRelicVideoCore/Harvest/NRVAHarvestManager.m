//
//  NRVAHarvestManager.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAHarvestManager.h"
#import "NRVAVideoConfiguration.h"
#import "NRVACrashSafeHarvestFactory.h"
#import "NRVAEventBufferInterface.h"
#import "NRVAHttpClientInterface.h"
#import "NRVASchedulerInterface.h"
#import "NRVAIntegratedDeadLetterHandler.h"
#import "NRVADefaultSizeEstimator.h"
#import "NRVAUtils.h"
#import "NRVALog.h"

// Define constants for event types to avoid magic strings
static NSString * const kNRVAEventTypeOnDemand = @"ondemand";
static NSString * const kNRVAEventTypeLive = @"live";

@interface NRVAHarvestManager ()

@property (nonatomic, strong) NRVAVideoConfiguration *config;
@property (nonatomic, strong) id<NRVAHarvestComponentFactory> crashSafeFactory;
@property (nonatomic, strong) NRVADefaultSizeEstimator *sizeEstimator;
@property (nonatomic, strong) dispatch_queue_t harvestQueue;

@end

@implementation NRVAHarvestManager

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)config {
    self = [super init];
    if (self) {
        _config = config;
        _harvestQueue = dispatch_queue_create("com.newrelic.videoagent.harvest", DISPATCH_QUEUE_SERIAL);
        _sizeEstimator = [[NRVADefaultSizeEstimator alloc] init];
        
        // Create harvest task blocks for the factory
        __weak typeof(self) weakSelf = self;
        void(^overflowTask)(NSString *) = ^(NSString *bufferType) {
            NRVA_DEBUG_LOG(@"Buffer overflow detected for %@ - triggering immediate harvest", bufferType);
            [weakSelf harvestNow:bufferType];
        };
        
        // Start scheduler only when buffer reaches 60% capacity
        void(^capacityCallback)(double capacity, NSString *bufferType) = ^(double capacity, NSString *bufferType) {
           
                NRVA_DEBUG_LOG(@"Capacity threshold reached for %@ (%.1f%%) - starting scheduler", bufferType, capacity * 100);
                [weakSelf.crashSafeFactory.getScheduler startWithBufferType:bufferType];
            
        };
        
        void(^onDemandTask)(void) = ^{
            [weakSelf harvestOnDemand];
        };
        
        void(^liveTask)(void) = ^{
            [weakSelf harvestLive];
        };
        
        // Initialize crash-safe factory with all components
        _crashSafeFactory = [[NRVACrashSafeHarvestFactory alloc] initWithConfiguration:config
                                                                       overflowCallback:overflowTask
                                                                       capacityCallback:capacityCallback
                                                                          onDemandTask:onDemandTask
                                                                              liveTask:liveTask];
        
        NRVA_DEBUG_LOG(@"HarvestManager initialized");
        
        // Log recovery status if in recovery mode
        if ([_crashSafeFactory isRecovering]) {
            NRVA_DEBUG_LOG(@"🔄 Recovery mode detected: %@", [_crashSafeFactory getRecoveryStats]);
        }
    }
    return self;
}

- (void)recordEvent:(NSString *)eventType attributes:(NSDictionary<NSString *, id> *)attributes {
    if (!eventType || eventType.length == 0) {
        NRVA_ERROR_LOG(@"Cannot record event: eventType is nil or empty");
        return;
    }
    
    dispatch_async(self.harvestQueue, ^{
        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:(attributes ?: @{})];
        event[@"eventType"] = eventType;
        event[@"timestamp"] = @([[NSDate date] timeIntervalSince1970] * 1000); // milliseconds
        
        // Add to event buffer - this will trigger capacity monitoring
        [self.crashSafeFactory.getEventBuffer addEvent:[event copy]];
        
        NRVA_DEBUG_LOG(@"🗂️ Queued event: %@ (total queue size: %lu)",
                      eventType, (unsigned long)[self.crashSafeFactory.getEventBuffer getEventCount]);
    });
}

- (void)harvestOnDemand {
    NSInteger batchSizeBytes = self.config.regularBatchSizeBytes;
    [self harvestWithBatchSize:batchSizeBytes priorityFilter:kNRVAEventTypeOnDemand harvestType:kNRVAEventTypeOnDemand];
}

- (void)harvestLive {
    NSInteger batchSizeBytes = self.config.liveBatchSizeBytes;
    [self harvestWithBatchSize:batchSizeBytes priorityFilter:kNRVAEventTypeLive harvestType:kNRVAEventTypeLive];
}

- (id<NRVAHarvestComponentFactory>)getFactory {
    return self.crashSafeFactory;
}

- (NSUInteger)queueSize {
    // Ensure thread safety by dispatching to the harvest queue
    __block NSUInteger count = 0;
    dispatch_sync(self.harvestQueue, ^{
        count = [self.crashSafeFactory.getEventBuffer getEventCount];
    });
    return count;
}

- (NSString *)getRecoveryStatus {
    return [self.crashSafeFactory getRecoveryStats];
}

#pragma mark - Private Harvest Methods

- (void)harvestNow:(NSString *)bufferType {
    dispatch_async(self.harvestQueue, ^{
        // STRICT: Validation to ensure a session is either 'live' or 'ondemand'
        if ([kNRVAEventTypeLive isEqualToString:bufferType]) {
            [self harvestLive];
        } else if ([kNRVAEventTypeOnDemand isEqualToString:bufferType]) {
            [self harvestOnDemand];
        } else {
            NRVA_ERROR_LOG(@"Invalid buffer type for immediate harvest: %@. Sessions must be either 'live' or 'ondemand'.", bufferType);
            // Do nothing to force correct buffer type, matching Android behavior
        }
    });
}

- (void)harvestWithBatchSize:(NSInteger)batchSizeBytes priorityFilter:(NSString *)priorityFilter harvestType:(NSString *)harvestType {
    dispatch_async(self.harvestQueue, ^{
        @try {
            NSArray<NSDictionary<NSString *, id> *> *events = [self.crashSafeFactory.getEventBuffer pollBatchByPriority:batchSizeBytes
                                                                                                           sizeEstimator:self.sizeEstimator
                                                                                                                priority:priorityFilter];
            
            if (events && events.count > 0) {
                [self.crashSafeFactory.getHttpClient sendEvents:events
                                                     harvestType:harvestType
                                                      completion:^(BOOL success) {
                    if (success) {
                        // Notify event buffer about successful harvest to trigger any pending recovery
                        [self.crashSafeFactory.getEventBuffer onSuccessfulHarvest];
                    } else {
                        [self.crashSafeFactory.getDeadLetterHandler handleFailedEvents:events harvestType:harvestType];
                    }
                    NRVA_DEBUG_LOG(@"%@ harvest: %lu events", harvestType, (unsigned long)events.count);
                }];
            }
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"%@ harvest failed: %@", harvestType, exception.reason);
        }
    });
}

- (void)dealloc {
    // Perform any necessary cleanup
    [self.crashSafeFactory cleanup];
}

@end
