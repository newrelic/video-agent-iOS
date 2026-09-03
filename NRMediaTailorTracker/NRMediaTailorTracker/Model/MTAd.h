//
//  MTAd.h
//  NRMediaTailorTracker
//
//  A single ad creative inside an `MTAvail`. Equivalent to one VAST <Ad>.
//  Immutable; populated from MediaTailor tracking JSON via `+fromDictionary:`.
//
//  Bug B2 fix: `creativeId` is the PRIMARY identity (atomic facts §1, §9). The
//  Android port treated `adId` as primary, which fails because `adId` is unique
//  only within an avail. Use `-primaryKey` to get the stable identity:
//      - `creativeId` if present
//      - `"<availId>:<adId>"` composite fallback when `creativeId` is missing
//

#import <Foundation/Foundation.h>

@class MTTrackingEvent;

NS_ASSUME_NONNULL_BEGIN

@interface MTAd : NSObject

// Identity
@property (nonatomic, copy, readonly, nullable) NSString *creativeId;   // PRIMARY identity (Bug B2)
@property (nonatomic, copy, readonly, nullable) NSString *adId;         // VAST <Ad id="…"> — unique within avail only

// Owning avail — captured so `-primaryKey` can produce the composite fallback
@property (nonatomic, copy, readonly, nullable) NSString *availId;

// Metadata
@property (nonatomic, copy, readonly, nullable) NSString *adTitle;
@property (nonatomic, copy, readonly, nullable) NSString *adSystem;
@property (nonatomic, copy, readonly, nullable) NSString *creativeSequence;  // 1-based string index
@property (nonatomic, copy, readonly, nullable) NSString *vastAdId;
@property (nonatomic, copy, readonly, nullable) NSString *skipOffset;        // HH:MM:SS, nil if not skippable
@property (nonatomic, copy, readonly, nullable) NSString *adProgramDateTime; // ISO 8601 wall-clock (Live)

// Timing — absolute to the content timeline, in milliseconds
@property (nonatomic, assign, readonly) NSTimeInterval startTimeMs;
@property (nonatomic, assign, readonly) NSTimeInterval durationMs;

// Tracking events (impression, quartiles, complete, …). Beacon URLs are NOT fired by this tracker.
@property (nonatomic, copy, readonly) NSArray<MTTrackingEvent *> *trackingEvents;

/// Convenience: case-insensitive match of "bumper" on adSystem, adTitle, OR adId.
@property (nonatomic, assign, readonly) BOOL isBumper;

- (instancetype)initWithCreativeId:(nullable NSString *)creativeId
                              adId:(nullable NSString *)adId
                           availId:(nullable NSString *)availId
                           adTitle:(nullable NSString *)adTitle
                          adSystem:(nullable NSString *)adSystem
                  creativeSequence:(nullable NSString *)creativeSequence
                          vastAdId:(nullable NSString *)vastAdId
                        skipOffset:(nullable NSString *)skipOffset
                 adProgramDateTime:(nullable NSString *)adProgramDateTime
                       startTimeMs:(NSTimeInterval)startTimeMs
                        durationMs:(NSTimeInterval)durationMs
                    trackingEvents:(NSArray<MTTrackingEvent *> *)trackingEvents NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Build from one entry of `avails[*].ads[*]`. `availId` is passed in so the
/// fallback composite key can be formed. Returns nil if the dict is unusable.
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict availId:(nullable NSString *)availId;

/// Bug B2: returns `creativeId` if non-nil; else `"<availId>:<adId>"` composite.
- (NSString *)primaryKey;

@end

NS_ASSUME_NONNULL_END
