//
//  MTAdState.h
//  NRMediaTailorTracker
//
//  Explicit playback state for `MTPlayheadStateMachine`. The state machine
//  reduces a stream of playhead positions to a sequence of well-defined
//  transitions; T08 turns those transitions into NRVideoTracker events.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MTAdState) {
    /// Outside every ad break. The default state.
    MTAdStateContent      = 0,

    /// Inside a break that has ads (`MTAdBreak.isNoFill == NO`) but not yet
    /// inside any specific pod. Transient: we move into `InPod` as soon as a
    /// pod's range contains the position. A6 fix: if the last pod ends before
    /// the break does, we re-enter `InBreak` (idle) and stay there until the
    /// position exits the break range.
    MTAdStateInBreak      = 1,

    /// Inside a specific `MTAdPod`. Quartiles fire here.
    MTAdStateInPod        = 2,

    /// Inside a break flagged `isNoFill = YES` (Bug A2 — empty avail). We
    /// emit `BREAK_START` + an `AD_ERROR(NO_FILL)` + `BREAK_END` and never
    /// touch `MTAdStateInPod` for this break.
    MTAdStateNoFill       = 3,
};

NS_ASSUME_NONNULL_END
