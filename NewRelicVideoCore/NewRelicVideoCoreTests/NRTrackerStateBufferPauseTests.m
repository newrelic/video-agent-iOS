//
//  NRTrackerStateBufferPauseTests.m
//  NewRelicVideoCoreTests
//
//  Regression tests for premature/missing CONTENT_BUFFER_END on pause-during-rebuffer, and the isPlaying corruption it exposed in goBufferEnd/goSeekEnd.
//

@import XCTest;
#import "NRTrackerState.h"

@interface NRTrackerStateBufferPauseTests : XCTestCase
@end

@implementation NRTrackerStateBufferPauseTests

// goBufferEnd must succeed on isBuffering alone — isPaused can't be YES before the first isStarted.
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

// Closing a buffer window while paused must not flip isPlaying back to YES.
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

// No-regression: closing a buffer window while playing still sets isPlaying = YES.
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

// Closing a seek window while paused must not flip isPlaying back to YES (undoing a prior paused goBufferEnd).
- (void)testSeekEndWhilePausedLeavesIsPlayingFalse {
    NRTrackerState *state = [[NRTrackerState alloc] init];

    XCTAssertTrue([state goRequest]);
    XCTAssertTrue([state goStart]);
    XCTAssertTrue([state goPause]);
    XCTAssertTrue([state goSeekStart]);

    XCTAssertTrue(state.isPaused);

    XCTAssertTrue([state goSeekEnd]);

    XCTAssertTrue(state.isPaused, @"pause must still be in effect after the seek window closes");
    XCTAssertFalse(state.isPlaying, @"isPlaying must stay NO — closing a seek window must not resume playback while paused");
}

// No-regression: closing a seek window while playing still sets isPlaying = YES.
- (void)testSeekEndWhilePlayingSetsIsPlayingTrue {
    NRTrackerState *state = [[NRTrackerState alloc] init];

    XCTAssertTrue([state goRequest]);
    XCTAssertTrue([state goStart]);
    XCTAssertTrue([state goSeekStart]);

    XCTAssertFalse(state.isPaused);

    XCTAssertTrue([state goSeekEnd]);

    XCTAssertFalse(state.isPaused);
    XCTAssertTrue(state.isPlaying, @"isPlaying must be YES again once a seek resolves while the user was playing, not paused");
}

@end
