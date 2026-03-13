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

// Define constants for event types to avoid magic strings
static NSString * const kNRVAEventTypeOnDemand = @"ondemand";
static NSString * const kNRVAEventTypeLive = @"live";

@interface NRVAHarvestManager ()

@property (nonatomic, strong) NRVAVideoConfiguration *config;
@property (nonatomic, strong) id<NRVAHarvestComponentFactory> crashSafeFactory;
@property (nonatomic, strong) NRVADefaultSizeEstimator *sizeEstimator;
@property (nonatomic, strong) dispatch_queue_t harvestQueue;
@property (nonatomic) NSInteger qoeCycleCount;
@property (nonatomic, strong) NSDictionary *pendingFinalQoe;
@property (nonatomic, strong) NSDictionary *lastSentQoEAttributes; // Snapshot for dirty check

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

- (void)setQoeEventProvider:(NSDictionary * (^)(void))qoeEventProvider {
    _qoeEventProvider = [qoeEventProvider copy];
    _qoeCycleCount = 0;
}

- (void)enqueueFinalQoeEvent:(NSDictionary *)event {
    dispatch_async(self.harvestQueue, ^{
        self.pendingFinalQoe = event;
    });
}

- (NSDictionary *)collectQoeEventIfNeeded {
    // Pending final QoE (from sendEnd) takes priority — always sent, bypasses dirty check.
    // The event was built eagerly on the tracker thread while state was still valid,
    // so there is no race with aggregator reset or provider nil.
    if (self.pendingFinalQoe) {
        NSDictionary *finalEvent = self.pendingFinalQoe;
        self.pendingFinalQoe = nil;
        _qoeEventProvider = nil;
        _qoeCycleCount = 0;
        self.lastSentQoEAttributes = nil; // Clear snapshot for next session
        return finalEvent;
    }

    NSDictionary * (^provider)(void) = self.qoeEventProvider;
    if (!provider) return nil;

    self.qoeCycleCount++;

    NSInteger multiplier = self.config.qoeAggregateIntervalMultiplier;
    if (multiplier < 1) multiplier = 1;
    BOOL qualifies = (self.qoeCycleCount - 1) % multiplier == 0;

    if (!qualifies) return nil;

    // Multiplier satisfied — build the QoE event and check if KPIs changed
    NSDictionary *qoeEvent = provider();
    if (!qoeEvent) return nil;

    if ([self qoeAttributesChangedFrom:self.lastSentQoEAttributes to:qoeEvent]) {
        self.lastSentQoEAttributes = qoeEvent;
        return qoeEvent;
    }

    // KPIs unchanged — skip sending
    return nil;
}

// Compare QoE KPI attributes between two events. Returns YES if any KPI value changed.
// Only compares KPI keys (not metadata like timestamp, actionName, eventType).
- (BOOL)qoeAttributesChangedFrom:(NSDictionary *)previous to:(NSDictionary *)current {
    if (!previous) return YES; // First QoE event — always send

    for (NSString *key in NRVAAllKPIKeys()) {
        id prevVal = previous[key];
        id currVal = current[key];
        if (prevVal == nil && currVal == nil) continue;
        if (prevVal == nil || currVal == nil) return YES;
        if (![prevVal isEqual:currVal]) return YES;
    }
    return NO;
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

            // QoE is independent of the batch — collect if multiplier qualifies and KPIs changed
            NSDictionary *qoeEvent = [self collectQoeEventIfNeeded];
            if (qoeEvent) {
                [finalEvents addObject:qoeEvent];
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
