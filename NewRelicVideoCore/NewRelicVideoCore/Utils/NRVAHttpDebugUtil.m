//
//  NRVAHttpDebugUtil.m
//  NewRelicVideoCore
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAHttpDebugUtil.h"
#import "NRVALog.h"

@implementation NRVAHttpDebugUtil

+ (void)logRequestAsCurl:(NSURLRequest *)request tag:(nullable NSString *)tag {
    if (!request) return;
    
    NSMutableString *curlCommand = [NSMutableString stringWithString:@"curl"];
    
    // Add HTTP method
    NSString *method = request.HTTPMethod ?: @"GET";
    if (![method isEqualToString:@"GET"]) {
        [curlCommand appendFormat:@" -X %@", method];
    }
    
    // Add headers
    NSDictionary *headers = request.allHTTPHeaderFields;
    for (NSString *key in headers) {
        NSString *value = headers[key];
        [curlCommand appendFormat:@" -H \"%@: %@\"", key, value];
    }
    
    // Add body data for POST/PUT requests
    if (request.HTTPBody) {
        NSString *bodyString = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        if (bodyString) {
            // Escape quotes in JSON
            bodyString = [bodyString stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            [curlCommand appendFormat:@" -d \"%@\"", bodyString];
        } else {
            [curlCommand appendFormat:@" -d '<binary data: %lu bytes>'", (unsigned long)request.HTTPBody.length];
        }
    }
    
    // Add URL (should be last)
    [curlCommand appendFormat:@" \"%@\"", request.URL.absoluteString];
    
    // Log with tag
    NSString *tagPrefix = tag ? [NSString stringWithFormat:@"[%@] ", tag] : @"";
    NRVA_DEBUG_LOG(@"🌐 %@API REQUEST:\n%@", tagPrefix, curlCommand);
}

+ (void)logResponse:(nullable NSURLResponse *)response 
               data:(nullable NSData *)data 
              error:(nullable NSError *)error 
                tag:(nullable NSString *)tag {
    NSString *tagPrefix = tag ? [NSString stringWithFormat:@"[%@] ", tag] : @"";
    
    if (error) {
        NRVA_ERROR_LOG(@"🌐 %@API RESPONSE ERROR: %@", tagPrefix, error.localizedDescription);
        if (error.code == NSURLErrorServerCertificateUntrusted || 
            error.code == NSURLErrorSecureConnectionFailed ||
            [error.localizedDescription containsString:@"SSL"]) {
            NRVA_ERROR_LOG(@"🔒 %@SSL/Certificate Error Details: %@", tagPrefix, error.userInfo);
        }
        return;
    }
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *statusIcon = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) ? @"✅" : @"❌";
        
        NRVA_DEBUG_LOG(@"🌐 %@API RESPONSE %@ %ld: %@", 
                tagPrefix, statusIcon, (long)httpResponse.statusCode, httpResponse.URL.absoluteString);
        
        // Log response data if available and reasonable size
        if (data && data.length > 0) {
            if (data.length < 1024) { // Only log small responses to avoid clutter
                NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (responseString) {
                    NRVA_DEBUG_LOG(@"🌐 %@Response Data: %@", tagPrefix, responseString);
                } else {
                    NRVA_DEBUG_LOG(@"🌐 %@Response Data: <binary data: %lu bytes>", tagPrefix, (unsigned long)data.length);
                }
            } else {
                NRVA_DEBUG_LOG(@"🌐 %@Response Data: <large response: %lu bytes>", tagPrefix, (unsigned long)data.length);
            }
        }
    }
}

@end