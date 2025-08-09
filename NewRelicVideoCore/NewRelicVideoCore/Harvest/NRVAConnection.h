//
//  NRVAConnection.h
//  NewRelicVideoCore
//
//  Adapted from NRMAConnection.h
//  Copyright © 2025 New Relic. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRVAConnectInformation;

// Video agent specific constants
#define kNRVA_APPLICATION_TOKEN_HEADER      @"X-App-License-Key"
#define kNRVA_VIDEO_USER_AGENT_HEADER       @"User-Agent"
#define kNRVA_CONTENT_TYPE_HEADER           @"Content-Type"
#define kNRVA_APP_VERSION_HEADER            @"X-NewRelic-App-Version"
#define kNRVA_OS_NAME_HEADER                @"X-NewRelic-OS-Name"

@interface NRVAConnection : NSObject

@property(strong, nonatomic) NSString *applicationToken;
@property(strong, nonatomic) NSString *applicationVersion;
@property(assign, nonatomic) BOOL useSSL;

/**
 * Creates a new POST request with the given URI and video agent headers
 * @param uri The URI for the request
 * @return Configured NSURLRequest for video agent use
 */
- (NSMutableURLRequest *)newPostWithURI:(NSString *)uri;

/**
 * Get the video agent user agent string
 * @return User agent string identifying this as the video agent
 */
- (NSString *)videoAgentUserAgent;

/**
 * Get the current OS name for headers
 * @return OS name string (iOS/tvOS)
 */
- (NSString *)osName;

/**
 * Post data to URL with completion handler
 * @param data The data to post
 * @param urlString The URL string
 * @param completionHandler Completion handler for response
 */
- (void)postData:(NSData *)data 
           toURL:(NSString *)urlString 
completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

@end
