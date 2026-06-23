//
//  MTAdBreak.h
//  NRMediaTailorTracker
//
//  Mutable runtime state for one ad break (a MediaTailor "avail"). Holds the
//  list of `MTAdPod`s currently scheduled within it plus the break-level
//  firing flags used to dedupe `AD_BREAK_START` / `AD_BREAK_END` /
//  `AD_START` events.
//
//  Identity (Bug A4): for VOD the `availId` + `startTimeMs` are stable. For
//  live, `availProgramDateTime` (wall-clock) is the only correlation key that
//  survives HLS sliding-window rotation — the schedule merger should use a
//  compound key `(availId, availProgramDateTime ?? startTimeMs)`.
//
//  `isNoFill` (Bug A2): empty avail. The state machine must emit
//  `AD_BREAK_START` → `AD_BREAK_END` only and never `AD_START` / quartiles.
//

#import <Foundation/Foundation.h>

@class MTAdPod;

NS_ASSUME_NONNULL_BEGIN

@interface MTAdBreak : NSObject

@property (nonatomic, copy, nullable) NSString *availId;
@property (nonatomic, assign) NSTimeInterval startTimeMs;
@property (nonatomic, assign) NSTimeInterval durationMs;
@property (nonatomic, assign, readonly) NSTimeInterval endTimeMs;

@property (nonatomic, copy, nullable) NSString *availProgramDateTime; // ISO 8601 wall-clock (Live)

/// Bug A2: no-fill. When YES, the state machine must NOT emit AD_START /
/// AD_QUARTILE / AD_END inside this break.
@property (nonatomic, assign) BOOL isNoFill;

/// Bug A3: set by the schedule merger when the manifest pod count and tracking
/// API ad count disagree. Surfaced as an `AD_BREAK_START` attribute.
@property (nonatomic, assign) BOOL podCountMismatch;

@property (nonatomic, strong, readonly) NSMutableArray<MTAdPod *> *pods;

// Firing flags
@property (nonatomic, assign) BOOL hasFiredStart;
@property (nonatomic, assign) BOOL hasFiredEnd;
@property (nonatomic, assign) BOOL hasFiredAdStart;
@property (nonatomic, assign) BOOL hasFiredQ1;
@property (nonatomic, assign) BOOL hasFiredQ2;
@property (nonatomic, assign) BOOL hasFiredQ3;

- (instancetype)initWithAvailId:(nullable NSString *)availId
                    startTimeMs:(NSTimeInterval)startTimeMs
                     durationMs:(NSTimeInterval)durationMs;

/// Half-open: `[startTimeMs, endTimeMs)`.
- (BOOL)containsPositionMs:(NSTimeInterval)positionMs;

/// Returns the active pod for the given playhead, or nil.
- (nullable MTAdPod *)activePodForPositionMs:(NSTimeInterval)positionMs;

@end

NS_ASSUME_NONNULL_END
