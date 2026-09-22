//
//  NRTrackerStateBufferPauseTests.m
//  NewRelicVideoCoreTests
//
//  Regression tests for NR-531411: CONTENT_BUFFER_END was getting sent
//  prematurely (or, in the initial-load case, never at all until resume) when
//  the user paused while a rebuffer was still in progress.
//
//  Two independent bugs in NRTrackerState were involved:
//
//  1. goBufferEnd's success previously had no direct relationship with
//     whether the caller had gated on isPaused vs isBuffering: callers up in
//     NRTrackerAVPlayer used to require isPaused == YES before calling
//     goBufferEnd while the user was paused. isPaused can only become true
//     after goStart has run at least once (it requires isStarted), so if the
//     user pauses during the very first buffering window — before the first
//     frame has ever rendered — isPaused is permanently stuck at NO and the
//     buffer-close was never even attempted, leaving CONTENT_BUFFER_END
//     stuck until resume. The fix re-gates the callers on isBuffering
//     instead, and this test locks in that goBufferEnd itself succeeds based
//     on isBuffering alone, regardless of isPaused/isStarted.
//
//  2. goBufferEnd used to unconditionally set isPlaying = true when closing
//     the buffer window, even if the user was still paused at that moment.
//     That corrupts the state machine into isPaused == YES && isPlaying ==
//     YES, which downstream consumers (NRVideoTracker's chrono/heartbeat,
//     NRQoEAggregator's bitrate timer) read as "resume", incorrectly
//     restarting playtime/bitrate timers mid-pause. The fix makes
//     isPlaying reflect !isPaused instead of an unconditional true.
//

@import XCTest;
#import "NRTrackerState.h"

@interface NRTrackerStateBufferPauseTests : XCTestCase
@end

@implementation NRTrackerStateBufferPauseTests

// Finding 1: buffering that starts and resolves before the first goStart
// (i.e. before isStarted/isPaused can ever be YES) must still be closeable.
// goBufferEnd must succeed purely on isBuffering, independent of isPaused
// or isStarted.
- (void)testBufferEndSucceedsDuringInitialLoadBeforeStartRegardlessOfPauseState {
    NRTrackerState *state = [[NRTrackerState alloc] init];

    XCTAssertTrue([state goRequest]);
    XCTAssertTrue([state goBufferStart]);

    XCTAssertTrue(state.isRequested);
    XCTAssertTrue(state.isBuffering);
    XCTAssertFalse(state.isStarted, @"isStarted must still be NO — playback has never started");
    XCTAssertFalse(state.isPaused, @"isPaused can never become YES before isStarted — this is the stuck condition from finding 1");

    BOOL bufferEndSucceeded = [state goBufferEnd];

    XCTAssertTrue(bufferEndSucceeded, @"goBufferEnd must succeed based on isBuffering alone, not isPaused/isStarted");
    XCTAssertFalse(state.isBuffering, @"isBuffering must be cleared once the buffer window closes");
}

// Finding 2: closing a buffer window while genuinely paused must not flip
// isPlaying back to YES.
- (void)testBufferEndWhilePausedLeavesIsPlayingFalse {
    NRTrackerState *state = [[NRTrackerState alloc] init];

    XCTAssertTrue([state goRequest]);
    XCTAssertTrue([state goStart]);
    XCTAssertTrue([state goPause]);
    XCTAssertTrue([state goBufferStart]);

    XCTAssertTrue(state.isPaused);

    XCTAssertTrue([state goBufferEnd]);

    XCTAssertTrue(state.isPaused, @"pause must still be in effect after the buffer window closes");
    XCTAssertFalse(state.isPlaying, @"isPlaying must stay NO — closing a buffer window must not resume playback while paused");
}

// AC2 no-regression check: closing a buffer window while actually playing
// (never paused) must still correctly re-assert isPlaying = YES.
- (void)testBufferEndWhilePlayingSetsIsPlayingTrue {
    NRTrackerState *state = [[NRTrackerState alloc] init];

    XCTAssertTrue([state goRequest]);
    XCTAssertTrue([state goStart]);
    XCTAssertTrue([state goBufferStart]);

    XCTAssertFalse(state.isPaused);

    XCTAssertTrue([state goBufferEnd]);

    XCTAssertFalse(state.isPaused);
    XCTAssertTrue(state.isPlaying, @"isPlaying must be YES again once buffering resolves while the user was playing, not paused");
}

@end
