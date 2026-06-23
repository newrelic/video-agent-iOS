//
//  MTNonLinearAvail.h
//  NRMediaTailorTracker
//
//  Non-linear (overlay / companion) avails surfaced by the MediaTailor tracking
//  endpoint. We do NOT render overlays — per FEATURE_SPEC §5 anti-pattern
//  guardrails we are a passive observer. The presence of non-linear avails is
//  exposed as the `nonLinearAvailsCount` event attribute so customers can see
//  them in NRDB.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTNonLinearAvail : NSObject

@property (nonatomic, copy, readonly, nullable) NSString *availId;
@property (nonatomic, assign, readonly) NSTimeInterval startTimeMs;
@property (nonatomic, assign, readonly) NSTimeInterval durationMs;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *rawPayload;

- (instancetype)initWithAvailId:(nullable NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                     durationMs:(NSTimeInterval)durationMs
                     rawPayload:(nullable NSDictionary<NSString *, id> *)rawPayload NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
