//
//  NRVALog.h
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

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
 * Set logging enabled state
 */
+ (void)setLoggingEnabled:(BOOL)enabled;

/**
 * Get current logging state
 */
+ (BOOL)isLoggingEnabled;

@end
