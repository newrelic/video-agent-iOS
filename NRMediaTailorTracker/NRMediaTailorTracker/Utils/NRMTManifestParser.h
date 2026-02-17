//
//  NRMTManifestParser.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 05/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NRMTAdBreak;

NS_ASSUME_NONNULL_BEGIN

/**
 Manifest parser result
 */
@interface NRMTManifestParserResult : NSObject

@property (nonatomic, strong) NSArray<NRMTAdBreak *> *adBreaks;
@property (nonatomic, assign) BOOL isVOD;
@property (nonatomic, assign) NSTimeInterval targetDuration;
@property (nonatomic, strong, nullable) NSString *trackingURL;

@end

/**
 Static utility class for parsing MediaTailor HLS manifests
 */
@interface NRMTManifestParser : NSObject

/**
 Asynchronously parses a MediaTailor HLS manifest and extracts ad breaks

 @param manifestURL The full master manifest URL
 @param trackingURL The tracking API URL (optional, for enrichment)
 @param completion Completion handler with parsed result or error
 */
+ (void)parseManifestAtURL:(NSString *)manifestURL
                trackingURL:(nullable NSString *)trackingURL
                 completion:(void (^)(NRMTManifestParserResult * _Nullable result, NSError * _Nullable error))completion;

/**
 Synchronously parses HLS manifest text for ad breaks (for backward compatibility)

 @param manifestText The HLS manifest content
 @return Array of detected ad breaks
 */
+ (NSArray<NRMTAdBreak *> *)parseHLSManifestForAds:(NSString *)manifestText;

/**
 Extracts target duration from HLS manifest text

 @param manifestText The HLS manifest content
 @return Target duration in seconds, or 0 if not found
 */
+ (NSTimeInterval)extractTargetDuration:(NSString *)manifestText;

@end

NS_ASSUME_NONNULL_END
