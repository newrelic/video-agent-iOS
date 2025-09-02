//
//  NRVADeadLetterEventBuffer.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVADeadLetterEventBuffer.h"
#import "NRVASizeEstimator.h"
#import "NRVALog.h"

@interface NRVADeadLetterEventBuffer ()

@property (nonatomic, assign) BOOL isAppleTVDevice;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *retryEvents;
@property (nonatomic, strong) dispatch_queue_t deadLetterQueue_queue;
@property (nonatomic, assign) NSInteger maxCapacity;

@end

@implementation NRVADeadLetterEventBuffer

- (instancetype)initWithIsTV:(BOOL)isTV {
    self = [super init];
    if (self) {
        _isAppleTVDevice = isTV;
        _retryEvents = [[NSMutableArray alloc] init];
        _deadLetterQueue_queue = dispatch_queue_create("com.newrelic.videoagent.deadletter.buffer", DISPATCH_QUEUE_SERIAL);
        
        // Smaller capacity for dead letter queue - it's just for retries
        _maxCapacity = _isAppleTVDevice ? 200 : 100;
        
        NRVA_DEBUG_LOG(@"Dead letter buffer initialized - Max capacity: %ld", (long)_maxCapacity);
    }
    return self;
}

#pragma mark - NRVAEventBufferInterface

- (void)addEvent:(NSDictionary<NSString *, id> *)event {
    if (!event) return;
    
    dispatch_async(self.deadLetterQueue_queue, ^{
        // Simple add with capacity management - no callbacks, no scheduler triggers
        [self.retryEvents addObject:event];
        
        // Simple overflow protection - remove oldest if over capacity
        while (self.retryEvents.count > self.maxCapacity) {
            [self.retryEvents removeObjectAtIndex:0];
        }
    });
}

- (NSArray<NSDictionary<NSString *, id> *> *)pollBatchByPriority:(NSInteger)maxSizeBytes 
                                                    sizeEstimator:(id<NRVASizeEstimator>)sizeEstimator 
                                                         priority:(NSString *)priority {
    __block NSArray<NSDictionary<NSString *, id> *> *result = @[];
    
    dispatch_sync(self.deadLetterQueue_queue, ^{
        NSMutableArray *batch = [[NSMutableArray alloc] init];
        
        // Simple FIFO - no priority separation needed for retry events
        NSInteger maxEvents = self.isAppleTVDevice ? 20 : 10; // Small batches for retries
        NSInteger currentSize = 0;
        
        for (NSInteger i = 0; i < maxEvents && self.retryEvents.count > 0; i++) {
            NSDictionary *event = self.retryEvents[0];
            [self.retryEvents removeObjectAtIndex:0];
            
            if (event == nil) break;
            
            NSInteger eventSize = sizeEstimator ? [sizeEstimator estimate:event] : 2048;
            if (currentSize + eventSize > maxSizeBytes && batch.count > 0) {
                [self.retryEvents insertObject:event atIndex:0]; // Put back
                break;
            }
            
            [batch addObject:event];
            currentSize += eventSize;
        }
        
        result = [batch copy];
    });
    
    return result;
}

- (NSInteger)getEventCount {
    __block NSInteger count = 0;
    dispatch_sync(self.deadLetterQueue_queue, ^{
        count = self.retryEvents.count;
    });
    return count;
}

- (BOOL)isEmpty {
    return [self getEventCount] == 0;
}

- (void)cleanup {
    dispatch_sync(self.deadLetterQueue_queue, ^{
        [self.retryEvents removeAllObjects];
    });
}

// Dead letter queues don't need callbacks - they're just retry storage
- (void)setOverflowCallback:(id<NRVAOverflowCallback>)callback {
    // No-op - dead letter queues don't trigger harvests
}

- (void)setCapacityCallback:(id<NRVACapacityCallback>)callback {
    // No-op - dead letter queues don't start schedulers
}

@end
