//
//  NRVAPriorityEventBuffer.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAPriorityEventBuffer.h"
#import "NRVASizeEstimator.h"
#import "NRVADefaultSizeEstimator.h"
#import "NRVideoDefs.h"
#import "NRVALog.h"
#import "NRVAVideoConfiguration.h"
#import <UIKit/UIKit.h> 

@interface NRVAPriorityEventBuffer ()
{
    // Use instance variables instead of properties to avoid accessor issues
    NSMutableArray<NSDictionary<NSString *, id> *> *_liveEvents;
    NSMutableArray<NSDictionary<NSString *, id> *> *_ondemandEvents;
    dispatch_queue_t _bufferQueue;
    dispatch_semaphore_t _pollingSemaphore; // For non-blocking polling
    BOOL _isAppleTVDevice;
    BOOL _isRunningInLowMemory;
    NSInteger _maxLiveEvents;
    NSInteger _maxOndemandEvents;
    id<NRVAOverflowCallback> _overflowCallback;
    id<NRVACapacityCallback> _capacityCallback;
}
@end

@implementation NRVAPriorityEventBuffer

- (instancetype)initWithIsTV:(BOOL *)isTV {
    self = [super init];
    if (self) {
        _isAppleTVDevice = isTV;
        
        _isRunningInLowMemory = NO;
        
        _maxLiveEvents = _isAppleTVDevice ? 300 : 150;
        _maxOndemandEvents = _isAppleTVDevice ? 700 : 350;
        
        _liveEvents = [[NSMutableArray alloc] init];
        _ondemandEvents = [[NSMutableArray alloc] init];
        
        // Create thread-safe queue for buffer operations
        _bufferQueue = dispatch_queue_create("com.newrelic.videoagent.priority.buffer", DISPATCH_QUEUE_SERIAL);
        
        // ADDED: Initialize semaphore for non-blocking polling
        _pollingSemaphore = dispatch_semaphore_create(1);
        
        NRVA_DEBUG_LOG(@"Priority buffer initialized for %@ from configuration - Live: %ld, OnDemand: %ld",
                      isTV ? @"TV" : @"Mobile", (long)_maxLiveEvents, (long)_maxOndemandEvents);
    }
    return self;
}

- (void)dealloc {
    // No notification cleanup needed since we don't register for any
}


- (void)setOverflowCallback:(id<NRVAOverflowCallback>)callback {
    _overflowCallback = callback;
}

- (void)setCapacityCallback:(id<NRVACapacityCallback>)callback {
    _capacityCallback = callback;
}

- (void)addEvent:(NSDictionary<NSString *, id> *)event {
    if (event == nil) return;
    
    // CRITICAL FIX: Make this truly async and non-blocking
    dispatch_async(_bufferQueue, ^{
        // Check if this is a live streaming event
        BOOL isLiveContent = [self isLiveStreamingEvent:event];
        
        // Get the target queue for this event - exact Android logic
        NSMutableArray *targetQueue = isLiveContent ? _liveEvents : _ondemandEvents;
        NSInteger maxCapacity = isLiveContent ? _maxLiveEvents : _maxOndemandEvents;
        NSString *bufferType = isLiveContent ? @"live" : @"ondemand";
        
        // SCHEDULER STARTUP: Only start scheduler on FIRST event of each category
        BOOL wasEmpty = (targetQueue.count == 0);
        
        // Add the new event (this will be the most recent one)
        [targetQueue addObject:event];
        
        // Check capacity thresholds AFTER the event is added
        double currentCapacity = (double)targetQueue.count / maxCapacity;
        
        // DETAILED BUFFER CAPACITY LOGGING - Log every event with precise capacity
        NSInteger totalEvents = _liveEvents.count + _ondemandEvents.count;
        NRVA_DEBUG_LOG(@"📊 [BUFFER] Added %@ event: Live=%ld/%ld (%.3f), OnDemand=%ld/%ld (%.3f), Total=%ld | Capacity for %@: %.3f",
                      bufferType,
                      (long)_liveEvents.count, (long)_maxLiveEvents, (double)_liveEvents.count / _maxLiveEvents,
                      (long)_ondemandEvents.count, (long)_maxOndemandEvents, (double)_ondemandEvents.count / _maxOndemandEvents,
                      (long)totalEvents,
                      bufferType, currentCapacity);
        
        // Determine what actions need to be taken (but don't execute immediately)
        BOOL shouldTriggerHarvest = (currentCapacity >= 0.85);  // Trigger at 90% or higher
        BOOL shouldStartScheduler = wasEmpty;
        
        // Fallback: if we somehow still reach max capacity, remove oldest events
        NSInteger liveEventsRemoved = 0;
        NSInteger ondemandEventsRemoved = 0;
        
        while (_liveEvents.count > _maxLiveEvents) {
            [_liveEvents removeObjectAtIndex:0];
            liveEventsRemoved++;
        }
        while (_ondemandEvents.count > _maxOndemandEvents) {
            [_ondemandEvents removeObjectAtIndex:0];
            ondemandEventsRemoved++;
        }
        
        if (liveEventsRemoved > 0 || ondemandEventsRemoved > 0) {
            NRVA_DEBUG_LOG(@"⚠️ [BUFFER] OVERFLOW PROTECTION - Removed oldest events: Live=%ld, OnDemand=%ld",
                    (long)liveEventsRemoved, (long)ondemandEventsRemoved);
        }
        
        // CRITICAL FIX: Only call callbacks when really needed, not for every event
        if (shouldStartScheduler && _capacityCallback) {
            // Schedule callback on next run loop to avoid blocking
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_capacityCallback) {
                    NRVA_DEBUG_LOG(@"📞 [BUFFER] Calling capacity callback for %@ scheduler startup with capacity %.3f - Live: %ld, OnDemand: %ld", 
                                  bufferType, currentCapacity, (long)_liveEvents.count, (long)_ondemandEvents.count);
                    [_capacityCallback onCapacityThresholdReached:currentCapacity
                                                       bufferType:bufferType];
                }
            });
        }
        
        // Only trigger overflow for actual overflow situations (90%+ full)
        if (shouldTriggerHarvest && currentCapacity >= 0.9 && _overflowCallback) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_overflowCallback) {
                    NRVA_DEBUG_LOG(@"📞 [BUFFER] Calling overflow callback for %@ immediate harvest at %.3f capacity", bufferType, currentCapacity);
                    [_overflowCallback onBufferNearFull:bufferType];
                }
            });
        }
    });
}

// MODIFIED: This method is now non-blocking
- (NSArray<NSDictionary<NSString *, id> *> *)pollBatchByPriority:(NSInteger)maxSizeBytes
                                                    sizeEstimator:(id<NRVASizeEstimator>)sizeEstimator
                                                         priority:(NSString *)priority {
    // Try to acquire the polling lock without waiting (non-blocking).
    if (dispatch_semaphore_wait(_pollingSemaphore, DISPATCH_TIME_NOW) != 0) {
        // If the semaphore is already held, return immediately to avoid blocking.
        return @[];
    }
    
    __block NSArray<NSDictionary<NSString *, id> *> *result = @[];
    
    @try {
        BOOL isLivePriority = [@"live" isEqualToString:priority];
        
        NSMutableArray *targetQueue = isLivePriority ? _liveEvents : _ondemandEvents;
        if (targetQueue.count == 0) {
            // Fast path: return early if queue is empty
            return @[];
        }
        
        dispatch_sync(_bufferQueue, ^{
            if (targetQueue.count == 0) {
                result = @[];
                return;
            }
            
            NSInteger estimatedBatchSize = _isAppleTVDevice ?
            (isLivePriority ? 25 : 50) : (isLivePriority ? 15 : 30);
            NSMutableArray *batch = [[NSMutableArray alloc] initWithCapacity:estimatedBatchSize];
            
            NSInteger currentSize = 0;
            NSInteger maxEvents;
            if (isLivePriority) {
                maxEvents = _isAppleTVDevice ? 25 : 12;
            } else {
                maxEvents = _isAppleTVDevice ? 60 : 25;
            }
            
            for (NSInteger i = 0; i < maxEvents && targetQueue.count > 0; i++) {
                NSDictionary *event = targetQueue[0];
                [targetQueue removeObjectAtIndex:0];
                
                NSInteger eventSize;
                if (sizeEstimator != nil) {
                    eventSize = [sizeEstimator estimate:event];
                } else {
                    eventSize = _isAppleTVDevice ? 2048 : 1800;
                }
                
                if (currentSize + eventSize > maxSizeBytes && batch.count > 0) {
                    [targetQueue insertObject:event atIndex:0];
                    break;
                }
                
                // Dynamic low-memory check
                if (_isRunningInLowMemory && batch.count >= 8) {
                    [targetQueue insertObject:event atIndex:0];
                    break;
                }
                
                [batch addObject:event];
                currentSize += eventSize;
            }
            
            result = [batch copy];
        });
    }
    @finally {
        // IMPORTANT: Always release the semaphore to allow the next poll.
        dispatch_semaphore_signal(_pollingSemaphore);
    }
    
    return result;
}

- (NSInteger)getEventCount {
    __block NSInteger count = 0;
    dispatch_sync(_bufferQueue, ^{
        count = _liveEvents.count + _ondemandEvents.count;
    });
    return count;
}

- (BOOL)isEmpty {
    __block BOOL empty = YES;
    dispatch_sync(_bufferQueue, ^{
        empty = _liveEvents.count == 0 && _ondemandEvents.count == 0;
    });
    return empty;
}

- (void)cleanup {
    [self clear];
}

- (void)clear {
    dispatch_sync(_bufferQueue, ^{
        [_liveEvents removeAllObjects];
        [_ondemandEvents removeAllObjects];
    });
}

#pragma mark - Private Methods

- (BOOL)isLiveStreamingEvent:(NSDictionary<NSString *, id> *)event {
    // Check for explicit live content marker
    NSNumber *isLive = event[@"contentIsLive"];
    if (isLive != nil) {
        return [isLive boolValue];
    }
    
    // Default to on-demand if not explicitly marked as live
    return NO;
}

// Called after a successful harvest - no-op for in-memory buffer
- (void)onSuccessfulHarvest {
    // No-op: This is just the in-memory buffer, recovery logic is handled by CrashSafeEventBuffer wrapper
}

@end
