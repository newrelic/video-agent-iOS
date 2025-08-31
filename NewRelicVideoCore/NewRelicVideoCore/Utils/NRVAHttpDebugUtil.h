//
//  NRVAHttpDebugUtil.h
//  NewRelicVideoCore
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Utility class for debugging HTTP requests and responses.
 * Provides functionality to log requests as curl commands and log response details.
 */
@interface NRVAHttpDebugUtil : NSObject

/**
 * Logs an HTTP request as a curl command for debugging purposes.
 * @param request The NSURLRequest to log
 * @param tag Optional tag to prefix the log message (e.g., "TOKEN", "HARVEST")
 */
+ (void)logRequestAsCurl:(NSURLRequest *)request tag:(nullable NSString *)tag;

/**
 * Logs HTTP response details including status code, headers, and response data.
 * @param response The NSURLResponse received
 * @param data The response data received
 * @param error Any error that occurred during the request
 * @param tag Optional tag to prefix the log message (e.g., "TOKEN", "HARVEST")
 */
+ (void)logResponse:(nullable NSURLResponse *)response 
               data:(nullable NSData *)data 
              error:(nullable NSError *)error 
                tag:(nullable NSString *)tag;

@end

NS_ASSUME_NONNULL_END