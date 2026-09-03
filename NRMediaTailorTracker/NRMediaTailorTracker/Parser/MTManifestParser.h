//
//  MTManifestParser.h
//  NRMediaTailorTracker
//
//  Manifest-parser seam (T11). Defines the protocol that the built-in
//  `MTHlsParser` conforms to, and that a customer-supplied DASH adapter would
//  also conform to. This is the integration point that lets us ship HLS-only
//  in v1 while leaving the door open for DASH without forking the SDK.
//
//  Per FEATURE_SPEC §6 "DASH on iOS isn't first-class in AVPlayer": customers
//  using third-party DASH players (THEOplayer, Bitmovin, Shaka) can write a
//  thin adapter that conforms to this protocol and inject it via
//  `-[NRTrackerMediaTailor setManifestParser:]`.
//
//  Threading: implementations may be called from a background queue when the
//  tracker is fetching/parsing manifests asynchronously, so conforming types
//  must be safe to call from non-main queues. They MUST NOT mutate shared
//  state during the parse call; the tracker is responsible for serialising
//  result handling back onto its own queue.
//

#import <Foundation/Foundation.h>

@class MTManifestParseResult;

NS_ASSUME_NONNULL_BEGIN

@protocol MTManifestParser <NSObject>

/// Parse a manifest body into ad breaks + an optional tracking URL.
///
/// @param manifest Raw manifest bytes (HLS `.m3u8` text encoded as UTF-8, or
///                 DASH MPD XML). Nil / empty MUST return an empty
///                 `MTManifestParseResult` rather than crashing.
/// @param baseURL  Manifest URL used to resolve relative URIs (e.g. a
///                 `URI` attribute on an HLS `EXT-X-DATERANGE` marker, or a
///                 DASH `BaseURL` element). May be nil; in that case relative
///                 URIs are returned unresolved.
/// @return         Parse result. Never nil.
- (MTManifestParseResult *)parseManifest:(nullable NSData *)manifest
                                 baseURL:(nullable NSURL *)baseURL;

@end

NS_ASSUME_NONNULL_END
