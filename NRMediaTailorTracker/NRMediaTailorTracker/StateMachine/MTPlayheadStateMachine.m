//
//  MTPlayheadStateMachine.m
//  NRMediaTailorTracker
//

#import "MTPlayheadStateMachine.h"
#import "MergedSchedule.h"
#import "MTAdBreak.h"
#import "MTAdPod.h"

static const NSTimeInterval kDefaultPlayheadPollInterval = 0.250;

@interface MTPlayheadStateMachine ()

@property (nonatomic, strong, readonly) MergedSchedule *schedule;
@property (nonatomic, assign, readwrite) NSTimeInterval playheadPollInterval;
@property (nonatomic, assign, readwrite) MTAdState currentState;
@property (nonatomic, weak, readwrite, nullable) MTAdBreak *currentAdBreak;
@property (nonatomic, weak, readwrite, nullable) MTAdPod *currentAdPod;

/// Errors already delivered via `raisedError:`. Compared by pointer identity.
@property (nonatomic, strong) NSMutableSet<MTMergedScheduleError *> *drainedErrors;

/// AVPlayer integration state.
@property (nonatomic, weak, nullable) AVPlayer *attachedPlayer;
@property (nonatomic, strong, nullable) id periodicTimeObserverToken;

@end

@implementation MTPlayheadStateMachine

- (instancetype)initWithSchedule:(MergedSchedule *)schedule
            playheadPollInterval:(NSTimeInterval)interval {
    NSParameterAssert(schedule != nil);
    self = [super init];
    if (self) {
        _schedule = schedule;
        _playheadPollInterval = (interval > 0.0) ? interval : kDefaultPlayheadPollInterval;
        _currentState = MTAdStateContent;
        _drainedErrors = [NSMutableSet set];
    }
    return self;
}

- (void)dealloc {
    [self detachFromPlayer];
}

#pragma mark - AVPlayer integration

- (void)attachToPlayer:(AVPlayer *)player {
    NSAssert([NSThread isMainThread], @"attachToPlayer: must be called on main thread");
    if (player == nil) { return; }

    [self detachFromPlayer];

    self.attachedPlayer = player;

    CMTime interval = CMTimeMakeWithSeconds(self.playheadPollInterval, NSEC_PER_SEC);
    __weak typeof(self) weakSelf = self;
    self.periodicTimeObserverToken =
        [player addPeriodicTimeObserverForInterval:interval
                                             queue:dispatch_get_main_queue()
                                        usingBlock:^(CMTime time) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil) { return; }
            NSTimeInterval seconds = CMTimeGetSeconds(time);
            if (!isfinite(seconds) || seconds < 0.0) { return; }
            [strongSelf tickAtPositionMs:seconds * 1000.0];
        }];
}

- (void)detachFromPlayer {
    if (self.periodicTimeObserverToken != nil && self.attachedPlayer != nil) {
        [self.attachedPlayer removeTimeObserver:self.periodicTimeObserverToken];
    }
    self.periodicTimeObserverToken = nil;
    self.attachedPlayer = nil;
}

#pragma mark - State machine core

- (void)tickAtPositionMs:(NSTimeInterval)positionMs {
    NSAssert([NSThread isMainThread], @"tickAtPositionMs: must be called on main thread");

    MTAdBreak *containingBreak = [self findBreakContainingPositionMs:positionMs];

    // 1) Break-level transitions
    if (containingBreak != self.currentAdBreak) {
        [self exitCurrentPodAndBreakIfAny];
        if (containingBreak != nil) {
            [self enterBreak:containingBreak];
        }
    }

    if (self.currentAdBreak == nil) {
        // We're in CONTENT; nothing else to do.
        return;
    }

    // 2) No-fill breaks skip pod / quartile work entirely.
    if (self.currentState == MTAdStateNoFill) {
        return;
    }

    // 3) Pod-level transitions inside the current break.
    MTAdPod *containingPod = [self.currentAdBreak activePodForPositionMs:positionMs];
    if (containingPod != self.currentAdPod) {
        if (self.currentAdPod != nil) {
            [self.delegate stateMachine:self exitedPod:self.currentAdPod inBreak:self.currentAdBreak];
        }
        if (containingPod != nil) {
            [self enterPod:containingPod];
        } else {
            // Between pods or after the last pod — A6: stay InBreak.
            self.currentAdPod = nil;
            self.currentState = MTAdStateInBreak;
        }
    }

    // 4) Quartile checks for the active pod.
    if (self.currentAdPod != nil) {
        [self checkQuartilesForPod:self.currentAdPod atPositionMs:positionMs];
    }
}

- (MTAdBreak *)findBreakContainingPositionMs:(NSTimeInterval)positionMs {
    for (MTAdBreak *brk in self.schedule.breaks) {
        if ([brk containsPositionMs:positionMs]) {
            return brk;
        }
    }
    return nil;
}

- (void)exitCurrentPodAndBreakIfAny {
    if (self.currentAdPod != nil && self.currentAdBreak != nil) {
        [self.delegate stateMachine:self exitedPod:self.currentAdPod inBreak:self.currentAdBreak];
        self.currentAdPod = nil;
    }
    if (self.currentAdBreak != nil) {
        if (!self.currentAdBreak.hasFiredEnd) {
            [self.delegate stateMachine:self exitedBreak:self.currentAdBreak];
            self.currentAdBreak.hasFiredEnd = YES;
        }
        self.currentAdBreak = nil;
        self.currentState = MTAdStateContent;
    }
}

- (void)enterBreak:(MTAdBreak *)brk {
    self.currentAdBreak = brk;
    if (!brk.hasFiredStart) {
        [self.delegate stateMachine:self enteredBreak:brk];
        brk.hasFiredStart = YES;
        [self drainPendingErrorsForBreak:brk];
    }
    self.currentState = brk.isNoFill ? MTAdStateNoFill : MTAdStateInBreak;
}

- (void)enterPod:(MTAdPod *)pod {
    self.currentAdPod = pod;
    if (!pod.hasFiredStart) {
        [self.delegate stateMachine:self enteredPod:pod inBreak:self.currentAdBreak];
        pod.hasFiredStart = YES;
    }
    self.currentState = MTAdStateInPod;
}

- (void)checkQuartilesForPod:(MTAdPod *)pod atPositionMs:(NSTimeInterval)positionMs {
    if (pod.durationMs <= 0.0) { return; }
    double progress = (positionMs - pod.startTimeMs) / pod.durationMs;

    if (progress >= 0.25 && !pod.hasFiredQ1) {
        pod.hasFiredQ1 = YES;
        [self.delegate stateMachine:self crossedQuartile:1 inPod:pod inBreak:self.currentAdBreak];
    }
    if (progress >= 0.50 && !pod.hasFiredQ2) {
        pod.hasFiredQ2 = YES;
        [self.delegate stateMachine:self crossedQuartile:2 inPod:pod inBreak:self.currentAdBreak];
    }
    if (progress >= 0.75 && !pod.hasFiredQ3) {
        pod.hasFiredQ3 = YES;
        [self.delegate stateMachine:self crossedQuartile:3 inPod:pod inBreak:self.currentAdBreak];
    }
}

- (void)drainPendingErrorsForBreak:(MTAdBreak *)brk {
    for (MTMergedScheduleError *err in self.schedule.pendingErrors) {
        if (err.adBreak != brk) { continue; }
        if ([self.drainedErrors containsObject:err]) { continue; }
        [self.drainedErrors addObject:err];
        [self.delegate stateMachine:self raisedError:err];
    }
}

@end
