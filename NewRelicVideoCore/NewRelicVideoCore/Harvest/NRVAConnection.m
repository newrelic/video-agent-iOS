//
//  NRVAConnection.m
//  NewRelicVideoCore
//
//  Adapted from NRMAConnection.m
//  Copyright © 2025 New Relic. All rights reserved.
//

#import "NRVAConnection.h"
#import "NRVAUtils.h"

#define kNRVA_TIMEOUT_INTERVAL         20
#define kNRVA_VIDEO_AGENT_VERSION      @"4.0.0"
#define kNRVA_VIDEO_AGENT_NAME         @"NewRelicVideoAgent"

@implementation NRVAConnection

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize applicationVersion with a default value to prevent crashes
        if (!_applicationVersion) {
            NSBundle *mainBundle = [NSBundle mainBundle];
            _applicationVersion = [mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0.0";
        }
    }
    return self;
}

- (NSMutableURLRequest *)newPostWithURI:(NSString *)uri {
    NSMutableURLRequest *postRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:uri]];

    postRequest.HTTPMethod = @"POST";
    postRequest.timeoutInterval = kNRVA_TIMEOUT_INTERVAL;
    [postRequest addValue:@"application/json" forHTTPHeaderField:kNRVA_CONTENT_TYPE_HEADER];

    // Add X-App-License-Key header if application token is available
    if ([self.applicationToken length]) {
        [postRequest addValue:self.applicationToken forHTTPHeaderField:kNRVA_APPLICATION_TOKEN_HEADER];
    }

    // Set User-Agent header to match successful format
    [postRequest setValue:[self videoAgentUserAgent] forHTTPHeaderField:kNRVA_VIDEO_USER_AGENT_HEADER];

    return postRequest;
}

- (NSString *)videoAgentUserAgent {
    NSString *osVersion = [[UIDevice currentDevice] systemVersion];
    NSString *deviceModel = [[UIDevice currentDevice] model];
    
    // Format: AppName/AppVersion (Device; OS Version) AgentName/AgentVersion
    NSString *appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] ?: @"VideoApp";
    
    return [NSString stringWithFormat:@"%@/%@ (%@; %@ %@) %@/%@", 
            appName,
            self.applicationVersion,
            deviceModel,
            [self osName],
            osVersion,
            kNRVA_VIDEO_AGENT_NAME,
            kNRVA_VIDEO_AGENT_VERSION];
}

- (NSString *)osName {
    #if TARGET_OS_TV
        return @"tvOS";
    #else
        return @"iOS";
    #endif
}

- (void)postData:(NSData *)data 
           toURL:(NSString *)urlString 
completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    
    NSMutableURLRequest *request = [self newPostWithURI:urlString];
    if (!request) {
        NSLog(@"[NRVA] ERROR: Failed to create request for URL: %@", urlString);
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"NRVAConnectionDomain" 
                                               code:1001 
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to create request"}];
            completionHandler(nil, nil, error);
        }
        return;
    }
    
    request.HTTPBody = data;
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    config.timeoutIntervalForResource = 60.0;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request 
                                             completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        completionHandler(responseData, response, error);
    }];
    [task resume];
}

- (void)logResponse:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error tag:(NSString *)tag {
    NSString *tagPrefix = tag ? [NSString stringWithFormat:@"[%@] ", tag] : @"";
    
    if (error) {
        NSLog(@"🌐 %@API RESPONSE ERROR: %@", tagPrefix, error.localizedDescription);
        if (error.code == NSURLErrorServerCertificateUntrusted || 
            error.code == NSURLErrorSecureConnectionFailed ||
            [error.localizedDescription containsString:@"SSL"]) {
            NSLog(@"🔒 %@SSL/Certificate Error Details: %@", tagPrefix, error.userInfo);
        }
        return;
    }
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *statusIcon = (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) ? @"✅" : @"❌";
        
        NSLog(@"🌐 %@API RESPONSE %@ %ld: %@", 
                tagPrefix, statusIcon, (long)httpResponse.statusCode, httpResponse.URL.absoluteString);
        
        // Log response data if available and reasonable size
        if (data && data.length > 0) {
            if (data.length < 1024) { // Only log small responses to avoid clutter
                NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (responseString) {
                    NSLog(@"🌐 %@Response Data: %@", tagPrefix, responseString);
                } else {
                    NSLog(@"🌐 %@Response Data: <binary data: %lu bytes>", tagPrefix, (unsigned long)data.length);
                }
            } else {
                NSLog(@"🌐 %@Response Data: <large response: %lu bytes>", tagPrefix, (unsigned long)data.length);
            }
        }
    }
}

@end
