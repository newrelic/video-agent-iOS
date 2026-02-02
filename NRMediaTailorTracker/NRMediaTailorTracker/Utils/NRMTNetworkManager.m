//
//  NRMTNetworkManager.m
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import "NRMTNetworkManager.h"
#import "NRMTTrackingResponse.h"
#import "NRMTUtilities.h"

@implementation NRMTNetworkManager

+ (NSURLSessionDataTask *)fetchHLSMasterManifest:(NSURL *)url
                                      completion:(void (^)(NSString * _Nullable, NSURL * _Nullable, NSError * _Nullable))completion {
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
            completion(nil, nil, error);
        }
        return nil;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task = [session dataTaskWithURL:url
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@ Master manifest fetch error: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            if (completion) {
                completion(nil, nil, error);
            }
            return;
        }

        NSString *manifestText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!manifestText) {
            NSError *parseError = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                      code:-2
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse manifest text"}];
            if (completion) {
                completion(nil, nil, parseError);
            }
            return;
        }

        // Extract first media playlist URL from master manifest
        NSURL *mediaPlaylistURL = [self extractMediaPlaylistURL:manifestText baseURL:url];

        if (completion) {
            completion(manifestText, mediaPlaylistURL, nil);
        }
    }];

    [task resume];
    return task;
}

+ (NSURLSessionDataTask *)fetchHLSMediaPlaylist:(NSURL *)url
                                     completion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion {
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
            completion(nil, error);
        }
        return nil;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task = [session dataTaskWithURL:url
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@ Media playlist fetch error: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        NSString *manifestText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!manifestText) {
            NSError *parseError = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                      code:-2
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse manifest text"}];
            if (completion) {
                completion(nil, parseError);
            }
            return;
        }

        if (completion) {
            completion(manifestText, nil);
        }
    }];

    [task resume];
    return task;
}

+ (NSURLSessionDataTask *)fetchTrackingMetadata:(NSURL *)url
                                       timeout:(NSTimeInterval)timeout
                                    completion:(void (^)(NRMTTrackingResponse * _Nullable, NSError * _Nullable))completion {
    if (!url) {
        if (completion) {
            NSError *error = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                 code:-1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid tracking URL"}];
            completion(nil, error);
        }
        return nil;
    }

    // Add cache-busting timestamp
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSURLQueryItem *timestampItem = [NSURLQueryItem queryItemWithName:@"_t"
                                                                 value:[@([[NSDate date] timeIntervalSince1970]) stringValue]];
    NSMutableArray *queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
    [queryItems addObject:timestampItem];
    components.queryItems = queryItems;
    NSURL *finalURL = components.URL ?: url;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = timeout;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

    NSURLSessionDataTask *task = [session dataTaskWithURL:finalURL
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"%@ Tracking API fetch error: %@", [NRMTUtilities logPrefix], error.localizedDescription);
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        // Check HTTP status code
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode == 403 || httpResponse.statusCode == 401) {
                NSLog(@"%@ Tracking API session expired: %ld", [NRMTUtilities logPrefix], (long)httpResponse.statusCode);
                NSError *sessionError = [NSError errorWithDomain:@"com.newrelic.mediatailor"
                                                            code:httpResponse.statusCode
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Session expired"}];
                if (completion) {
                    completion(nil, sessionError);
                }
                return;
            }
        }

        // Parse JSON response
        NSError *parseError = nil;
        NRMTTrackingResponse *trackingResponse = [NRMTTrackingResponse parseFromData:data error:&parseError];

        if (parseError) {
            NSLog(@"%@ Tracking API parse error: %@", [NRMTUtilities logPrefix], parseError.localizedDescription);
            if (completion) {
                completion(nil, parseError);
            }
            return;
        }

        if (completion) {
            completion(trackingResponse, nil);
        }
    }];

    [task resume];
    return task;
}

// MARK: - Private Helpers

+ (nullable NSURL *)extractMediaPlaylistURL:(NSString *)masterManifest baseURL:(NSURL *)baseURL {
    // Find first #EXT-X-STREAM-INF line followed by a URI
    NSArray<NSString *> *lines = [masterManifest componentsSeparatedByString:@"\n"];
    BOOL foundStreamInf = NO;

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if ([trimmedLine hasPrefix:@"#EXT-X-STREAM-INF"]) {
            foundStreamInf = YES;
            continue;
        }

        if (foundStreamInf && trimmedLine.length > 0 && ![trimmedLine hasPrefix:@"#"]) {
            // This is the media playlist URI
            NSURL *mediaURL = [NSURL URLWithString:trimmedLine relativeToURL:baseURL];
            return mediaURL;
        }
    }

    return nil;
}

@end
