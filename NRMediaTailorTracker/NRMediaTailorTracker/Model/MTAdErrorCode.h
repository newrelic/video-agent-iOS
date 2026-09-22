//
//  MTAdErrorCode.h
//  NRMediaTailorTracker
//
//  Error codes surfaced via `AD_ERROR` events. Per FEATURE_SPEC §2 and
//  BUGS_TO_FIX.md group B (Bug B6 — Android emits no error event for ADS
//  timeout, expired token, parse failure, etc.).
//
//  The string name (returned by NSStringFromMTAdErrorCode) is what gets
//  attached to event attributes; the enum is used internally for switch
//  exhaustiveness.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTAdErrorCode) {
    MTAdErrorCodeAdsTimeout,
    MTAdErrorCodeTrackingFetchFailed,
    MTAdErrorCodeTokenExpired,
    MTAdErrorCodeNoFill,
    MTAdErrorCodeMissingAvailStart,
    MTAdErrorCodeManifestParseFailed,
    MTAdErrorCodeManifestTrackingMismatch,
};

/// Returns the canonical wire-format string for an error code (e.g. `NO_FILL`).
FOUNDATION_EXPORT NSString *NSStringFromMTAdErrorCode(MTAdErrorCode code);

NS_ASSUME_NONNULL_END
