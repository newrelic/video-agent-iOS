//
//  NRVACrashSafeEventBuffer.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVACrashSafeEventBuffer.h"
#import "NRVAPriorityEventBuffer.h"
#import "NRVAVideoConfiguration.h"
#import "NRVAOfflineStorage.h"
#import "NRVALog.h"

#define kNRVASessionActiveKey @"NRVAVideoSessionActive"
#define kNRVALastEventCountKey @"NRVAVideoLastEventCount"

@implementation NRVARecoveryStats
- (instancetype)initWithRecovering:(BOOL)isRecovering
                  backupEventCount:(NSInteger)backupEventCount
                  memoryEventCount:(NSInteger)memoryEventCount
                        isTVDevice:(BOOL)isTVDevice {
    self = [super init];
    if (self) {
        _isRecovering = isRecovering;
        _backupEventCount = backupEventCount;
        
        
    }
    return self;
}

@end

@interface NRVACrashSafeEventBuffer ()

// Core components
@property (nonatomic, strong) NRVAPriorityEventBuffer *memoryBuffer;
@property (nonatomic, strong) NRVAOfflineStorage *offlineStorage;
@property (nonatomic, strong) NRVAVideoConfiguration *configuration;
@property (nonatomic, strong) dispatch_queue_t crashSafeQueue;

// State management
@property (nonatomic, assign) BOOL isRecovering;
@property (nonatomic, assign) BOOL hasPendingRecovery;
@property (nonatomic, assign) NSInteger lastEventCount;

// TV vs. Mobile Optimizations
@property (nonatomic, assign) BOOL isTVDevice;
@property (nonatomic, assign) NSInteger emergencyBackupThreshold;

@end

@implementation NRVACrashSafeEventBuffer

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration
                       offlineStorage:(NRVAOfflineStorage *)offlineStorage {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _offlineStorage = offlineStorage;
        _memoryBuffer = [[NRVAPriorityEventBuffer alloc] initWithIsTV:configuration.isTV];
        _crashSafeQueue = dispatch_queue_create("com.newrelic.videoagent.crashsafe", DISPATCH_QUEUE_SERIAL);
        _isTVDevice = configuration.isTV;
        _emergencyBackupThreshold = _isTVDevice ? 200 : 100;
        _isRecovering = NO;

        [self checkCrashRecovery];
        [self markSessionStart];
    }
    return self;
}

#pragma mark - NRVAEventBufferInterface

- (void)addEvent:(NSDictionary<NSString *, id> *)event {
    [self.memoryBuffer addEvent:event];
    self.lastEventCount++;

    // TV optimization: Periodically save the event count, matching Android's implementation.
    if (self.isTVDevice && (self.lastEventCount % self.emergencyBackupThreshold == 0)) {
        [self updateCrashDetectionCounter];
    }
}

- (NSArray<NSDictionary<NSString *, id> *> *)pollBatchByPriority:(NSInteger)maxSizeBytes
                                                    sizeEstimator:(id<NRVASizeEstimator>)sizeEstimator
                                                         priority:(NSString *)priority {
    
    NSMutableArray<NSDictionary<NSString *, id> *> *batch =
        [[self.memoryBuffer pollBatchByPriority:maxSizeBytes sizeEstimator:sizeEstimator priority:priority] mutableCopy];
    
    if (self.isRecovering) {
        NSInteger optimalBatchSize = [self getOptimalBatchSizeForPriority:priority];
        NSInteger remainingCapacity = MAX(0, optimalBatchSize - batch.count);
        NSInteger minRecoverySize = MAX(remainingCapacity, self.isRecovering ? 5 : 0);
        
        if (minRecoverySize > 0) {
            NSArray<NSDictionary *> *recoveryEvents = [self pollRecoveryEventsForPriority:priority maxSize:minRecoverySize];
            if (recoveryEvents.count > 0) {
                [batch addObjectsFromArray:recoveryEvents];
                NRVA_DEBUG_LOG(@"🔄 Integrated %ld recovery events into %@ harvest batch", (long)recoveryEvents.count, priority);
            }
        }
    }
    
    return [batch copy];
}

- (NSInteger)getEventCount {
    NSInteger memoryCount = [self.memoryBuffer getEventCount];
    return self.isRecovering ? memoryCount + [self.offlineStorage getEventCount] : memoryCount;
}

- (BOOL)isEmpty {
    BOOL isOfflineEmpty = !self.isRecovering || [self.offlineStorage getEventCount] == 0;
    return [self.memoryBuffer isEmpty] && isOfflineEmpty;
}

- (void)onSuccessfulHarvest {
    [self.memoryBuffer onSuccessfulHarvest];
    
    // CRITICAL FIX: Remove successfully transmitted recovery events
    if (self.isRecovering) {
        dispatch_async(self.crashSafeQueue, ^{
            // Clean up processed events from all files after successful harvest
            NSArray<NSString *> *allFiles = [self.offlineStorage getAllOfflineFileNames];
            for (NSString *filename in allFiles) {
                [self.offlineStorage removeProcessedEventsFromFile:filename];
            }
            
            // Check if recovery is complete after cleanup
            if ([self.offlineStorage getEventCount] == 0) {
                self.isRecovering = NO;
                NRVA_LOG(@"🔄 Recovery complete - all offline events successfully transmitted and removed.");
            } else {
                NRVA_DEBUG_LOG(@"🔄 Recovery ongoing - %ld events remaining after cleanup", (long)[self.offlineStorage getEventCount]);
            }
        });
    }
    
    BOOL shouldStartRecovery = NO;

    if (self.hasPendingRecovery && !self.isRecovering) {
        self.hasPendingRecovery = NO;
        shouldStartRecovery = YES;
        NRVA_LOG(@"Starting crash recovery after successful harvest.");
    }

    if (!self.isRecovering && [self.offlineStorage getEventCount] > 0) {
        shouldStartRecovery = YES;
        NRVA_LOG(@"Starting offline recovery after successful harvest - backup data detected.");
    }

    if (shouldStartRecovery) {
        self.isRecovering = YES;
        NRVA_LOG(@"Recovery mode activated - offline events will be included in future harvests.");
    }
}

- (void)cleanup {
    [self.memoryBuffer cleanup];
    [self markSessionEnd];
}

- (void)setCapacityCallback:(id<NRVACapacityCallback>)callback {
    [self.memoryBuffer setCapacityCallback:callback];
}

- (void)setOverflowCallback:(id<NRVAOverflowCallback>)callback {
    [self.memoryBuffer setOverflowCallback:callback];
}

#pragma mark - Crash Safety & Recovery

- (void)emergencyBackup {
    dispatch_async(self.crashSafeQueue, ^{
        @try {
            NSArray *liveEvents = [self.memoryBuffer pollBatchByPriority:NSIntegerMax sizeEstimator:nil priority:@"live"];
            NSArray *ondemandEvents = [self.memoryBuffer pollBatchByPriority:NSIntegerMax sizeEstimator:nil priority:@"ondemand"];
            
            NSMutableArray *allEvents = [NSMutableArray array];
            if (liveEvents) [allEvents addObjectsFromArray:liveEvents];
            if (ondemandEvents) [allEvents addObjectsFromArray:ondemandEvents];

            if (allEvents.count > 0) {
                NSData *data = [NSJSONSerialization dataWithJSONObject:allEvents options:0 error:nil];
                if (data && [self.offlineStorage persistDataToDisk:data]) {
                    NRVA_LOG(@"Emergency backup: %ld events saved to disk.", (long)allEvents.count);
                }
            }
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"Emergency backup failed: %@", exception.reason);
        }
    });
}

- (void)backupFailedEvents:(NSArray<NSDictionary<NSString *, id> *> *)failedEvents {
    if (failedEvents == nil || failedEvents.count == 0) return;
    
    dispatch_async(self.crashSafeQueue, ^{
        NSData *data = [NSJSONSerialization dataWithJSONObject:failedEvents options:0 error:nil];
        if (data && [self.offlineStorage persistDataToDisk:data]) {
            if (!self.isRecovering) {
                self.isRecovering = YES;
                NRVA_LOG(@"Recovery mode enabled for %ld failed events.", (long)failedEvents.count);
            }
        }
    });
}

- (NRVARecoveryStats *)getRecoveryStats {
    return [[NRVARecoveryStats alloc] initWithRecovering:self.isRecovering
                                        backupEventCount:[self.offlineStorage getEventCount]
                                        memoryEventCount:[self.memoryBuffer getEventCount]
                                              isTVDevice:self.isTVDevice];
}

#pragma mark - Private: Crash Detection

- (void)updateCrashDetectionCounter {
    [[NSUserDefaults standardUserDefaults] setInteger:self.lastEventCount forKey:kNRVALastEventCountKey];
}

- (void)checkCrashRecovery {
    dispatch_async(self.crashSafeQueue, ^{
        BOOL wasSessionActive = [[NSUserDefaults standardUserDefaults] boolForKey:kNRVASessionActiveKey];

        if (wasSessionActive) {
            if ([self.offlineStorage getEventCount] > 0) {
                self.hasPendingRecovery = YES;
                NRVA_LOG(@"Crash detected - recovery will start after first successful harvest.");
            }
        }
    });
}

- (void)markSessionStart {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kNRVASessionActiveKey];
}

- (void)markSessionEnd {
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kNRVASessionActiveKey];
}

#pragma mark - Private: Helper Methods

- (NSArray<NSDictionary *> *)pollRecoveryEventsForPriority:(NSString *)priority maxSize:(NSInteger)maxSize {
    @try {
        NSMutableArray<NSDictionary *> *batchEvents = [NSMutableArray array];
        NSArray<NSString *> *allFiles = [self.offlineStorage getAllOfflineFileNames];

        // 1. Loop through every available offline file, treating them as a queue.
        for (NSString *filename in allFiles) {
            // 2. If our batch is already full, stop processing more files.
            if (batchEvents.count >= maxSize) {
                break;
            }

            // 3. Calculate how many more events we need to fill the batch.
            NSInteger needed = maxSize - batchEvents.count;
            
            // 4. Read the required number of events from the current file.
            NSArray<NSDictionary *> *eventsFromFile = [self.offlineStorage getUnprocessedEventsFromFile:filename maxEvents:needed];

            if (eventsFromFile.count > 0) {
                [batchEvents addObjectsFromArray:eventsFromFile];
                
                // CRITICAL FIX: DO NOT remove events here - only mark them as read
                // Events will be removed only after successful HTTP transmission
                // This prevents data loss if HTTP harvest fails
                NRVA_DEBUG_LOG(@"🔄 Read %ld events from file %@ (not yet removed)", (long)eventsFromFile.count, filename);
            }
        }
        
        if (batchEvents.count > 0) {
            NRVA_DEBUG_LOG(@"🔄 Polled %ld total recovery events (will be removed after successful harvest)", (long)batchEvents.count);
        }

        // Recovery mode will be ended by onSuccessfulHarvest when storage is actually empty
        
        return [batchEvents copy];

    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Recovery polling failed: %@", exception.reason);
        return @[];
    }
}

- (NSInteger)getOptimalBatchSizeForPriority:(NSString *)priority {
    NSInteger baseSize = [@"live" isEqualToString:priority] ? 50 : 100;
    return self.isTVDevice ? baseSize * 2 : baseSize;
}

@end
