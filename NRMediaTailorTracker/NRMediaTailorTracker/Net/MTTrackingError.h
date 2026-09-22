//
//  MTTrackingError.h
//  NRMediaTailorTracker
//
//  NSError domain + codes for the `MTTrackingClient` HTTP fetch path.
//  Distinct from `MTAdErrorCode` (which is the public AD_ERROR event
//  vocabulary). These codes describe the network-layer failure modes that
//  the client then maps into AD_ERROR events upstream:
//
//      MTTrackingErrorCodeTimeout         -> AD_ERROR errorCode=ADS_TIMEOUT
//      MTTrackingErrorCodeNetworkFailure  -> AD_ERROR errorCode=TRACKING_FETCH_FAILED
//      MTTrackingErrorCodeTokenExpired    -> AD_ERROR errorCode=TOKEN_EXPIRED
//      MTTrackingErrorCodeInvalidResponse -> AD_ERROR errorCode=TRACKING_FETCH_FAILED
//      MTTrackingErrorCodeParseFailed     -> AD_ERROR errorCode=TRACKING_FETCH_FAILED
//      MTTrackingErrorCodeCancelled       -> (silent; do not emit AD_ERROR)
//
//  The mapping lives in T08; this file just defines the codes.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const MTTrackingErrorDomain;

typedef NS_ERROR_ENUM(MTTrackingErrorDomain, MTTrackingErrorCode) {
    MTTrackingErrorCodeTimeout         = 1,
    MTTrackingErrorCodeNetworkFailure  = 2,
    MTTrackingErrorCodeTokenExpired    = 3,
    MTTrackingErrorCodeInvalidResponse = 4,
    MTTrackingErrorCodeParseFailed     = 5,
    MTTrackingErrorCodeCancelled       = 6,
};

NS_ASSUME_NONNULL_END
