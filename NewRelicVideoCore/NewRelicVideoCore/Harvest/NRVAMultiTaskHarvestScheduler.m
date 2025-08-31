//
//  NRVAMultiTaskHarvestScheduler.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAMultiTaskHarvestScheduler.h"
#import "NRVAVideoConfiguration.h"
#import "NRVALog.h"

static NSString * const kHarvestQueueLabel = @"com.newrelic.videoagent.harvest";
static NSString * const kLiveBufferType = @"live";
static NSString * const kOnDemandBufferType = @"ondemand";

static const NSTimeInterval kInitialLiveDelaySeconds = 0.5;
static const NSTimeInterval kInitialOnDemandDelaySeconds = 1.0;


@interface NRVAMultiTaskHarvestScheduler ()

@property (nonatomic, strong) dispatch_queue_t backgroundQueue;
@property (nonatomic, copy) void(^onDemandHarvestTask)(void);
@property (nonatomic, copy) void(^liveHarvestTask)(void);
@property (nonatomic, assign) NSTimeInterval onDemandIntervalSeconds;
@property (nonatomic, assign) NSTimeInterval liveIntervalSeconds;
@property (nonatomic, assign) BOOL isAppleTVDevice;

@property (nonatomic, strong, nullable) dispatch_source_t onDemandTimerSource;
@property (nonatomic, strong, nullable) dispatch_source_t liveTimerSource;

@property (atomic, assign) BOOL isOnDemandRunning;
@property (atomic, assign) BOOL isLiveRunning;
@property (atomic, assign) BOOL isShutdown;

@end

@implementation NRVAMultiTaskHarvestScheduler

- (instancetype)initWithOnDemandTask:(void(^)(void))onDemandTask
                            liveTask:(void(^)(void))liveTask
                       configuration:(NRVAVideoConfiguration *)configuration {
    self = [super init];
    if (self) {
        _onDemandHarvestTask = [onDemandTask copy];
        _liveHarvestTask = [liveTask copy];
        _onDemandIntervalSeconds = configuration.harvestCycleSeconds;
        _liveIntervalSeconds = configuration.liveHarvestCycleSeconds;
        _isAppleTVDevice = configuration.isTV;
        
        dispatch_qos_class_t qosClass = _isAppleTVDevice ? QOS_CLASS_DEFAULT : QOS_CLASS_BACKGROUND;
        _backgroundQueue = dispatch_queue_create([kHarvestQueueLabel UTF8String],
                                                dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, qosClass, 0));
        
        NRVA_DEBUG_LOG(@"Scheduler initialized for %@ - OnDemand: %.0fs, Live: %.0fs",
                      _isAppleTVDevice ? @"TV" : @"Mobile", _onDemandIntervalSeconds, _liveIntervalSeconds);
    }
    return self;
}

- (void)dealloc {
    [self stopAllSchedulers];
}

- (void)start {
    [self startWithBufferType:kOnDemandBufferType];
    [self startWithBufferType:kLiveBufferType];
}

- (void)startWithBufferType:(NSString *)bufferType {
    if (self.isShutdown) {
        NRVA_ERROR_LOG(@"Cannot start %@ scheduler - already shutdown", bufferType);
        return;
    }
    
    if ([bufferType isEqualToString:kLiveBufferType]) {
        if (!self.isLiveRunning) {
            self.isLiveRunning = YES;
            [self setupTimerForBufferType:kLiveBufferType initialDelay:kInitialLiveDelaySeconds interval:self.liveIntervalSeconds];
            NRVA_DEBUG_LOG(@"Live scheduler started with immediate harvest");
        }
    } else if ([bufferType isEqualToString:kOnDemandBufferType]) {
        if (!self.isOnDemandRunning) {
            self.isOnDemandRunning = YES;
            [self setupTimerForBufferType:kOnDemandBufferType initialDelay:kInitialOnDemandDelaySeconds interval:self.onDemandIntervalSeconds];
            NRVA_DEBUG_LOG(@"OnDemand scheduler started with quick first harvest");
        }
    }
}

- (void)shutdown {
    if (self.isShutdown) return;
    self.isShutdown = YES;
    
    NRVA_DEBUG_LOG(@"Shutting down scheduler");
    [self stopAllSchedulers];
    [self executeImmediateHarvest:@"SHUTDOWN"];
}

- (void)forceHarvest {
    [self executeImmediateHarvest:@"FORCE_HARVEST"];
}

- (BOOL)isRunning {
    return !self.isShutdown && (self.isOnDemandRunning || self.isLiveRunning);
}

- (void)pause {
    if (self.isShutdown) return;
    NRVA_DEBUG_LOG(@"Pausing scheduler");
    [self stopAllSchedulers];
}

- (void)resume:(BOOL)useExtendedIntervals {
    if (self.isShutdown) return;
    NRVA_DEBUG_LOG(@"Resuming scheduler - Extended intervals: %@", useExtendedIntervals ? @"YES" : @"NO");
    
    [self stopAllSchedulers];
    
    BOOL isExtended = useExtendedIntervals && self.isAppleTVDevice;
    
    if (self.isOnDemandRunning) {
        NSTimeInterval interval = isExtended ? self.onDemandIntervalSeconds * 2 : self.onDemandIntervalSeconds;
        [self setupTimerForBufferType:kOnDemandBufferType initialDelay:kInitialOnDemandDelaySeconds interval:interval];
    }
    if (self.isLiveRunning) {
        NSTimeInterval interval = isExtended ? self.liveIntervalSeconds * 2 : self.liveIntervalSeconds;
        [self setupTimerForBufferType:kLiveBufferType initialDelay:kInitialLiveDelaySeconds interval:interval];
    }
}

#pragma mark - Private Helper Methods

- (void)setupTimerForBufferType:(NSString *)bufferType initialDelay:(NSTimeInterval)initialDelay interval:(NSTimeInterval)interval {
    dispatch_source_t timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.backgroundQueue);
    
    dispatch_source_set_timer(timerSource,
                              dispatch_walltime(NULL, initialDelay * NSEC_PER_SEC),
                              interval * NSEC_PER_SEC,
                              (interval * NSEC_PER_SEC) * 0.1);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(timerSource, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        @try {
            if ([bufferType isEqualToString:kLiveBufferType] && strongSelf.liveHarvestTask) {
                strongSelf.liveHarvestTask();
            } else if ([bufferType isEqualToString:kOnDemandBufferType] && strongSelf.onDemandHarvestTask) {
                strongSelf.onDemandHarvestTask();
            }
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"%@ harvest task failed: %@", bufferType, exception.reason);
        }
    });

    if ([bufferType isEqualToString:kLiveBufferType]) {
        self.liveTimerSource = timerSource;
    } else if ([bufferType isEqualToString:kOnDemandBufferType]) {
        self.onDemandTimerSource = timerSource;
    }
    dispatch_resume(timerSource);
}

- (void)executeImmediateHarvest:(NSString *)reason {
    NRVA_DEBUG_LOG(@"Executing immediate harvest - Reason: %@", reason);
    
    dispatch_sync(self.backgroundQueue, ^{
        @try {
            if (self.onDemandHarvestTask) self.onDemandHarvestTask();
            if (self.liveHarvestTask) self.liveHarvestTask();
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"Immediate harvest failed for reason: %@ - %@", reason, exception.reason);
        }
    });
}

- (void)stopAllSchedulers {
    if (self.onDemandTimerSource) {
        dispatch_source_cancel(self.onDemandTimerSource);
        self.onDemandTimerSource = nil;
    }
    if (self.liveTimerSource) {
        dispatch_source_cancel(self.liveTimerSource);
        self.liveTimerSource = nil;
    }
}

@end