//
//  MTTrackingEvent.h
//  NRMediaTailorTracker
//
//  A single VAST tracking event entry inside an `MTAd.trackingEvents` array
//  (impression, firstQuartile, midpoint, thirdQuartile, complete, etc.).
//
//  `startTimeInSeconds` from the MediaTailor tracking JSON is RELATIVE TO AD START,
//  not absolute manifest time. Stored as relativeToAdStartMs to prevent confusion
//  with MTAvail.startTimeMs and MTAd.startTimeMs (which are absolute).
//  See atomic facts §1, §9 and BUGS_TO_FIX.md B5.
//
//  NOTE: We DO NOT fire these beacons. Per anti-pattern guardrails (FEATURE_SPEC §5)
//  the tracker is a passive observer; beacon URLs are surfaced for opt-in
//  client-side reporting consumers only.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTTrackingEvent : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *eventType;          // e.g. "impression", "firstQuartile"
@property (nonatomic, copy, readonly, nullable) NSString *eventId;
@property (nonatomic, assign, readonly) NSTimeInterval relativeToAdStartMs;   // milliseconds RELATIVE to ad start (Bug B5)
@property (nonatomic, copy, readonly) NSArray<NSURL *> *beaconUrls;
@property (nonatomic, copy, readonly, nullable) NSString *eventProgramDateTime; // ISO 8601 wall-clock

- (instancetype)initWithEventType:(nullable NSString *)eventType
                          eventId:(nullable NSString *)eventId
              relativeToAdStartMs:(NSTimeInterval)relativeToAdStartMs
                       beaconUrls:(NSArray<NSURL *> *)beaconUrls
             eventProgramDateTime:(nullable NSString *)eventProgramDateTime NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Build from a tracking-JSON dictionary entry. Returns nil if the dict is unusable.
/// Converts the JSON's `startTimeInSeconds` (seconds, relative to ad start) into
/// `relativeToAdStartMs` (milliseconds, relative to ad start).
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
