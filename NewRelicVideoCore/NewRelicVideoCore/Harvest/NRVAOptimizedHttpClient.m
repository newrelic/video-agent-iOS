//
//  NRVAOptimizedHttpClient.m
//  NewRelicVideoCore
//
//  Created by New Relic Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVAOptimizedHttpClient.h"
#import "NRVAVideoConfiguration.h"
#import "NRVATokenManager.h"
#import "NRVAUtils.h"
#import "NRVALog.h"

static const int kMaxRetryAttempts = 3;

@interface NRVAOptimizedHttpClient ()

@property (nonatomic, strong) NRVAVideoConfiguration *configuration;
@property (nonatomic, strong) NRVATokenManager *tokenManager;
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, strong) NSString *endpointUrl;

@end

@implementation NRVAOptimizedHttpClient

- (instancetype)initWithConfiguration:(NRVAVideoConfiguration *)configuration {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _tokenManager = [[NRVATokenManager alloc] initWithConfiguration:configuration];
        
        // Set endpoint URL based on region - matches Android exactly
        _endpointUrl = [self buildEndpointUrl];
        
        // Create optimized URL session configuration
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.timeoutIntervalForRequest = 30.0;
        sessionConfig.timeoutIntervalForResource = 60.0;
        sessionConfig.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        
        // Align connection pool size with Android
        sessionConfig.HTTPMaximumConnectionsPerHost = 5;
        
        // Device-specific optimizations
        if (configuration.isTV) {
            sessionConfig.timeoutIntervalForRequest = 100.0; // TV can wait longer
        }
        else if (configuration.memoryOptimized) {
            sessionConfig.timeoutIntervalForRequest = 6.0; // Faster timeout for low memory
        }
        
        _urlSession = [NSURLSession sessionWithConfiguration:sessionConfig];
        
        NRVA_DEBUG_LOG(@"Optimized HTTP client initialized for %@ - Endpoint: %@",
                      configuration.isTV ? @"TV" : @"Mobile", _endpointUrl);
    }
    return self;
}

- (void)sendEvents:(NSArray<NSDictionary<NSString *, id> *> *)events
       harvestType:(NSString *)harvestType
        completion:(void (^)(BOOL success))completion {
    if (!events || events.count == 0) {
        if (completion) completion(YES); // Nothing to send is considered success
        return;
    }
    
    // Kick off the send process with retry logic
    [self sendEventsAsyncWithRetry:events attempt:0 completion:completion];
}

#pragma mark - Private Send Logic with Retry

- (void)sendEventsAsyncWithRetry:(NSArray<NSDictionary<NSString *, id> *> *)events
                           attempt:(int)attempt
                      completion:(void (^)(BOOL success))completion {
    
    // Base case: If we've exceeded max attempts, fail out
    if (attempt >= kMaxRetryAttempts) {
        NRVA_ERROR_LOG(@"All %d immediate attempts failed for %lu events. Queuing for next harvest.", kMaxRetryAttempts, (unsigned long)events.count);
        if (completion) completion(NO);
        return;
    }
    
    if (attempt > 0) {
        NRVA_DEBUG_LOG(@"Immediate retry %d/%d (no delay for mobile/TV performance)", attempt + 1, kMaxRetryAttempts);
    }
    
    // Get app token first
    [self.tokenManager getAppTokenWithCompletion:^(NSArray<NSNumber *> *appToken, NSError *tokenError) {
        if (tokenError || !appToken) {
            NRVA_ERROR_LOG(@"Failed to get app token: %@", tokenError.localizedDescription);
            if (completion) completion(NO);
            return;
        }
        
        @try {
            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.endpointUrl]];
            [request setHTTPMethod:@"POST"];
            [request setTimeoutInterval:self.configuration.isTV ? 100.0 : 30.0];
            
            [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
            [request setValue:[self createUserAgent] forHTTPHeaderField:@"User-Agent"];
            [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
            [request setValue:self.configuration.applicationToken forHTTPHeaderField:@"X-App-License-Key"];
            
            NSArray *payload = [self buildCompletePayload:appToken events:events];
            
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
            
            if (jsonError) {
                NRVA_ERROR_LOG(@"Failed to serialize payload: %@", jsonError.localizedDescription);
                if (completion) completion(NO);
                return;
            }
            
            [request setHTTPBody:jsonData];
            
            NSURLSessionDataTask *dataTask = [self.urlSession dataTaskWithRequest:request
                                                                 completionHandler:^(NSData *data, NSURLResponse *urlResponse, NSError *error) {
                [self handleResponse:data
                            response:urlResponse
                               error:error
                              events:events
                             attempt:attempt
                          completion:completion];
            }];
            
            [dataTask resume];
            
        } @catch (NSException *exception) {
            NRVA_ERROR_LOG(@"HTTP client exception on attempt %d: %@", attempt + 1, exception.reason);
            [self sendEventsAsyncWithRetry:events attempt:attempt + 1 completion:completion];
        }
    }];
}

- (void)handleResponse:(NSData *)data
              response:(NSURLResponse *)urlResponse
                 error:(NSError *)error
                events:(NSArray *)events
               attempt:(int)attempt
            completion:(void (^)(BOOL success))completion {
    
    if (error) {
        NRVA_ERROR_LOG(@"HTTP request failed on attempt %d: %@", attempt + 1, error.localizedDescription);
        [self sendEventsAsyncWithRetry:events attempt:attempt + 1 completion:completion];
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)urlResponse;
    NSInteger statusCode = httpResponse.statusCode;
    
    if (statusCode >= 200 && statusCode < 300) {
        NRVA_DEBUG_LOG(@"✅ Successfully sent %lu events on attempt %d - Status: %ld",
                      (unsigned long)events.count, attempt + 1, (long)statusCode);
        if (completion) completion(YES);
        return;
    }
    
    NRVA_ERROR_LOG(@"❌ HTTP request failed on attempt %d with status: %ld", attempt + 1, (long)statusCode);
    
    if (statusCode == 401 || statusCode == 403) {
        NRVA_ERROR_LOG(@"Authentication failed. Refreshing token and retrying.");
        [self.tokenManager refreshTokenWithCompletion:nil];
        [self sendEventsAsyncWithRetry:events attempt:attempt + 1 completion:completion];
    }
    else if (statusCode == 429) {
        NSTimeInterval delay = [self parseRetryAfterHeader:httpResponse];
        NRVA_ERROR_LOG(@"Rate limit exceeded. Server requested retry after %.1f seconds. Deferring to next harvest.", delay);
        if (completion) completion(NO);
    }
    else if (statusCode >= 500) {
        NRVA_ERROR_LOG(@"Server error (status: %ld). Retrying...", (long)statusCode);
        [self sendEventsAsyncWithRetry:events attempt:attempt + 1 completion:completion];
    }
    else {
        // For other client errors (4xx), don't retry as the request is likely invalid.
        NRVA_ERROR_LOG(@"Request failed with unrecoverable client error status: %ld", (long)statusCode);
        if (completion) completion(NO);
    }
}

#pragma mark - Helper Methods

/**
 * Parses the 'Retry-After' header value to seconds, matching Android's logic.
 * Supports delay-seconds format.
 * @param httpResponse The HTTP response containing the headers.
 * @return The delay in seconds, capped at 5 minutes, or a default of 60 seconds.
 */
- (NSTimeInterval)parseRetryAfterHeader:(NSHTTPURLResponse *)httpResponse {
    NSString *retryAfterString = [httpResponse valueForHTTPHeaderField:@"Retry-After"];
    
    // Default to 60 seconds if header is missing, per Android logic
    if (!retryAfterString || [retryAfterString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
        return 60.0;
    }
    
    // Try parsing as seconds (most common format)
    double delayInSeconds = [retryAfterString doubleValue];
    
    // If parsing fails (returns 0 for non-numeric string), use default. Otherwise, use parsed value.
    if (delayInSeconds <= 0) {
        return 60.0;
    }
    
    // Cap at 5 minutes (300 seconds) to match Android
    return MIN(delayInSeconds, 300.0);
}

- (NSArray *)buildCompletePayload:(NSArray<NSNumber *> *)appToken events:(NSArray<NSDictionary<NSString *, id> *> *)events {
    NSString *osName = [NRVAUtils osName];
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *architecture = [self getArchitecture];
    NSString *agentName = @"NewRelic-VideoAgent-iOS";
    NSString *agentVersion = @"4.0.0";
    NSString *deviceId = [NRVAUtils generateSessionId];
    NSString *manufacturer = @"Apple";
    
    NSDictionary *deviceMetadata = @{
        @"size": [self getDeviceSize],
        @"platform": @"iOS",
        @"platformVersion": osVersion
    };
    
    NSArray *deviceInfo = @[
        osName,
        osVersion,
        architecture,
        agentName,
        agentVersion,
        deviceId,
        @"", // carrier (not used)
        @"", // network type (not used)
        manufacturer,
        deviceMetadata
    ];
    
    // Build complete payload array - EXACTLY matches Android structure
    NSArray *payload = @[
        appToken,                          // First: data token array
        deviceInfo,                        // Second: device information array
        @0,                               // Third: timestamp (0)
        @[],                              // Fourth: empty array
        @[],                              // Fifth: empty array
        @[],                              // Sixth: empty array
        @[],                              // Seventh: empty array
        @[],                              // Eighth: empty array
        @{},                              // Ninth: empty dictionary
        events                            // Tenth: events array
    ];
    
    return payload;
}

- (NSString *)buildEndpointUrl {
    NSString *region = self.configuration.region.uppercaseString;
    
    if ([region isEqualToString:@"EU"]) {
        return @"https://mobile-collector.eu.newrelic.com/mobile/v3/data";
    } else if ([region isEqualToString:@"AP"]) {
        return @"https://mobile-collector.ap.newrelic.com/mobile/v3/data";
    } else if ([region isEqualToString:@"GOV"]) {
        return @"https://mobile-collector.gov.newrelic.com/mobile/v3/data";
    } else if ([region isEqualToString:@"STAGING"]) {
        return @"https://mobile-collector.staging.newrelic.com/mobile/v3/data";
    } else {
        return @"https://mobile-collector.newrelic.com/mobile/v3/data"; // US/DEFAULT
    }
}

- (NSString *)createUserAgent {
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *deviceModel = [[UIDevice currentDevice] model];
    
    return [NSString stringWithFormat:@"NewRelic-VideoAgent-iOS/1.0.0 (%@; %@ %@)", 
            deviceModel, [NRVAUtils osName], osVersion];
}

- (NSString *)getArchitecture {
    #if TARGET_CPU_ARM64
        return @"arm64";
    #elif TARGET_CPU_X86_64
        return @"x86_64";
    #else
        return @"unknown";
    #endif
}

- (NSString *)getDeviceSize {
    if ([NRVAUtils isTVDevice]) {
        return @"large";
    } else {
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = MAX(screenBounds.size.width, screenBounds.size.height);
        
        if (screenWidth >= 768) {
            return @"large"; // iPad
        } else {
            return @"normal"; // iPhone
        }
    }
}

@end