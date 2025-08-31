//
//  NRVACrashSafeEventBuffer.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAEventBufferInterface.h"

@class NRVAVideoConfiguration;
@class NRVAOfflineStorage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Recovery statistics for crash-safe operations.
 */
@interface NRVARecoveryStats : NSObject
@property (nonatomic, assign) BOOL isRecovering;
@property (nonatomic, assign) NSInteger backupEventCount; // Tracks events in offline storage
@property (nonatomic, strong, nullable) NSString *recoveryReason;
@end

/**
 * A crash-safe event buffer that mirrors the robust logic of the Android agent.
 *
 * Features:
 * - Normal operation uses a fast in-memory buffer.
 * - Automatic crash detection via session state flags.
 * - Deferred recovery starts only after the first successful data transmission.
 * - Full backup of in-memory events during emergencies (e.g., app termination).
 * - TV-optimized with periodic background persistence.
 */
@interface NRVACrashSafeEventBuffer : NSObject <NRVAEventBufferInterface>

/**
 * Initialize with configuration and offline storage.
 * @param configuration Video configuration.
 * @param offlineStorage Offline storage for crash recovery.
 */
- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration
                       offlineStorage:(NRVAOfflineStorage *)offlineStorage;

/**
 * CRITICAL: Backs up all in-memory events to disk.
 * This should be called when the app is about to terminate or enter the background.
 */
- (void)emergencyBackup;

/**
 * Backs up events that have failed to send after all retries are exhausted.
 * This will immediately enable recovery mode.
 * @param failedEvents An array of event dictionaries that failed to be sent.
 */
- (void)backupFailedEvents:(NSArray<NSDictionary<NSString *, id> *> *)failedEvents;

/**
 * Get current recovery statistics.
 */
- (NRVARecoveryStats *)getRecoveryStats;

@end

NS_ASSUME_NONNULL_END
