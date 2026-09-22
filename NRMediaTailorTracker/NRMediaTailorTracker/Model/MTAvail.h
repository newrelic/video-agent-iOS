//
//  MTAvail.h
//  NRMediaTailorTracker
//
//  A MediaTailor "avail" — a single ad-break window in the content timeline.
//  Contains zero or more `MTAd` objects. An empty `ads` array means no-fill
//  (ad-server failure / slate); the tracker must emit AD_BREAK_START →
//  AD_BREAK_END with no AD_START in between. See atomic facts §6 and Bug A2.
//

#import <Foundation/Foundation.h>

@class MTAd;

NS_ASSUME_NONNULL_BEGIN

@interface MTAvail : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *availId;
@property (nonatomic, assign, readonly) NSTimeInterval startTimeMs;   // absolute, ms
@property (nonatomic, assign, readonly) NSTimeInterval durationMs;
@property (nonatomic, copy, readonly, nullable) NSString *availProgramDateTime; // ISO 8601 wall-clock (Live)
@property (nonatomic, copy, readonly) NSArray<MTAd *> *ads;

/// True when the tracking JSON did NOT supply `startTimeInSeconds` for this avail.
/// Surfaced so the schedule merger can implement Bug A8 (emit AD_ERROR with
/// errorCode=MISSING_AVAIL_START rather than silently inferring start from
/// the first ad).
@property (nonatomic, assign, readonly) BOOL hasStartTime;

- (instancetype)initWithAvailId:(nullable NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                   hasStartTime:(BOOL)hasStartTime
                     durationMs:(NSTimeInterval)durationMs
           availProgramDateTime:(nullable NSString *)availProgramDateTime
                            ads:(NSArray<MTAd *> *)ads NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

/// Convenience for the schedule merger (Bug A2).
@property (nonatomic, assign, readonly, getter=isNoFill) BOOL noFill;

@end

NS_ASSUME_NONNULL_END
