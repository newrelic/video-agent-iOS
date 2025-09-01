//
//  NRVACrashSafeHarvestFactory.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVACrashSafeHarvestFactory.h"
#import "NRVAVideoConfiguration.h"
#import "NRVACrashSafeEventBuffer.h"
#import "NRVAIntegratedDeadLetterHandler.h"
#import "NRVAOptimizedHttpClient.h"
#import "NRVAMultiTaskHarvestScheduler.h"
#import "NRVAOfflineStorage.h"
#import "NRVALog.h"

@interface NRVACrashSafeHarvestFactory ()

@property (nonatomic, strong) NRVAVideoConfiguration *configuration;
@property (nonatomic, strong) NRVACrashSafeEventBuffer *crashSafeBuffer;
@property (nonatomic, strong) NRVAIntegratedDeadLetterHandler *integratedHandler;
@property (nonatomic, strong) id<NRVAHttpClientInterface> httpClient;
@property (nonatomic, strong) id<NRVASchedulerInterface> scheduler;
@property (nonatomic, strong) NRVAOfflineStorage *offlineStorage;

@end

// Wrapper class for overflow callback
@interface NRVAOverflowCallbackWrapper : NSObject <NRVAOverflowCallback>
@property (nonatomic, copy) void(^overflowBlock)(NSString *bufferType);
@end

@implementation NRVAOverflowCallbackWrapper
- (instancetype)initWithBlock:(void(^)(NSString *bufferType))block {
    self = [super init];
    if (self) {
        _overflowBlock = block;
    }
    return self;
}

- (void)onBufferNearFull:(NSString *)bufferType {
    if (self.overflowBlock) {
        self.overflowBlock(bufferType);
    }
}
@end

// Wrapper class for capacity callback
@interface NRVACapacityCallbackWrapper : NSObject <NRVACapacityCallback>
@property (nonatomic, copy) void(^capacityBlock)(double capacity, NSString *bufferType);
@end

@implementation NRVACapacityCallbackWrapper
- (instancetype)initWithBlock:(void(^)(double capacity, NSString *bufferType))block {
    self = [super init];
    if (self) {
        _capacityBlock = block;
    }
    return self;
}

- (void)onCapacityThresholdReached:(double)currentCapacity bufferType:(NSString *)bufferType {
    if (self.capacityBlock) {
        self.capacityBlock(currentCapacity, bufferType);
    }
}
@end

@implementation NRVACrashSafeHarvestFactory

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration
                      overflowCallback:(void(^)(NSString *bufferType))overflowCallback
                      capacityCallback:(void(^)(double capacity, NSString *bufferType))capacityCallback
                         onDemandTask:(void(^)(void))onDemandTask
                             liveTask:(void(^)(void))liveTask {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _offlineStorage = [[NRVAOfflineStorage alloc] initWithEndpoint:@"crash-safe-events" 
                                                       maxStorageSizeMB:configuration.maxOfflineStorageSizeMB];
        
        _crashSafeBuffer = [[NRVACrashSafeEventBuffer alloc] initWithConfiguration:configuration
                                                                    offlineStorage:_offlineStorage];
        _httpClient = [[NRVAOptimizedHttpClient alloc] initWithConfiguration:configuration];
        _integratedHandler = [[NRVAIntegratedDeadLetterHandler alloc] initWithMainBuffer:_crashSafeBuffer
                                                                               httpClient:_httpClient
                                                                            configuration:configuration];
        _scheduler = [[NRVAMultiTaskHarvestScheduler alloc] initWithOnDemandTask:onDemandTask
                                                                        liveTask:liveTask
                                                                   configuration:configuration];
        
        // Set callbacks for buffer capacity monitoring using wrapper objects
        if (overflowCallback) {
            NRVAOverflowCallbackWrapper *overflowWrapper = [[NRVAOverflowCallbackWrapper alloc] initWithBlock:overflowCallback];
            [_crashSafeBuffer setOverflowCallback:overflowWrapper];
        }
        
        if (capacityCallback) {
            NRVACapacityCallbackWrapper *capacityWrapper = [[NRVACapacityCallbackWrapper alloc] initWithBlock:capacityCallback];
            [_crashSafeBuffer setCapacityCallback:capacityWrapper];
        }
        
        NRVA_DEBUG_LOG(@"CrashSafeHarvestFactory initialized successfully");
    }
    return self;
}

#pragma mark - NRVAHarvestComponentFactory Protocol

- (NRVAVideoConfiguration *)getConfiguration {
    return self.configuration;
}

- (void)cleanup {
    [self.crashSafeBuffer cleanup];
    NRVA_DEBUG_LOG(@"CrashSafeHarvestFactory cleaned up successfully");
}

- (id<NRVAEventBufferInterface>)getEventBuffer {
    return self.crashSafeBuffer;
}

- (id<NRVAHttpClientInterface>)getHttpClient {
    return self.httpClient;
}

- (id<NRVASchedulerInterface>)getScheduler {
    return self.scheduler;
}

- (NRVAIntegratedDeadLetterHandler *)getDeadLetterHandler {
    return self.integratedHandler;
}

- (void)performEmergencyBackup {
    @try {
        [self.crashSafeBuffer emergencyBackup];
        [self.integratedHandler emergencyBackup];
    } @catch (NSException *exception) {
        NRVA_ERROR_LOG(@"Emergency backup failed: %@", exception.reason);
    }
}

- (BOOL)isRecovering {
    return [self.crashSafeBuffer getRecoveryStats].isRecovering;
}

- (NSString *)getRecoveryStats {
    return [[self.crashSafeBuffer getRecoveryStats] description];
}

@end