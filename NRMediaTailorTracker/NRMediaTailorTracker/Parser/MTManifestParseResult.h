//
//  MTManifestParseResult.h
//  NRMediaTailorTracker
//
//  Output of a manifest parse: optional tracking URL (recovered from a manifest
//  marker — Bug B4 PRIMARY path) and the list of `MTAdBreak`s detected.
//

#import <Foundation/Foundation.h>

@class MTAdBreak;

NS_ASSUME_NONNULL_BEGIN

@interface MTManifestParseResult : NSObject

/// Tracking URL recovered from a manifest marker (HLS EXT-X-DATERANGE
/// `CLASS="tracking"` / `CLASS="com.apple.hls.interstitial"` URI attribute).
/// Nil when the manifest contains no tracking marker — caller falls back to
/// `+[MTDetector deriveTrackingURL:]` (Bug B4 FALLBACK path).
@property (nonatomic, copy, nullable, readonly) NSURL *trackingURL;

/// Ad breaks detected in the manifest. Empty when no segment markers matched.
@property (nonatomic, copy, readonly) NSArray<MTAdBreak *> *breaks;

- (instancetype)initWithTrackingURL:(nullable NSURL *)trackingURL
                             breaks:(NSArray<MTAdBreak *> *)breaks NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)empty;

@end

NS_ASSUME_NONNULL_END
