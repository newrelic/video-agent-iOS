//
//  NRVALog.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NRVAVideoConfiguration.h"

@interface NRVALog : NSObject

/**
 * Debug logging (only when debug logging is enabled)
 */
void NRVA_DEBUG_LOG(NSString *format, ...);

/**
 * Error logging (always enabled)
 */
void NRVA_ERROR_LOG(NSString *format, ...);

/**
 * Buffer-capacity logging. Emitted through os_log (also in release builds) when enabled with
 * +setBufferLoggingEnabled:level: and the message severity is at or above the configured level.
 * WARNING maps to the default os_log type, which has no dedicated warning type.
 */
void NRVA_BUFFER_LOG(NRVALoggingLevel level, NSString *format, ...);

/**
 * Configure buffer-capacity logging
 */
+ (void)setBufferLoggingEnabled:(BOOL)enabled level:(NRVALoggingLevel)level;

/**
 * Observe every buffer-capacity message that passes the filter (used by tests). Pass nil to remove.
 */
+ (void)setBufferLogObserver:(void (^)(NRVALoggingLevel level, NSString *message))observer;

/**
 * Set logging enabled state
 */
+ (void)setLoggingEnabled:(BOOL)enabled;

/**
 * Get current logging state
 */
+ (BOOL)isLoggingEnabled;

@end
