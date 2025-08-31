//
//  NRVAIntegratedDeadLetterHandler.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVACrashSafeEventBuffer;
@class NRVAVideoConfiguration;
@protocol NRVAHttpClientInterface;

NS_ASSUME_NONNULL_BEGIN

/**
 * An integrated handler for events that fail to send.
 * This architecture is equivalent to the Android implementation.
 */
@interface NRVAIntegratedDeadLetterHandler : NSObject

/**
 * Initialize with the main event buffer, HTTP client, and configuration.
 * @param mainBuffer The central crash-safe buffer used for long-term backup.
 * @param httpClient The HTTP client (stored for the component that will perform the retry).
 * @param configuration The video configuration for device-specific settings.
 */
- (instancetype)initWithMainBuffer:(NRVACrashSafeEventBuffer *)mainBuffer
                        httpClient:(id<NRVAHttpClientInterface>)httpClient
                     configuration:(NRVAVideoConfiguration *)configuration;

/**
 * Handles failed events by sorting them for either in-memory retry or immediate backup.
 * @param failedEvents An array of event dictionaries that failed to be sent.
 * @param harvestType The type of harvest ("live" or "ondemand").
 */
- (void)handleFailedEvents:(NSArray<NSDictionary<NSString *, id> *> *)failedEvents harvestType:(NSString *)harvestType;

/**
 * Backs up any events pending an in-memory retry to the main crash-safe buffer.
 * This should be called when the app is about to terminate.
 */
- (void)emergencyBackup;

/**
 * Get the number of events currently in the in-memory retry queue.
 */
- (NSInteger)inMemoryRetryQueueSize;

@end

NS_ASSUME_NONNULL_END