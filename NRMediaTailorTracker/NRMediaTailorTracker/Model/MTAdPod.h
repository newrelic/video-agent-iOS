//
//  MTAdPod.h
//  NRMediaTailorTracker
//
//  Mutable runtime state for a single ad creative inside an `MTAdBreak`.
//  Maps roughly 1:1 to an `MTAd` but carries the firing flags that the
//  playhead poll loop flips to dedupe `AD_START` / quartile events.
//
//  Unlike the immutable `MTAd` model, this is the *playback* representation —
//  populated by the schedule merger and mutated by the state machine.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTAdPod : NSObject

// Identity — primaryKey is derived from the source MTAd (Bug B2).
@property (nonatomic, copy, nullable) NSString *primaryKey;
@property (nonatomic, copy, nullable) NSString *creativeId;
@property (nonatomic, copy, nullable) NSString *adId;

// Timing — absolute milliseconds against the content timeline.
@property (nonatomic, assign) NSTimeInterval startTimeMs;
@property (nonatomic, assign) NSTimeInterval durationMs;
@property (nonatomic, assign, readonly) NSTimeInterval endTimeMs;

// Metadata
@property (nonatomic, copy, nullable) NSString *adTitle;
@property (nonatomic, copy, nullable) NSString *adSystem;
@property (nonatomic, copy, nullable) NSString *creativeSequence;
@property (nonatomic, copy, nullable) NSString *vastAdId;
@property (nonatomic, copy, nullable) NSString *skipOffset;
@property (nonatomic, copy, nullable) NSString *adProgramDateTime;
@property (nonatomic, assign) BOOL isBumper;

// Firing flags — flipped on first emission to prevent duplicate events.
@property (nonatomic, assign) BOOL hasFiredStart;
@property (nonatomic, assign) BOOL hasFiredQ1;
@property (nonatomic, assign) BOOL hasFiredQ2;
@property (nonatomic, assign) BOOL hasFiredQ3;

- (instancetype)initWithStartTimeMs:(NSTimeInterval)startTimeMs
                         durationMs:(NSTimeInterval)durationMs;

/// `position` semantics: half-open interval `[startTimeMs, endTimeMs)`.
- (BOOL)containsPositionMs:(NSTimeInterval)positionMs;

@end

NS_ASSUME_NONNULL_END
