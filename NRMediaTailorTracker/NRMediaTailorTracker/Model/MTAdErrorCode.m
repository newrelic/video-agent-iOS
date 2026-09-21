//
//  MTAdErrorCode.m
//  NRMediaTailorTracker
//

#import "MTAdErrorCode.h"

NSString *NSStringFromMTAdErrorCode(MTAdErrorCode code) {
    switch (code) {
        case MTAdErrorCodeAdsTimeout:                return @"ADS_TIMEOUT";
        case MTAdErrorCodeTrackingFetchFailed:       return @"TRACKING_FETCH_FAILED";
        case MTAdErrorCodeTokenExpired:              return @"TOKEN_EXPIRED";
        case MTAdErrorCodeNoFill:                    return @"NO_FILL";
        case MTAdErrorCodeMissingAvailStart:         return @"MISSING_AVAIL_START";
        case MTAdErrorCodeManifestParseFailed:       return @"MANIFEST_PARSE_FAILED";
        case MTAdErrorCodeManifestTrackingMismatch:  return @"MANIFEST_TRACKING_MISMATCH";
    }
    return @"UNKNOWN";
}
