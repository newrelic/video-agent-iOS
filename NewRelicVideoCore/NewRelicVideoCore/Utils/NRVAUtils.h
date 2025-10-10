//
//  NRVAUtils.h
//  NewRelicVideoCore
//
//  Video agent utility functions
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NRVAUtils : NSObject

/**
 * Get the current device type (TV vs Mobile)
 */
+ (BOOL)isTVDevice;

/**
 * Get OS name string
 */
+ (NSString *)osName;

/**
 * Get device model string
 */
+ (NSString *)deviceModel;

/**
 * Generate unique identifier for sessions
 */
+ (NSString *)generateSessionId;

@end
