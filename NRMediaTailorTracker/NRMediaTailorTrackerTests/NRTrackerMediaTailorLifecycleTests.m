//
//  NRTrackerMediaTailorLifecycleTests.m
//  NRMediaTailorTrackerTests
//
//  T09 — verify lifecycle hygiene: dispose is idempotent, dealloc cleans
//  up, re-attaching swaps observers cleanly, in-flight work doesn't
//  outlive dispose.
//

#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import <NRMediaTailorTracker/NRTrackerMediaTailor.h>
#import <NRMediaTailorTracker/MTPlayheadStateMachine.h>
#import <NRMediaTailorTracker/MergedSchedule.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>


@interface NRTrackerMediaTailor (LifecycleTestingAccess)
@property (nonatomic, readonly, nullable) MTPlayheadStateMachine *stateMachine;
@end

static MergedSchedule *MTMakeTrivialSchedule(void) {
    MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:1000 durationMs:2000];
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"a" startTimeMs:1000 durationMs:2000];
    [brk.pods addObject:pod];
    return [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];
}


@interface NRTrackerMediaTailorLifecycleTests : XCTestCase
@end

@implementation NRTrackerMediaTailorLifecycleTests

/// 1. dispose is idempotent.
- (void)testDispose_idempotent {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t dispose];
    [t dispose];   // must not crash
    XCTAssertTrue(t.isDisposed);
}

/// 2. After dispose, state-machine delegate work and notifyAdSkipped no-op.
- (void)testDispose_disablesFurtherTracking {
    MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:1000 durationMs:2000];
    pod.creativeId = @"cre-1";
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"avail-1" startTimeMs:1000 durationMs:2000];
    [brk.pods addObject:pod];
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t startTrackingWithSchedule:sched];
    [t dispose];

    XCTAssertNil(t.stateMachine);
    // notifyAdSkipped after dispose is a no-op (just shouldn't crash).
    XCTAssertNoThrow([t notifyAdSkipped]);
    // startTrackingWithSchedule after dispose is a no-op.
    [t startTrackingWithSchedule:sched];
    XCTAssertNil(t.stateMachine);
}

/// 3. setPlayer with AVPlayer installs the state machine's time observer
/// (the state machine is attached only if startTracking has been called).
- (void)testSetPlayer_attachesStateMachineWhenTrackingStarted {
    AVPlayer *player = [[AVPlayer alloc] init];
    MTAdPod *pod = [[MTAdPod alloc] initWithStartTimeMs:1000 durationMs:2000];
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"x" startTimeMs:1000 durationMs:2000];
    [brk.pods addObject:pod];
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t startTrackingWithSchedule:sched];
    [t setPlayer:player];

    XCTAssertNotNil(t.stateMachine);
    XCTAssertNoThrow([t dispose]);
}

/// 4. Re-attaching a player tears down the old observer before installing
/// the new one. We just verify no crash + dispose is clean.
- (void)testSetPlayer_reAttachReplacesPreviousObserver {
    AVPlayer *p1 = [[AVPlayer alloc] init];
    AVPlayer *p2 = [[AVPlayer alloc] init];

    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t setPlayer:p1];
    [t setPlayer:p2];

    XCTAssertNoThrow([t dispose]);
}

/// 5. setPlayer with a non-AVPlayer object delegates to the superclass
/// without crashing or installing KVO.
- (void)testSetPlayer_nonAVPlayerDelegatesToSuper {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    NSObject *fakePlayer = [NSObject new];
    XCTAssertNoThrow([t setPlayer:fakePlayer]);
    XCTAssertNoThrow([t dispose]);
}

/// 6. setPlayer after dispose is a no-op.
- (void)testSetPlayer_afterDispose_isNoOp {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t dispose];
    AVPlayer *player = [[AVPlayer alloc] init];
    XCTAssertNoThrow([t setPlayer:player]);
}

/// 7. Memory leak: tracker is released after its strong references drop.
- (void)testTrackerDealloc_releasesCleanly {
    __weak NRTrackerMediaTailor *weakRef = nil;
    @autoreleasepool {
        NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
        AVPlayer *player = [[AVPlayer alloc] init];
        [t setPlayer:player];
        weakRef = t;
        XCTAssertNotNil(weakRef);
        // Dropping t at scope end should release the tracker.
        // dealloc → dispose → KVO teardown → player deref.
    }
    XCTAssertNil(weakRef, @"NRTrackerMediaTailor leaked");
}

/// 8. stopTracking does NOT detach the player; only dispose does.
- (void)testStopTracking_leavesPlayerAttached {
    AVPlayer *player = [[AVPlayer alloc] init];
    MergedSchedule *sched = [MergedSchedule empty];

    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t setPlayer:player];
    [t startTrackingWithSchedule:sched];

    [t stopTracking];

    XCTAssertNil(t.stateMachine);
    XCTAssertFalse(t.isDisposed);

    // We can still re-start tracking with the same player.
    [t startTrackingWithSchedule:sched];
    XCTAssertNotNil(t.stateMachine);

    [t dispose];
}

#pragma mark - P0-112: pollIntervalMs config

- (void)testPollIntervalMs_defaultIs250ms {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    [t startTrackingWithSchedule:MTMakeTrivialSchedule()];
    XCTAssertEqualWithAccuracy(t.stateMachine.playheadPollInterval, 0.250, 0.0001);
}

- (void)testPollIntervalMs_customValuePlumbsThrough {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    t.pollIntervalMs = 1000;
    [t startTrackingWithSchedule:MTMakeTrivialSchedule()];
    XCTAssertEqualWithAccuracy(t.stateMachine.playheadPollInterval, 1.0, 0.0001);
}

- (void)testPollIntervalMs_clampsBelowFloor {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    t.pollIntervalMs = 50;   // below 100ms floor
    [t startTrackingWithSchedule:MTMakeTrivialSchedule()];
    XCTAssertEqualWithAccuracy(t.stateMachine.playheadPollInterval, 0.100, 0.0001);
}

- (void)testPollIntervalMs_clampsAboveCeiling {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    t.pollIntervalMs = 9000;  // above 5000ms ceiling
    [t startTrackingWithSchedule:MTMakeTrivialSchedule()];
    XCTAssertEqualWithAccuracy(t.stateMachine.playheadPollInterval, 5.0, 0.0001);
}

#pragma mark - P0-111: trackingUrl override

- (void)testResolvedTrackingURL_overrideUsedVerbatim {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    t.trackingUrl = @"https://custom.cdn.example/track/session-1";
    NSURL *manifest = [NSURL URLWithString:@"https://x.mediatailor.us-east-1.amazonaws.com/v1/master/a/b.m3u8?aws.sessionId=SID"];
    XCTAssertEqualObjects([t resolvedTrackingURLForManifestURL:manifest].absoluteString,
                          @"https://custom.cdn.example/track/session-1");
}

- (void)testResolvedTrackingURL_fallsBackToDerivation {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];  // no override
    NSURL *manifest = [NSURL URLWithString:@"https://x.mediatailor.us-east-1.amazonaws.com/v1/master/a/b.m3u8?aws.sessionId=SID"];
    NSURL *resolved = [t resolvedTrackingURLForManifestURL:manifest];
    XCTAssertNotNil(resolved);
    XCTAssertTrue([resolved.absoluteString containsString:@"/v1/tracking/"],
                  @"fallback should derive a /v1/tracking/ URL");
}

- (void)testResolvedTrackingURL_nilWhenNoOverrideAndNotDerivable {
    NRTrackerMediaTailor *t = [[NRTrackerMediaTailor alloc] init];
    XCTAssertNil([t resolvedTrackingURLForManifestURL:nil]);
}

@end
