//
//  NRVideoDefs.h
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#ifndef NRVideoDefs_h
#define NRVideoDefs_h

#define NRVIDEO_CORE_VERSION        @"4.0.5"

#define NR_VIDEO_EVENT              @"VideoAction"
#define NR_VIDEO_AD_EVENT           @"VideoAdAction"
#define NR_VIDEO_ERROR_EVENT        @"VideoErrorAction"
#define NR_VIDEO_CUSTOM_EVENT       @"VideoCustomAction"

#define TRACKER_READY               @"TRACKER_READY"
#define PLAYER_READY                @"PLAYER_READY"

#define CONTENT_REQUEST             @"CONTENT_REQUEST"
#define CONTENT_START               @"CONTENT_START"
#define CONTENT_PAUSE               @"CONTENT_PAUSE"
#define CONTENT_RESUME              @"CONTENT_RESUME"
#define CONTENT_END                 @"CONTENT_END"
#define CONTENT_SEEK_START          @"CONTENT_SEEK_START"
#define CONTENT_SEEK_END            @"CONTENT_SEEK_END"
#define CONTENT_BUFFER_START        @"CONTENT_BUFFER_START"
#define CONTENT_BUFFER_END          @"CONTENT_BUFFER_END"
#define CONTENT_HEARTBEAT           @"CONTENT_HEARTBEAT"
#define CONTENT_RENDITION_CHANGE    @"CONTENT_RENDITION_CHANGE"
#define CONTENT_ERROR               @"CONTENT_ERROR"

#define AD_REQUEST                  @"AD_REQUEST"
#define AD_START                    @"AD_START"
#define AD_PAUSE                    @"AD_PAUSE"
#define AD_RESUME                   @"AD_RESUME"
#define AD_END                      @"AD_END"
#define AD_SEEK_START               @"AD_SEEK_START"
#define AD_SEEK_END                 @"AD_SEEK_END"
#define AD_BUFFER_START             @"AD_BUFFER_START"
#define AD_BUFFER_END               @"AD_BUFFER_END"
#define AD_HEARTBEAT                @"AD_HEARTBEAT"
#define AD_RENDITION_CHANGE         @"AD_RENDITION_CHANGE"
#define AD_ERROR                    @"AD_ERROR"
#define AD_BREAK_START              @"AD_BREAK_START"
#define AD_BREAK_END                @"AD_BREAK_END"
#define AD_QUARTILE                 @"AD_QUARTILE"
#define AD_CLICK                    @"AD_CLICK"

#define QOE_AGGREGATE               @"QOE_AGGREGATE"
#define QOE_AGGREGATE_VERSION       @"1.0.0"

// --- Base attribute names (C strings, no prefix) ---
// These define WHAT is being measured. Each is a raw name without any category prefix.
// Never use these directly in event dictionaries — always use the prefixed versions below.
#define ATTR_STARTUP_TIME           "startupTime"
#define ATTR_PEAK_BITRATE           "peakBitrate"
#define ATTR_AVERAGE_BITRATE        "averageBitrate"
#define ATTR_TOTAL_PLAYTIME         "totalPlaytime"
#define ATTR_TOTAL_REBUFFERING_TIME "totalRebufferingTime"
#define ATTR_REBUFFERING_RATIO      "rebufferingRatio"
#define ATTR_HAD_STARTUP_ERROR      "hadStartupError"
#define ATTR_HAD_PLAYBACK_ERROR     "hadPlaybackError"

// --- Category prefixes (C strings) ---
// Each category gets its own NRQL namespace prefix.
// To add a new category: define a prefix here, then create prefixed macros below.
// Example: #define ENGAGEMENT_PREFIX "eng."
#define QOE_PREFIX                  ""

// --- Prefixed QoE attribute keys (NSString, for use in event dictionaries) ---
// Composed as: @<PREFIX><BASE_NAME>  (compile-time string concatenation)
// NRQL: SELECT startupTime, peakBitrate FROM VideoAction WHERE actionName = 'QOE_AGGREGATE'
#define KPI_STARTUP_TIME            @QOE_PREFIX ATTR_STARTUP_TIME
#define KPI_PEAK_BITRATE            @QOE_PREFIX ATTR_PEAK_BITRATE
#define KPI_AVERAGE_BITRATE         @QOE_PREFIX ATTR_AVERAGE_BITRATE
#define KPI_TOTAL_PLAYTIME          @QOE_PREFIX ATTR_TOTAL_PLAYTIME
#define KPI_TOTAL_REBUFFERING_TIME  @QOE_PREFIX ATTR_TOTAL_REBUFFERING_TIME
#define KPI_REBUFFERING_RATIO       @QOE_PREFIX ATTR_REBUFFERING_RATIO
#define KPI_HAD_STARTUP_ERROR       @QOE_PREFIX ATTR_HAD_STARTUP_ERROR
#define KPI_HAD_PLAYBACK_ERROR      @QOE_PREFIX ATTR_HAD_PLAYBACK_ERROR

// --- Centralized list of all QoE KPI attribute keys ---
// When adding a new KPI_* macro above, also add it to this array.
// Used by the aggregator, harvest manager, and anywhere KPI keys need enumeration.
static inline NSArray<NSString *> *NRVAAllKPIKeys(void) {
    static NSArray *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @[
            KPI_STARTUP_TIME,
            KPI_PEAK_BITRATE,
            KPI_AVERAGE_BITRATE,
            KPI_TOTAL_PLAYTIME,
            KPI_TOTAL_REBUFFERING_TIME,
            KPI_REBUFFERING_RATIO,
            KPI_HAD_STARTUP_ERROR,
            KPI_HAD_PLAYBACK_ERROR
        ];
    });
    return keys;
}

#endif /* NRVideoDefs_h */
