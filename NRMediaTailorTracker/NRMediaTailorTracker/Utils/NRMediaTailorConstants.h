//
//  NRMediaTailorConstants.h
//  NRMediaTailorTracker
//
//  Created by New Relic on 04/01/2026.
//  Copyright © 2026 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - Enumerations

/**
 Stream Type
 */
typedef NS_ENUM(NSInteger, NRMTStreamType) {
    NRMTStreamTypeVOD,   // Video on Demand
    NRMTStreamTypeLive   // Live streaming
};

/**
 Manifest Type (HLS only for v1.0)
 */
typedef NS_ENUM(NSInteger, NRMTManifestType) {
    NRMTManifestTypeHLS  // HTTP Live Streaming (.m3u8)
};

/**
 Ad Position (VOD only)
 */
typedef NS_ENUM(NSInteger, NRMTAdPosition) {
    NRMTAdPositionPreRoll,   // First ad break
    NRMTAdPositionMidRoll,   // Middle ad break
    NRMTAdPositionPostRoll,  // Last ad break
    NRMTAdPositionUnknown    // Live or undetermined
};

/**
 Ad Source (where the ad was detected from)
 */
typedef NS_ENUM(NSInteger, NRMTAdSource) {
    NRMTAdSourceManifestCue,         // Detected from CUE-OUT/CUE-IN tags (HLS)
    NRMTAdSourceTrackingAPI,         // Added from tracking API response
    NRMTAdSourceManifestAndTracking  // Enriched by both sources
};

// MARK: - Default Configuration Values

/**
 Default live manifest poll interval (seconds)
 */
#define NRMT_DEFAULT_LIVE_MANIFEST_POLL_INTERVAL 5.0

/**
 Default live tracking API poll interval (seconds)
 */
#define NRMT_DEFAULT_LIVE_TRACKING_POLL_INTERVAL 10.0

/**
 Default tracking API request timeout (seconds)
 */
#define NRMT_DEFAULT_TRACKING_API_TIMEOUT 5.0

// MARK: - Timing Thresholds

/**
 Minimum ad duration to be considered valid (seconds)
 Filters false positives from zero-duration CUE markers
 */
#define NRMT_MIN_AD_DURATION 0.5

/**
 Tolerance for matching ad times (seconds)
 Used for deduplication and schedule matching
 */
#define NRMT_AD_TIMING_TOLERANCE 0.5

/**
 Threshold to ignore pause events after ad break (seconds)
 Prevents false CONTENT_PAUSE immediately after ad
 */
#define NRMT_POST_AD_PAUSE_THRESHOLD 0.5

// MARK: - Quartile Percentages

/**
 First quartile percentage (25%)
 */
#define NRMT_QUARTILE_Q1 0.25

/**
 Second quartile percentage (50%)
 */
#define NRMT_QUARTILE_Q2 0.50

/**
 Third quartile percentage (75%)
 */
#define NRMT_QUARTILE_Q3 0.75

// MARK: - MediaTailor Identifiers

/**
 Segment pattern to identify MediaTailor ad segments
 */
#define NRMT_SEGMENT_PATTERN @"segments.mediatailor"

/**
 MediaTailor domain pattern for URL detection
 */
#define NRMT_DOMAIN_PATTERN @".mediatailor."

// MARK: - HLS Manifest Patterns

/**
 Regex pattern for CUE-OUT duration extraction
 Matches: #EXT-X-CUE-OUT:DURATION=30.0
 */
#define NRMT_REGEX_CUE_OUT @"#EXT-X-CUE-OUT:DURATION=([\\d.]+)"

/**
 Regex pattern for CUE-IN detection
 Matches: #EXT-X-CUE-IN
 */
#define NRMT_REGEX_CUE_IN @"#EXT-X-CUE-IN"

/**
 Regex pattern for DISCONTINUITY detection
 Matches: #EXT-X-DISCONTINUITY
 */
#define NRMT_REGEX_DISCONTINUITY @"#EXT-X-DISCONTINUITY"

/**
 Regex pattern for MAP URI extraction
 Matches: #EXT-X-MAP:URI="segment.mp4"
 */
#define NRMT_REGEX_MAP @"#EXT-X-MAP:URI=\"([^\"]+)\""

/**
 Regex pattern for EXTINF duration extraction
 Matches: #EXTINF:6.0,
 */
#define NRMT_REGEX_EXTINF @"#EXTINF:([\\d.]+)"

/**
 Regex pattern for target duration extraction
 Matches: #EXT-X-TARGETDURATION:6
 */
#define NRMT_REGEX_TARGET_DURATION @"#EXT-X-TARGETDURATION:(\\d+)"

/**
 Prefix for CUE-OUT tag
 */
#define NRMT_TAG_CUE_OUT @"#EXT-X-CUE-OUT"

/**
 Prefix for CUE-IN tag
 */
#define NRMT_TAG_CUE_IN @"#EXT-X-CUE-IN"

/**
 Prefix for DISCONTINUITY tag
 */
#define NRMT_TAG_DISCONTINUITY @"#EXT-X-DISCONTINUITY"

/**
 Prefix for EXTINF tag
 */
#define NRMT_TAG_EXTINF @"#EXTINF:"

// MARK: - Logging

/**
 Log prefix for MediaTailor tracker
 */
#define NRMT_LOG_PREFIX @"[MediaTailor]"

NS_ASSUME_NONNULL_END
