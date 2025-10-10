//
//  NRVAHarvestComponentFactory.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NRVAEventBufferInterface;
@protocol NRVAHttpClientInterface;
@protocol NRVASchedulerInterface;
@class NRVAVideoConfiguration;
@class NRVAIntegratedDeadLetterHandler;

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for creating harvest-related components
 * Uses dependency injection pattern for better testability
 * Optimized for mobile/TV environments
 */
@protocol NRVAHarvestComponentFactory <NSObject>

/**
 * Gets the configuration for other components
 */
- (NRVAVideoConfiguration *)getConfiguration;

/**
 * Cleanup resources
 */
- (void)cleanup;

- (id<NRVAEventBufferInterface>)getEventBuffer;
- (id<NRVAHttpClientInterface>)getHttpClient;
- (id<NRVASchedulerInterface>)getScheduler;
- (NRVAIntegratedDeadLetterHandler *)getDeadLetterHandler;
- (void)performEmergencyBackup;
- (BOOL)isRecovering;
- (NSString *)getRecoveryStats;

@end

NS_ASSUME_NONNULL_END