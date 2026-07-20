//
//  NRTrackerMediaTailorEventTests.m
//  NRMediaTailorTrackerTests
//
//  T08 — verify the tracker emits the correct event sequence and attributes
//  in response to state-machine transitions. We subclass NRTrackerMediaTailor
//  to intercept NRVideoTracker's sendXxx calls without going to the network.
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/NRTrackerMediaTailor.h>
#import <NRMediaTailorTracker/MTPlayheadStateMachine.h>
#import <NRMediaTailorTracker/MergedSchedule.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>
#import <NRMediaTailorTracker/MTAdErrorCode.h>


/// Re-declare the private `stateMachine` property so tests can drive it
/// directly via `-tickAtPositionMs:`. The actual storage lives in the
/// class extension inside NRTrackerMediaTailor.m; this category only
/// exposes the synthesized accessor for the compiler's benefit.
@interface NRTrackerMediaTailor (TestingAccess)
@property (nonatomic, readonly, nullable) MTPlayheadStateMachine *stateMachine;
@end


#pragma mark - Recording tracker subclass

@interface MTRecordingTracker : NRTrackerMediaTailor
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *lastAttributesByEvent;
@end

@implementation MTRecordingTracker

- (instancetype)init {
    self = [super init];
    if (self) {
        _events = [NSMutableArray array];
        _lastAttributesByEvent = [NSMutableArray array];
    }
    return self;
}

- (void)recordEvent:(NSString *)name {
    [self.events addObject:name];
    NSDictionary *snapshot = [[self getAttributes:name attributes:nil] copy];
    [self.lastAttributesByEvent addObject:snapshot];
}

- (void)sendAdBreakStart        { [self recordEvent:@"AD_BREAK_START"]; }
- (void)sendAdBreakEnd          { [self recordEvent:@"AD_BREAK_END"];   }
- (void)sendRequest             { [self recordEvent:@"AD_REQUEST"];     }
- (void)sendStart               { [self recordEvent:@"AD_START"];       }
- (void)sendEnd                 { [self recordEvent:@"AD_END"];         }
- (void)sendAdQuartile          {
    NSDictionary *snapshot = [[self getAttributes:@"AD_QUARTILE" attributes:nil] copy];
    NSNumber *q = snapshot[@"adQuartile"] ?: [self getAdQuartile];
    [self.events addObject:[NSString stringWithFormat:@"AD_QUARTILE:%@", q ?: @"?"]];
    [self.lastAttributesByEvent addObject:snapshot];
}

- (void)sendVideoAdEvent:(NSString *)action {
    [self recordEvent:action];
}

- (void)sendVideoErrorEvent:(NSString *)action attributes:(NSDictionary *)attributes {
    NSString *code = attributes[@"errorCode"] ?: @"?";
    [self.events addObject:[NSString stringWithFormat:@"%@:%@", action, code]];
    NSMutableDictionary *snapshot = [[self getAttributes:action attributes:attributes] mutableCopy];
    [snapshot addEntriesFromDictionary:attributes ?: @{}];
    [self.lastAttributesByEvent addObject:[snapshot copy]];
}

@end


#pragma mark - Helpers

static MTAdPod *MakePod(NSString *creativeId, NSString *adId, NSTimeInterval startMs, NSTimeInterval durMs) {
    MTAdPod *p = [[MTAdPod alloc] initWithStartTimeMs:startMs durationMs:durMs];
    p.creativeId = creativeId;
    p.adId = adId;
    p.primaryKey = creativeId ?: adId;
    p.adTitle = @"Test Ad";
    p.adSystem = @"FreeWheel";
    p.vastAdId = @"vast-123";
    return p;
}

static MTAdBreak *MakeBreak(NSString *availId, NSTimeInterval startMs, NSTimeInterval durMs,
                            NSArray<MTAdPod *> *pods, BOOL noFill) {
    MTAdBreak *b = [[MTAdBreak alloc] initWithAvailId:availId startTimeMs:startMs durationMs:durMs];
    b.isNoFill = noFill;
    [b.pods addObjectsFromArray:pods];
    return b;
}


#pragma mark - Tests

@interface NRTrackerMediaTailorEventTests : XCTestCase
@end

@implementation NRTrackerMediaTailorEventTests

/// 1. Golden: 1 break + 1 pod walked through quartiles → full IMA-parity sequence.
- (void)testGolden_breakAndPod_emitsFullEventSequence {
    MTAdPod *pod = MakePod(@"cre-1", @"ad-1", 1000, 2000);
    MTAdBreak *brk = MakeBreak(@"avail-A", 1000, 2000, @[pod], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];

    [t.stateMachine tickAtPositionMs:1100];   // BREAK_START, AD_REQUEST, AD_START
    [t.stateMachine tickAtPositionMs:1500];   // Q1
    [t.stateMachine tickAtPositionMs:2000];   // Q2
    [t.stateMachine tickAtPositionMs:2500];   // Q3
    [t.stateMachine tickAtPositionMs:3500];   // AD_END, AD_BREAK_END

    NSArray *expected = @[
        @"AD_BREAK_START",
        @"AD_REQUEST",
        @"AD_START",
        @"AD_QUARTILE:1",
        @"AD_QUARTILE:2",
        @"AD_QUARTILE:3",
        @"AD_END",
        @"AD_BREAK_END",
    ];
    XCTAssertEqualObjects(t.events, expected);
}

/// 2. No-fill: AD_BREAK_START → AD_ERROR(NO_FILL) → AD_BREAK_END. No AD_START / quartile.
- (void)testNoFill_emitsBreakStartErrorBreakEnd {
    MTAdBreak *brk = MakeBreak(@"avail-NF", 1000, 3000, @[], YES);
    MergedSchedule *sched =
        [[MergedSchedule alloc] initWithBreaks:@[brk]
                                 pendingErrors:@[
                                    [[MTMergedScheduleError alloc] initWithBreak:brk
                                                                       errorCode:MTAdErrorCodeNoFill
                                                                         message:nil]
                                 ]];
    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];

    [t.stateMachine tickAtPositionMs:1500];
    [t.stateMachine tickAtPositionMs:4500];

    NSArray *expected = @[
        @"AD_BREAK_START",
        @"AD_ERROR:NO_FILL",
        @"AD_BREAK_END",
    ];
    XCTAssertEqualObjects(t.events, expected);
}

/// 3. B6 — every documented MTAdErrorCode round-trips through AD_ERROR
/// with its canonical string in the errorCode attribute.
- (void)testB6_everyErrorCodeEmitsAdError {
    MTAdErrorCode codes[] = {
        MTAdErrorCodeAdsTimeout,
        MTAdErrorCodeTrackingFetchFailed,
        MTAdErrorCodeTokenExpired,
        MTAdErrorCodeNoFill,
        MTAdErrorCodeMissingAvailStart,
        MTAdErrorCodeManifestParseFailed,
        MTAdErrorCodeManifestTrackingMismatch,
    };

    for (size_t i = 0; i < sizeof(codes)/sizeof(codes[0]); i++) {
        MTAdErrorCode code = codes[i];
        MTAdBreak *brk = MakeBreak(@"avail-X", 1000, 1000, @[], YES);
        MergedSchedule *sched =
            [[MergedSchedule alloc] initWithBreaks:@[brk]
                                     pendingErrors:@[
                                        [[MTMergedScheduleError alloc] initWithBreak:brk
                                                                           errorCode:code
                                                                             message:@"diag"]
                                     ]];

        MTRecordingTracker *t = [MTRecordingTracker new];
        [t startTrackingWithSchedule:sched];
        [t.stateMachine tickAtPositionMs:1500];

        NSString *expected = [NSString stringWithFormat:@"AD_ERROR:%@", NSStringFromMTAdErrorCode(code)];
        XCTAssertTrue([t.events containsObject:expected],
                      @"Code %ld: did not see %@ in %@", (long)code, expected, t.events);
    }
}

/// 4. B7 — adProgramDateTime and availProgramDateTime are ALWAYS in the
/// attribute dict, even when the source values are nil (empty string).
- (void)testB7_liveProgramDateTimeAlwaysEmitted {
    MTAdPod *pod = MakePod(@"cre-1", @"ad-1", 1000, 2000);
    pod.adProgramDateTime = nil;
    MTAdBreak *brk = MakeBreak(@"avail-L", 1000, 2000, @[pod], NO);
    brk.availProgramDateTime = nil;
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];
    [t.stateMachine tickAtPositionMs:1100];   // AD_BREAK_START + AD_REQUEST + AD_START

    XCTAssertGreaterThan(t.lastAttributesByEvent.count, 0u);
    for (NSDictionary *attrs in t.lastAttributesByEvent) {
        XCTAssertNotNil(attrs[@"availProgramDateTime"], @"availProgramDateTime missing in %@", attrs);
        XCTAssertNotNil(attrs[@"adProgramDateTime"], @"adProgramDateTime missing in %@", attrs);
    }
}

/// 5. Pod-level attributes flow through on AD_START.
- (void)testPodAttributes_landOnAdStart {
    MTAdPod *pod = MakePod(@"cre-7", @"ad-9", 1000, 2000);
    pod.adSystem = @"GDFP";
    pod.creativeSequence = @"1";
    pod.skipOffset = @"00:00:05";
    MTAdBreak *brk = MakeBreak(@"avail-P", 1000, 2000, @[pod], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];
    [t.stateMachine tickAtPositionMs:1100];

    NSUInteger startIdx = [t.events indexOfObject:@"AD_START"];
    XCTAssertNotEqual(startIdx, NSNotFound);
    NSDictionary *attrs = t.lastAttributesByEvent[startIdx];
    XCTAssertEqualObjects(attrs[@"creativeId"], @"cre-7");
    XCTAssertEqualObjects(attrs[@"adId"], @"ad-9");
    XCTAssertEqualObjects(attrs[@"adSystem"], @"GDFP");
    XCTAssertEqualObjects(attrs[@"creativeSequence"], @"1");
    XCTAssertEqualObjects(attrs[@"skipOffset"], @"00:00:05");
    XCTAssertEqualObjects(attrs[@"vastAdId"], @"vast-123");
}

/// 6. AD_SKIP fires when notifyAdSkipped is called inside a pod.
- (void)testNotifyAdSkipped_firesAdSkip {
    MTAdPod *pod = MakePod(@"cre-1", @"ad-1", 1000, 2000);
    MTAdBreak *brk = MakeBreak(@"avail-S", 1000, 2000, @[pod], NO);
    MergedSchedule *sched = [[MergedSchedule alloc] initWithBreaks:@[brk] pendingErrors:@[]];

    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];
    [t.stateMachine tickAtPositionMs:1100];   // enter pod
    [t.events removeAllObjects];
    [t.lastAttributesByEvent removeAllObjects];

    [t notifyAdSkipped];
    XCTAssertEqualObjects(t.events, @[@"AD_SKIP"]);
}

/// 7. notifyAdSkipped is a no-op outside an active pod.
- (void)testNotifyAdSkipped_outsidePod_isNoOp {
    MergedSchedule *sched = [MergedSchedule empty];
    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:sched];

    [t notifyAdSkipped];
    XCTAssertEqualObjects(t.events, @[]);
}

/// 8. stopTracking is idempotent and clears state.
- (void)testStopTracking_idempotent {
    MTRecordingTracker *t = [MTRecordingTracker new];
    [t startTrackingWithSchedule:[MergedSchedule empty]];
    [t stopTracking];
    [t stopTracking]; // should not crash
    XCTAssertNil(t.stateMachine);
}

@end
