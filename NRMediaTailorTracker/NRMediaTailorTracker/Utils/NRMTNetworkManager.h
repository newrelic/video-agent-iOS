//
//  NRMTNetworkManager.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRMTTrackingResponse;

NS_ASSUME_NONNULL_BEGIN

/**
 Network manager for fetching HLS manifests and MediaTailor tracking API

 Handles all HTTP requests with proper timeout, error handling, and cancellation support
 */
@interface NRMTNetworkManager : NSObject

/**
 Fetches HLS master manifest and extracts media playlist URL

 @param url Master manifest URL (.m3u8)
 @param completion Completion handler with manifest text and media URL
 @return NSURLSessionDataTask for cancellation
 */
+ (NSURLSessionDataTask *)fetchHLSMasterManifest:(NSURL *)url
                                      completion:(void (^)(NSString * _Nullable manifestText,
                                                          NSURL * _Nullable mediaPlaylistURL,
                                                          NSError * _Nullable error))completion;

/**
 Fetches HLS media playlist

 @param url Media playlist URL (.m3u8)
 @param completion Completion handler with manifest text
 @return NSURLSessionDataTask for cancellation
 */
+ (NSURLSessionDataTask *)fetchHLSMediaPlaylist:(NSURL *)url
                                     completion:(void (^)(NSString * _Nullable manifestText,
                                                         NSError * _Nullable error))completion;

/**
 Fetches tracking metadata from AWS MediaTailor Tracking API

 @param url Tracking API URL
 @param timeout Request timeout in seconds
 @param completion Completion handler with parsed tracking response
 @return NSURLSessionDataTask for cancellation
 */
+ (NSURLSessionDataTask *)fetchTrackingMetadata:(NSURL *)url
                                       timeout:(NSTimeInterval)timeout
                                    completion:(void (^)(NRMTTrackingResponse * _Nullable response,
                                                        NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
