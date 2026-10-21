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
 * Buffer-capacity logging. Emitted through os_log (also in release builds) when debug logging is
 * enabled and the message severity is at or above the level set with +setBufferLoggingLevel:.
 * WARNING maps to the default os_log type, which has no dedicated warning type.
 */
void NRVA_BUFFER_LOG(NRVALoggingLevel level, NSString *format, ...);

/**
 * Set the minimum level of buffer-capacity logs
 */
+ (void)setBufferLoggingLevel:(NRVALoggingLevel)level;

/**
 * Set logging enabled state
 */
+ (void)setLoggingEnabled:(BOOL)enabled;

/**
 * Get current logging state
 */
+ (BOOL)isLoggingEnabled;

@end
