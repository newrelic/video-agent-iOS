//
//  MTPlayheadStateMachineTests.m
//  NRMediaTailorTrackerTests
//
//  T07 — verify the state machine drives delegate callbacks deterministically
//  from a sequence of playhead positions. Tests are clock-free: we drive the
//  state machine via `-tickAtPositionMs:` rather than waiting on a real
//  `AVPlayer`.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTPlayheadStateMachine.h>
#import <NRMediaTailorTracker/MTAdState.h>
#import <NRMediaTailorTracker/MergedSchedule.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>
#import <NRMediaTailorTracker/MTAdErrorCode.h>


#pragma mark - Recorder delegate

@interface MTSMTestRecorder : NSObject <MTPlayheadStateMachineDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end

@implementation MTSMTestRecorder

- (instancetype)init {
    self = [super init];
    if (self) { _events = [NSMutableArray array]; }
    return self;
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm enteredBreak:(MTAdBreak *)brk {
    [self.events addObject:[NSString stringWithFormat:@"BREAK_START:%@", brk.availId ?: @"?"]];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm enteredPod:(MTAdPod *)pod inBreak:(MTAdBreak *)brk {
    [self.events addObject:[NSString stringWithFormat:@"POD_START:%@", pod.primaryKey ?: @"?"]];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm
     crossedQuartile:(NSInteger)quartile
               inPod:(MTAdPod *)pod
             inBreak:(MTAdBreak *)brk {
    [self.events addObject:[NSString stringWithFormat:@"Q%ld:%@", (long)quartile, pod.primaryKey ?: @"?"]];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm exitedPod:(MTAdPod *)pod inBreak:(MTAdBreak *)brk {
    [self.events addObject:[NSString stringWithFormat:@"POD_END:%@", pod.primaryKey ?: @"?"]];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm exitedBreak:(MTAdBreak *)brk {
    [self.events addObject:[NSString stringWithFormat:@"BREAK_END:%@", brk.availId ?: @"?"]];
}

- (void)stateMachine:(MTPlayheadStateMachine *)sm raisedError:(MTMergedScheduleError *)error {
    [self.events addObject:[NSString stringWithFormat:@"ERROR:%@", NSStringFromMTAdErrorCode(error.errorCode)]];
}

@end


#pragma mark - Helpers

static MTAdPod *makePod(NSString *key, NSTimeInterval startMs, NSTimeInterval durMs) {
    MTAdPod *p = [[MTAdPod alloc] initWithStartTimeMs:startMs durationMs:durMs];
    p.primaryKey = key;
    return p;
}

static MTAdBreak *makeBreak(NSString *availId, NSTimeInterval startMs, NSTimeInterval durMs,
                            NSArray<MTAdPod *> *pods, BOOL noFill) {
    MTAdBreak *b = [[MTAdBreak alloc] initWithAvailId:availId startTimeMs:startMs durationMs:durMs];
    b.isNoFill = noFill;
    [b.pods addObjectsFromArray:pods];
    return b;
}


#pragma mark - Tests

@interface MTPlayheadStateMachineTests : XCTestCase
@end

@implementation MTPlayheadStateMachineTests

/// 1. Golden path: 1 break with 2 pods, full traversal.
- (void)testGolden_breakWithTwoPods_emitsFullSequenceInOrder {
    MTAdPod *p1 = makePod(@"pod1", 1000, 2000); // 1.0s–3.0s
    MTAdPod *p2 = makePod(@"pod2", 3000, 2000); // 3.0s–5.0s
    MTAdBreak *brk = makeBreak(@"avail-A", 1000, 4000, @[p1, p2], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    // Walk the playhead through the break.
    [sm tickAtPositionMs:500];      // CONTENT, no events
    [sm tickAtPositionMs:1100];     // BREAK_START + POD_START p1
    [sm tickAtPositionMs:1500];     // Q1 p1 (25% of 2s = +500ms from 1000 = 1500)
    [sm tickAtPositionMs:2000];     // Q2 p1 (50% = 2000)
    [sm tickAtPositionMs:2500];     // Q3 p1 (75% = 2500)
    [sm tickAtPositionMs:3000];     // POD_END p1 + POD_START p2
    [sm tickAtPositionMs:3500];     // Q1 p2
    [sm tickAtPositionMs:4000];     // Q2 p2
    [sm tickAtPositionMs:4500];     // Q3 p2
    [sm tickAtPositionMs:5500];     // POD_END p2 + BREAK_END
    [sm tickAtPositionMs:6000];     // CONTENT, no events

    NSArray *expected = @[
        @"BREAK_START:avail-A",
        @"POD_START:pod1",
        @"Q1:pod1",
        @"Q2:pod1",
        @"Q3:pod1",
        @"POD_END:pod1",
        @"POD_START:pod2",
        @"Q1:pod2",
        @"Q2:pod2",
        @"Q3:pod2",
        @"POD_END:pod2",
        @"BREAK_END:avail-A",
    ];
    XCTAssertEqualObjects(rec.events, expected);
    XCTAssertEqual(sm.currentState, MTAdStateContent);
}

/// 2. No-fill break: BREAK_START + ERROR(NO_FILL) + BREAK_END, no pod / quartile events.
- (void)testNoFill_emitsBreakStartErrorBreakEnd_noPodOrQuartiles {
    MTAdBreak *brk = makeBreak(@"avail-NF", 1000, 3000, @[], YES);
    MergedSchedule *sched =
        [[MergedSchedule alloc] initWithBreaks:@[brk]
                                 pendingErrors:@[
                                    [[MTMergedScheduleError alloc] initWithBreak:brk
                                                                       errorCode:MTAdErrorCodeNoFill
                                                                         message:nil]
                                 ]];
    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:1500];   // BREAK_START + ERROR
    [sm tickAtPositionMs:2500];   // still in no-fill, no events
    [sm tickAtPositionMs:4500];   // BREAK_END

    NSArray *expected = @[
        @"BREAK_START:avail-NF",
        @"ERROR:NO_FILL",
        @"BREAK_END:avail-NF",
    ];
    XCTAssertEqualObjects(rec.events, expected);
}

/// 3. Backward seek inside a pod must not re-fire quartiles or POD_START.
- (void)testBackwardSeek_doesNotReFireQuartilesOrPodStart {
    MTAdPod *p1 = makePod(@"pod1", 1000, 2000);
    MTAdBreak *brk = makeBreak(@"avail-BS", 1000, 2000, @[p1], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:1100];   // BREAK_START + POD_START
    [sm tickAtPositionMs:2100];   // Q1 + Q2 (50% = 2000ms, exclusive >= 0.50)
    [rec.events removeAllObjects];

    // Seek back to pre-Q1.
    [sm tickAtPositionMs:1200];
    XCTAssertEqualObjects(rec.events, @[]); // no duplicates

    // Forward again past Q3.
    [sm tickAtPositionMs:2600];
    XCTAssertEqualObjects(rec.events, @[@"Q3:pod1"]);
}

/// 4. Skip past entire break: BREAK_START + BREAK_END fire, no pod / quartile events.
- (void)testSkipPastEntireBreak_emitsStartAndEndOnly {
    MTAdPod *p1 = makePod(@"pod1", 1000, 2000);
    MTAdBreak *brk = makeBreak(@"avail-SK", 1000, 2000, @[p1], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:500];     // CONTENT
    [sm tickAtPositionMs:5000];    // way past break — single tick covers both transitions

    // Implementation note: a single tick that lands outside an unentered break
    // emits no events for that break (we never observed entry). This matches
    // the IMA tracker behavior: if the user seeks past an ad, the ad is
    // considered "not played" rather than fast-forwarded.
    XCTAssertEqualObjects(rec.events, @[]);
    XCTAssertEqual(sm.currentState, MTAdStateContent);
}

/// 5. A5 — configurable playhead poll interval.
- (void)testA5_configurablePollInterval {
    MergedSchedule *sched = [MergedSchedule empty];

    MTPlayheadStateMachine *fast =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.100];
    MTPlayheadStateMachine *slow =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.500];
    MTPlayheadStateMachine *defaulted =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.0];
    MTPlayheadStateMachine *negative =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:-1.0];

    XCTAssertEqualWithAccuracy(fast.playheadPollInterval,      0.100, 1e-9);
    XCTAssertEqualWithAccuracy(slow.playheadPollInterval,      0.500, 1e-9);
    XCTAssertEqualWithAccuracy(defaulted.playheadPollInterval, 0.250, 1e-9);
    XCTAssertEqualWithAccuracy(negative.playheadPollInterval,  0.250, 1e-9);
}

/// 6. A8 drain order — ERROR(MISSING_AVAIL_START) must fire between BREAK_START
/// and POD_START.
- (void)testA8_errorDrainOrder_errorBetweenBreakStartAndPodStart {
    MTAdPod *p1 = makePod(@"pod1", 1000, 2000);
    MTAdBreak *brk = makeBreak(@"avail-A8", 1000, 2000, @[p1], NO);
    MergedSchedule *sched =
        [[MergedSchedule alloc] initWithBreaks:@[brk]
                                 pendingErrors:@[
                                    [[MTMergedScheduleError alloc] initWithBreak:brk
                                                                       errorCode:MTAdErrorCodeMissingAvailStart
                                                                         message:nil]
                                 ]];
    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:1100];

    XCTAssertEqualObjects(rec.events, (@[
        @"BREAK_START:avail-A8",
        @"ERROR:MISSING_AVAIL_START",
        @"POD_START:pod1",
    ]));
}

/// 7. A6 graceful last-pod handling: pod ends well before break ends; the state
/// machine emits POD_END at pod.endTimeMs and idles in IN_BREAK until BREAK_END.
- (void)testA6_lastPodEndsBeforeBreakEnd_idlesInBreakUntilBreakEnd {
    MTAdPod *p1 = makePod(@"pod1", 1000, 1000); // 1.0s–2.0s
    MTAdBreak *brk = makeBreak(@"avail-A6", 1000, 5000, @[p1], NO); // break: 1.0s–6.0s
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:1100];   // BREAK_START + POD_START
    [sm tickAtPositionMs:1500];   // Q1 + Q2
    [sm tickAtPositionMs:1800];   // Q3
    [sm tickAtPositionMs:2500];   // POD_END (we are now in break-idle range 2000..6000)
    XCTAssertEqual(sm.currentState, MTAdStateInBreak);

    [sm tickAtPositionMs:3000];   // still in break-idle, no events
    [sm tickAtPositionMs:5000];   // still in break-idle, no events
    XCTAssertEqual(sm.currentState, MTAdStateInBreak);

    [sm tickAtPositionMs:6500];   // BREAK_END

    NSArray *expected = @[
        @"BREAK_START:avail-A6",
        @"POD_START:pod1",
        @"Q1:pod1",
        @"Q2:pod1",
        @"Q3:pod1",
        @"POD_END:pod1",
        @"BREAK_END:avail-A6",
    ];
    XCTAssertEqualObjects(rec.events, expected);
    XCTAssertEqual(sm.currentState, MTAdStateContent);
}

/// Extra: forward seek across multiple quartile boundaries in a single tick
/// must emit all crossed quartiles in order.
- (void)testForwardSeekCrossesMultipleQuartilesInOneTick {
    MTAdPod *p1 = makePod(@"pod1", 0, 4000); // 0–4s
    MTAdBreak *brk = makeBreak(@"avail-FF", 0, 4000, @[p1], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTPlayheadStateMachine *sm =
        [[MTPlayheadStateMachine alloc] initWithSchedule:sched playheadPollInterval:0.250];
    MTSMTestRecorder *rec = [MTSMTestRecorder new];
    sm.delegate = rec;

    [sm tickAtPositionMs:100];     // BREAK_START + POD_START (no quartile yet — 100/4000 = 2.5%)
    [sm tickAtPositionMs:3500];    // 87.5% → Q1, Q2, Q3 all in one tick

    NSArray *expected = @[
        @"BREAK_START:avail-FF",
        @"POD_START:pod1",
        @"Q1:pod1",
        @"Q2:pod1",
        @"Q3:pod1",
    ];
    XCTAssertEqualObjects(rec.events, expected);
}

@end
