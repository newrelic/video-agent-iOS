//
//  MergedSchedule.h
//  NRMediaTailorTracker
//
//  Output of `+[MTAdScheduleMerger mergeManifestBreaks:trackingResponse:]`.
//  Pairs the merged ad-break list with any data-integrity errors the merger
//  queued for the event emitter (T08) to translate into `AD_ERROR` events:
//    - `NO_FILL` for empty avails (Bug A2)
//    - `MISSING_AVAIL_START` for avails missing `startTimeInSeconds` (Bug A8)
//    - `MANIFEST_TRACKING_MISMATCH` for breaks where manifest pod count and
//      tracking ad count disagree (Bug A3 — kept manifest geometry; flagged)
//

#import <Foundation/Foundation.h>
#import "MTAdErrorCode.h"

@class MTAdBreak;

NS_ASSUME_NONNULL_BEGIN

/// One queued error tied to a specific ad break. The event emitter (T08)
/// drains this list and fires the corresponding `AD_ERROR` events.
@interface MTMergedScheduleError : NSObject

@property (nonatomic, weak, readonly) MTAdBreak *adBreak;
@property (nonatomic, assign, readonly) MTAdErrorCode errorCode;
@property (nonatomic, copy, readonly, nullable) NSString *message;

- (instancetype)initWithBreak:(MTAdBreak *)adBreak
                    errorCode:(MTAdErrorCode)errorCode
                      message:(nullable NSString *)message NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface MergedSchedule : NSObject

@property (nonatomic, copy, readonly) NSArray<MTAdBreak *> *breaks;
@property (nonatomic, copy, readonly) NSArray<MTMergedScheduleError *> *pendingErrors;

/// Convenience counter: number of breaks in `breaks` that have
/// `podCountMismatch == YES` (Bug A3 trigger). Derived from `breaks`; exposed
/// for telemetry and tests so callers don't have to re-walk the array.
@property (nonatomic, assign, readonly) NSUInteger podCountMismatchCount;

/// Convenience counter: number of `pendingErrors` whose `errorCode` is
/// `MTAdErrorCodeMissingAvailStart` (Bug A8 trigger). Same rationale.
@property (nonatomic, assign, readonly) NSUInteger dataIntegrityWarningCount;

- (instancetype)initWithBreaks:(NSArray<MTAdBreak *> *)breaks
                 pendingErrors:(NSArray<MTMergedScheduleError *> *)pendingErrors NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)empty;

@end

NS_ASSUME_NONNULL_END
