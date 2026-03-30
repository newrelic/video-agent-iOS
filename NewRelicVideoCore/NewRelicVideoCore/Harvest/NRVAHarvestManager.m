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
#import "NRVideoDefs.h"
#import "NRVAVideo.h"
#import "NewRelicVideoAgent.h"
#import "NRVideoTracker.h"

// Private category to access NRVAVideo's internal properties
@interface NRVAVideo ()
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSNumber *> *trackerIds;
@property (nonatomic, strong, readonly) NRVAVideoConfiguration *configuration;
@end

// Private category to access NRVideoTracker's internal properties and methods
@interface NRVideoTracker ()
@property (nonatomic, readonly) BOOL isViewSessionActive;
@property (nonatomic, readonly) id qoeAggregator;
- (NSDictionary * _Nullable)generateQoeEventIfNeeded;
@end

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

#pragma mark - QoE Harvest Integration

// Collect QoE events from all active trackers
- (NSArray<NSDictionary *> *)collectAllActiveQoeEvents {
    NSMutableArray<NSDictionary *> *allQoeEvents = [NSMutableArray array];

    // Access video manager singleton to get active trackers
    NRVAVideo *videoInstance = [NRVAVideo getInstance];
    if (!videoInstance) return [allQoeEvents copy];

    // Get all tracker IDs from video manager
    NSArray<NSNumber *> *trackerIds = nil;
    @synchronized (videoInstance.trackerIds) {
        trackerIds = [videoInstance.trackerIds.allValues copy];
    }

    // Iterate through active trackers
    NewRelicVideoAgent *agent = [NewRelicVideoAgent sharedInstance];
    for (NSNumber *trackerId in trackerIds) {
        @try {
            // Get content tracker (where QOE lives)
            NRVideoTracker *tracker = (NRVideoTracker *)[agent contentTracker:trackerId];
            if (!tracker || ![tracker isKindOfClass:[NRVideoTracker class]]) continue;

            // Ask tracker for QoE if it's active and has aggregator
            if (tracker.isViewSessionActive && tracker.qoeAggregator) {
                NSDictionary *qoeEvent = [tracker generateQoeEventIfNeeded];
                if (qoeEvent) {
                    [allQoeEvents addObject:qoeEvent];
                }
            }
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"QoE generation failed for tracker %@: %@", trackerId, exception.reason);
            // Continue with other trackers
        }
    }

    return [allQoeEvents copy];
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

            NSMutableArray *finalEvents = events ? [events mutableCopy] : [NSMutableArray array];

            // QoE is independent of the batch — collect from all active trackers
            NSArray<NSDictionary *> *qoeEvents = [self collectAllActiveQoeEvents];
            if (qoeEvents.count > 0) {
                [finalEvents addObjectsFromArray:qoeEvents];
                NRVA_DEBUG_LOG(@"Added %lu QoE events from active trackers", (unsigned long)qoeEvents.count);
            }

            if (finalEvents.count > 0) {
                [self.crashSafeFactory.getHttpClient sendEvents:finalEvents
                                                     harvestType:harvestType
                                                      completion:^(BOOL success) {
                    if (success) {
                        // Notify event buffer about successful harvest to trigger any pending recovery
                        [self.crashSafeFactory.getEventBuffer onSuccessfulHarvest];
                    } else {
                        [self.crashSafeFactory.getDeadLetterHandler handleFailedEvents:finalEvents harvestType:harvestType];
                    }
                    NRVA_DEBUG_LOG(@"%@ harvest: %lu events", harvestType, (unsigned long)finalEvents.count);
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
