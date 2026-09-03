//
//  MTPlayheadStateMachine.h
//  NRMediaTailorTracker
//
//  Playhead poll loop and explicit state machine. Consumes a `MergedSchedule`
//  (from T06) and an `AVPlayer`, emits delegate callbacks at the boundaries
//  the event emitter (T08) needs to fire `AD_BREAK_START` / `AD_START` /
//  `AD_QUARTILE` / `AD_END` / `AD_BREAK_END` / `AD_ERROR`.
//
//  This task implements:
//    - A5: configurable `playheadPollInterval` (default 0.250s)
//    - A6: graceful handling when a pod ends before its break does (state
//          stays `MTAdStateInBreak` until the break itself ends)
//    - `pendingErrors` drain ordering: errors for a break fire AFTER
//      `enteredBreak:` and BEFORE the next pod/break transition. See
//      [[merger-pending-errors-array]] memory.
//
//  Bug dedup: every `MTAdBreak` and `MTAdPod` carries `hasFired*` BOOL flags
//  (set up by T03 in the model). Backward seeks DO NOT re-fire any event.
//
//  Threading: all state is main-queue only. `-tickAtPositionMs:` and the
//  `addPeriodicTimeObserverForInterval:queue:usingBlock:` block both run on
//  the main queue. Tests can drive the state machine via `-tickAtPositionMs:`
//  without an `AVPlayer`.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "MTAdState.h"

@class MergedSchedule;
@class MTAdBreak;
@class MTAdPod;
@class MTMergedScheduleError;
@class MTPlayheadStateMachine;

NS_ASSUME_NONNULL_BEGIN

@protocol MTPlayheadStateMachineDelegate <NSObject>

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
        enteredBreak:(MTAdBreak *)adBreak;

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
          enteredPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)adBreak;

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
     crossedQuartile:(NSInteger)quartile
               inPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)adBreak;

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
           exitedPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)adBreak;

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
         exitedBreak:(MTAdBreak *)adBreak;

- (void)stateMachine:(MTPlayheadStateMachine *)stateMachine
         raisedError:(MTMergedScheduleError *)error;

@end


@interface MTPlayheadStateMachine : NSObject

@property (nonatomic, weak, nullable) id<MTPlayheadStateMachineDelegate> delegate;

/// Effective poll interval in seconds. Echoes back what `init` was given,
/// after clamping non-positive inputs to the 0.250s default. Tests assert
/// against this when verifying A5.
@property (nonatomic, assign, readonly) NSTimeInterval playheadPollInterval;

@property (nonatomic, assign, readonly) MTAdState currentState;

@property (nonatomic, weak, readonly, nullable) MTAdBreak *currentAdBreak;
@property (nonatomic, weak, readonly, nullable) MTAdPod *currentAdPod;

- (instancetype)initWithSchedule:(MergedSchedule *)schedule
            playheadPollInterval:(NSTimeInterval)interval NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Attach to an `AVPlayer`. Installs a periodic-time observer at
/// `playheadPollInterval` that drives `-tickAtPositionMs:` on the main queue.
/// Re-attaching detaches the previous observer first.
- (void)attachToPlayer:(AVPlayer *)player;

/// Removes the periodic-time observer. Safe to call multiple times.
- (void)detachFromPlayer;

/// Test seam. Feeds a playhead position directly into the state machine.
/// The `AVPlayer` periodic observer also calls this internally.
- (void)tickAtPositionMs:(NSTimeInterval)positionMs;

@end

NS_ASSUME_NONNULL_END
