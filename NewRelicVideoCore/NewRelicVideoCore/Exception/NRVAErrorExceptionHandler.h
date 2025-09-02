//
//  NRVAErrorExceptionHandler.h
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Unified error handling for AVPlayer, IMA ads, and network errors
 * Provides standardized error codes and messages for consistent reporting
 */
@interface NRVAErrorExceptionHandler : NSObject

/**
 * Initialize with an error or exception
 * @param error The error or exception to handle
 */
- (instancetype)initWithError:(NSError *)error;

/**
 * Initialize with an exception
 * @param exception The exception to handle
 */
- (instancetype)initWithException:(NSException *)exception;

/**
 * Get standardized error code
 */
@property (nonatomic, readonly) NSInteger errorCode;

/**
 * Get standardized error message
 */
@property (nonatomic, readonly) NSString *errorMessage;

/**
 * Get error domain for categorization
 */
@property (nonatomic, readonly) NSString *errorDomain;

@end

NS_ASSUME_NONNULL_END