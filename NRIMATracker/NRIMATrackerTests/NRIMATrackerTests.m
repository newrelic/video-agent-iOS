//
//  NRIMATrackerTests.m
//  NRIMATrackerTests
//
//  Unit tests for NRTrackerIMA: client-side ads (CSAI) and Dynamic Ad Insertion (DAI).
//
//  IMAAdEvent, IMAAd, IMAAdPodInfo and IMAAdError cannot be created by the host app
//  (their initializers are unavailable), so the tests use hand-written subclasses that
//  override the read-only properties NRTrackerIMA reads. The recording tracker captures
//  the actions the tracker would send, without a harvest manager or network.
//

#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>
#import "NRTrackerIMA.h"

#pragma mark - IMA fakes

@interface FakePodInfo : IMAAdPodInfo
@property (nonatomic) NSInteger fakePodIndex;
@property (nonatomic) NSTimeInterval fakeTimeOffset;
@end
@implementation FakePodInfo
- (NSInteger)podIndex { return self.fakePodIndex; }
- (NSTimeInterval)timeOffset { return self.fakeTimeOffset; }
@end

@interface FakeAd : IMAAd
@property (nonatomic, copy) NSString *fakeTitle;
@property (nonatomic, copy) NSString *fakeCreativeId;
@property (nonatomic, copy) NSString *fakeAdId;
@property (nonatomic) NSInteger fakeBitrate;
@property (nonatomic) NSTimeInterval fakeDuration;
@property (nonatomic, strong) FakePodInfo *fakePod;
@end
@implementation FakeAd
- (NSString *)adTitle { return self.fakeTitle; }
- (NSString *)creativeID { return self.fakeCreativeId; }
- (NSString *)adId { return self.fakeAdId; }
- (NSTimeInterval)duration { return self.fakeDuration; }
- (IMAAdPodInfo *)adPodInfo { return self.fakePod; }
- (NSInteger)VASTMediaWidth { return 640; }
- (NSInteger)VASTMediaHeight { return 360; }
- (NSInteger)VASTMediaBitrate { return self.fakeBitrate; }
@end

@interface FakeEvent : IMAAdEvent
@property (nonatomic) IMAAdEventType fakeType;
@property (nonatomic, strong) FakeAd *fakeAd;
@end
@implementation FakeEvent
- (IMAAdEventType)type { return self.fakeType; }
- (NSString *)typeString { return @"fake"; }
- (IMAAd *)ad { return self.fakeAd; }
@end

@interface FakeError : IMAAdError
@property (nonatomic) IMAErrorType fakeType;
@property (nonatomic) IMAErrorCode fakeCode;
@property (nonatomic, copy) NSString *fakeMessage;
@end
@implementation FakeError
- (IMAErrorType)type { return self.fakeType; }
- (IMAErrorCode)code { return self.fakeCode; }
- (NSString *)message { return self.fakeMessage; }
@end

#pragma mark - Recording tracker

@interface RecordedAction : NSObject
@property (nonatomic, copy) NSString *action;
@property (nonatomic, copy) NSDictionary *attributes;
@end
@implementation RecordedAction
@end

@interface RecordingIMATracker : NRTrackerIMA
@property (nonatomic, strong) NSMutableArray<RecordedAction *> *recorded;
@end

@implementation RecordingIMATracker

- (instancetype)init {
    if (self = [super init]) {
        _recorded = [NSMutableArray array];
        [self.state setIsAd:YES];
    }
    return self;
}

- (void)record:(NSString *)action attributes:(NSDictionary *)attributes {
    RecordedAction *r = [[RecordedAction alloc] init];
    r.action = action;
    r.attributes = [self getAttributes:action attributes:attributes];
    [self.recorded addObject:r];
}

- (void)sendVideoAdEvent:(NSString *)action attributes:(NSDictionary *)attributes {
    [self record:action attributes:attributes];
}

- (void)sendVideoErrorEvent:(NSString *)action attributes:(NSDictionary *)attributes {
    [self record:action attributes:attributes];
}

// No heartbeat timer in unit tests.
- (void)startHeartbeat {}

- (NSArray<NSString *> *)actions {
    NSMutableArray *a = [NSMutableArray array];
    for (RecordedAction *r in self.recorded) { [a addObject:r.action]; }
    return a;
}

- (RecordedAction *)lastRecorded { return self.recorded.lastObject; }

@end

#pragma mark - Tests

@interface NRIMATrackerTests : XCTestCase
@end

@interface NRTrackerIMA (TestAccess)
- (void)daiPlayerTimeControlStatusChanged:(AVPlayerTimeControlStatus)status;
@end

@implementation NRIMATrackerTests

- (FakeAd *)adWithTitle:(NSString *)title timeOffset:(NSTimeInterval)offset podIndex:(NSInteger)podIndex {
    FakePodInfo *pod = [FakePodInfo alloc];
    pod.fakePodIndex = podIndex;
    pod.fakeTimeOffset = offset;
    FakeAd *ad = [FakeAd alloc];
    ad.fakeTitle = title;
    ad.fakeCreativeId = @"creative-1";
    ad.fakeAdId = [@"ad-" stringByAppendingString:title];
    ad.fakeBitrate = 800;
    ad.fakeDuration = 15;
    ad.fakePod = pod;
    return ad;
}

- (FakeEvent *)event:(IMAAdEventType)type ad:(FakeAd *)ad {
    FakeEvent *e = [FakeEvent alloc];
    e.fakeType = type;
    e.fakeAd = ad;
    return e;
}

- (RecordingIMATracker *)daiTracker {
    RecordingIMATracker *t = [[RecordingIMATracker alloc] init];
    [t configureWithAdConfig:[NRAdConfig ssaiIma] player:nil];
    return t;
}

- (RecordingIMATracker *)csaiTracker {
    RecordingIMATracker *t = [[RecordingIMATracker alloc] init];
    [t configureWithAdConfig:[NRAdConfig csai] player:nil];
    return t;
}

#pragma mark DAI lifecycle

- (void)testDaiFullLifecycleEmitsRequestStartQuartilesEnd {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];

    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_FIRST_QUARTILE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_MIDPOINT ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_THIRD_QUARTILE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_COMPLETE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_ENDED ad:nil] streamManager:nil];

    NSArray *expected = @[@"AD_BREAK_START", @"AD_REQUEST", @"AD_START", @"AD_QUARTILE", @"AD_QUARTILE",
                          @"AD_QUARTILE", @"AD_END", @"AD_BREAK_END"];
    XCTAssertEqualObjects([t actions], expected);
}

- (void)testDaiQuartileAttributeProgresses {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t getAdQuartile], @0);
    [t streamAdEvent:[self event:kIMAAdEvent_FIRST_QUARTILE ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"adQuartile"], @1);
    [t streamAdEvent:[self event:kIMAAdEvent_MIDPOINT ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"adQuartile"], @2);
    [t streamAdEvent:[self event:kIMAAdEvent_THIRD_QUARTILE ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"adQuartile"], @3);
}

- (void)testDaiEventsCarryStreamTypeAndAdMetadata {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];

    NSDictionary *attrs = [t lastRecorded].attributes;
    XCTAssertEqualObjects(attrs[@"adStreamType"], @"SSAI_IMA");
    XCTAssertEqualObjects(attrs[@"adTitle"], @"Ad A");
    XCTAssertEqualObjects(attrs[@"adCreativeId"], @"creative-1");
    XCTAssertEqualObjects(attrs[@"adDuration"], @15000);
}

- (void)testDaiSkippedSetsSkippedAndEnds {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_SKIPPED ad:ad] streamManager:nil];

    XCTAssertEqualObjects([[t actions] lastObject], @"AD_END");
    XCTAssertEqualObjects([t lastRecorded].attributes[@"adSkipped"], @1);
    XCTAssertEqualObjects([t getAdQuartile], [NSNull null]);
}

- (void)testSkippedFlagResetsOnNextAd {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_SKIPPED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t getAdSkipped], @0);
}

- (void)testDaiClickAndTapEmitAdClick {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_CLICKED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_TAPPED ad:ad] streamManager:nil];
    NSArray *tail = [[t actions] subarrayWithRange:NSMakeRange(2, 2)];
    XCTAssertEqualObjects(tail, (@[@"AD_CLICK", @"AD_CLICK"]));
}

- (void)testDaiTwoAdsInOneBreakEmitTwoStartsAndOneBreak {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_COMPLETE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_COMPLETE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_ENDED ad:nil] streamManager:nil];

    NSArray *a = [t actions];
    XCTAssertEqual([a filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'AD_START'"]].count, 2u);
    XCTAssertEqual([a filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'AD_BREAK_START'"]].count, 1u);
    XCTAssertEqual([a filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'AD_BREAK_END'"]].count, 1u);
}

#pragma mark Ad breaks

- (void)testDuplicateAdBreakStartedIsIgnored {
    RecordingIMATracker *t = [self daiTracker];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    XCTAssertEqualObjects([t actions], (@[@"AD_BREAK_START"]));
}

- (void)testManualAdBreakStartDoesNotDoubleCountWithAdBreakEvent {
    RecordingIMATracker *t = [self daiTracker];
    [t sendAdBreakStart];  // app also calls the lifecycle API by hand
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    XCTAssertEqualObjects([t actions], (@[@"AD_BREAK_START"]));
}

- (void)testAdBreakEndWithoutStartIsIgnored {
    RecordingIMATracker *t = [self daiTracker];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_ENDED ad:nil] streamManager:nil];
    XCTAssertEqual([t actions].count, 0u);
}

#pragma mark Pause and resume

- (RecordingIMATracker *)daiTrackerInAd {
    RecordingIMATracker *t = [self daiTracker];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"A" timeOffset:0 podIndex:0]] streamManager:nil];
    return t;
}

- (void)testDaiImaPauseResumeEventsEmitAdPauseResume {
    RecordingIMATracker *t = [self daiTrackerInAd];
    [t streamAdEvent:[self event:kIMAAdEvent_PAUSE ad:nil] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_RESUME ad:nil] streamManager:nil];
    XCTAssertEqualObjects([[t actions] subarrayWithRange:NSMakeRange(2, 2)], (@[@"AD_PAUSE", @"AD_RESUME"]));
}

- (void)testCsaiIgnoresImaPauseResume {
    RecordingIMATracker *t = [self csaiTracker];
    [t adEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"A" timeOffset:0 podIndex:0]] adsManager:nil];
    [t adEvent:[self event:kIMAAdEvent_PAUSE ad:nil] adsManager:nil];
    XCTAssertFalse([[t actions] containsObject:@"AD_PAUSE"]);
}

- (void)testDaiAdFollowsPlayerPauseAndResume {
    RecordingIMATracker *t = [self daiTrackerInAd];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusPaused];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusPlaying];
    XCTAssertEqualObjects([[t actions] subarrayWithRange:NSMakeRange(2, 2)], (@[@"AD_PAUSE", @"AD_RESUME"]));
}

- (void)testDaiPlayerPauseAfterImaPauseIsNotDuplicated {
    RecordingIMATracker *t = [self daiTrackerInAd];
    [t streamAdEvent:[self event:kIMAAdEvent_PAUSE ad:nil] streamManager:nil];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusPaused];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusPaused];
    XCTAssertEqual([[t actions] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF == 'AD_PAUSE'"]].count, 1u);
}

- (void)testDaiBufferingIsNotAPauseAndPauseOutsideAdIsIgnored {
    RecordingIMATracker *t = [self daiTrackerInAd];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate];
    XCTAssertFalse([[t actions] containsObject:@"AD_PAUSE"]);
    [t streamAdEvent:[self event:kIMAAdEvent_COMPLETE ad:nil] streamManager:nil];
    [t daiPlayerTimeControlStatusChanged:AVPlayerTimeControlStatusPaused];
    XCTAssertFalse([[t actions] containsObject:@"AD_PAUSE"]);
}

#pragma mark Errors

- (void)testDaiErrorKeepsDomainCodeMessageAndAddsStreamType {
    RecordingIMATracker *t = [self daiTracker];
    FakeError *err = [FakeError alloc];
    err.fakeType = kIMAAdLoadingFailed;
    err.fakeCode = kIMAError_VAST_LOAD_TIMEOUT;
    err.fakeMessage = @"stream request failed";

    [t handleStreamAdError:err];

    RecordedAction *r = [t lastRecorded];
    XCTAssertEqualObjects(r.action, @"AD_ERROR");
    XCTAssertEqualObjects(r.attributes[@"errorDomain"], @"com.newrelic.video.IMA");
    XCTAssertEqualObjects(r.attributes[@"errorCode"], @(kIMAError_VAST_LOAD_TIMEOUT));
    XCTAssertEqualObjects(r.attributes[@"errorMessage"], @"stream request failed");
    XCTAssertEqualObjects(r.attributes[@"adStreamType"], @"SSAI_IMA");
}

static NSString *const kRealStreamInitMessage =
    @"Stream initialization failed because either: \n1. Asset key was incorrect.\n2. The stream is inactive.\n"
    @"HTTP status code: 404 with URL: https://pubads.g.doubleclick.net/ssai/event/invalid-asset-key/streams?ctv=0&ms=Ldhzc"
    @"&js=ima-ios.3.33.0&correlator=2106536787911345&rdid=00000000-0000-0000-0000-000000000000"
    @"&idfv=67484060-5DF5-44BF-A381-8B9C8DC8EFEC&sid=EF8EEF18-580D-4729-BC0F-87B5AC4C3A82&url=com.x.adsenseformobileapps.com%2F";

- (void)testDaiErrorMessageDropsRequestUrlQuery {
    RecordingIMATracker *t = [self daiTracker];
    FakeError *err = [FakeError alloc];
    err.fakeType = kIMAAdLoadingFailed;
    err.fakeCode = kIMAError_STREAM_INITIALIZATION_FAILED;
    err.fakeMessage = kRealStreamInitMessage;
    [t handleStreamAdError:err];
    NSString *msg = [t lastRecorded].attributes[@"errorMessage"];
    XCTAssertTrue([msg containsString:@"https://pubads.g.doubleclick.net/ssai/event/invalid-asset-key/streams?<redacted>"]);
    XCTAssertTrue([msg hasPrefix:@"Stream initialization failed because either:"]);
    XCTAssertTrue([msg containsString:@"HTTP status code: 404"]);
    XCTAssertFalse([msg containsString:@"rdid"]);
    XCTAssertFalse([msg containsString:@"idfv"]);
    XCTAssertFalse([msg containsString:@"correlator"]);
}

- (void)testSanitizerKeepsTextWithoutQueryAndHandlesMultipleUrls {
    XCTAssertEqualObjects([NRTrackerIMA sanitizedErrorMessage:@"no url here"], @"no url here");
    XCTAssertEqualObjects([NRTrackerIMA sanitizedErrorMessage:@"see https://a.com/x/y plain"], @"see https://a.com/x/y plain");
    XCTAssertEqualObjects([NRTrackerIMA sanitizedErrorMessage:@"a https://a.com/p?id=1 b http://b.org/q?z=2#f c"],
                          @"a https://a.com/p?<redacted> b http://b.org/q?<redacted> c");
    XCTAssertNil([NRTrackerIMA sanitizedErrorMessage:nil]);
}

- (void)testCsaiErrorMessageIsNotSanitized {
    RecordingIMATracker *t = [self csaiTracker];
    [t adError:@"failed https://a.com/p?id=1" code:1];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"errorMessage"], @"failed https://a.com/p?id=1");
}

- (void)testDaiErrorCarriesErrorNameFromImaType {
    RecordingIMATracker *t = [self daiTracker];
    FakeError *err = [FakeError alloc];
    err.fakeType = kIMAAdLoadingFailed;
    err.fakeCode = kIMAError_STREAM_INITIALIZATION_FAILED;
    err.fakeMessage = @"m";
    [t handleStreamAdError:err];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"errorName"], @"IMA_AD_LOADING_FAILED");
    err.fakeType = kIMAAdPlayingFailed;
    [t handleStreamAdError:err];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"errorName"], @"IMA_AD_PLAYING_FAILED");
}

- (void)testDaiErrorWithNilMessageDoesNotCrash {
    RecordingIMATracker *t = [self daiTracker];
    FakeError *err = [FakeError alloc];
    err.fakeCode = kIMAError_VIDEO_PLAY_ERROR;
    [t handleStreamAdError:err];
    XCTAssertEqualObjects([t lastRecorded].action, @"AD_ERROR");
}

#pragma mark Retention and getters

- (void)testLastEventIsRetainedAfterCallerReleasesIt {
    RecordingIMATracker *t = [self daiTracker];
    __weak FakeEvent *weakEvent = nil;
    @autoreleasepool {
        FakeEvent *e = [self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"Ad A" timeOffset:0 podIndex:0]];
        weakEvent = e;
        [t streamAdEvent:e streamManager:nil];
    }
    XCTAssertNotNil(weakEvent, @"tracker must hold the event for the getters");
    XCTAssertEqualObjects([t getTitle], @"Ad A");
    XCTAssertEqualObjects([t getDuration], @15000);
}

- (void)testBreakEventWithoutAdKeepsPreviousAdMetadata {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_COMPLETE ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_ENDED ad:nil] streamManager:nil];
    XCTAssertEqualObjects([t lastRecorded].attributes[@"adTitle"], @"Ad A");
}

- (void)testDaiNewBreakDoesNotReportPreviousBreakMetadata {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    [t streamAdEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] streamManager:nil];
    XCTAssertEqualObjects([t getAdPosition], [NSNull null]);
    XCTAssertEqualObjects([t getTitle], [NSNull null]);
}

- (void)testDaiAdIdComesFromImaAdAndDiffersPerAd {
    RecordingIMATracker *t = [self daiTracker];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"A" timeOffset:0 podIndex:0]] streamManager:nil];
    XCTAssertEqualObjects([t getVideoId], @"ad-A");
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"B" timeOffset:0 podIndex:0]] streamManager:nil];
    XCTAssertEqualObjects([t getVideoId], @"ad-B");
}

- (void)testDaiZeroBitrateIsNullButCsaiKeepsValue {
    RecordingIMATracker *t = [self daiTracker];
    FakeAd *ad = [self adWithTitle:@"A" timeOffset:0 podIndex:0];
    ad.fakeBitrate = 0;
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:ad] streamManager:nil];
    XCTAssertEqualObjects([t getBitrate], [NSNull null]);
    XCTAssertEqualObjects([t getRenditionWidth], @640);
}

- (void)testDaiAdPositionUsesPodTimeOffset {
    RecordingIMATracker *t = [self daiTracker];
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:0 podIndex:0]] streamManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"pre");
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:120 podIndex:7]] streamManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"mid");
    [t streamAdEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:-1 podIndex:9]] streamManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"post");
}

- (void)testDaiPlayheadComesFromAdProgress {
    RecordingIMATracker *t = [self daiTracker];
    XCTAssertEqualObjects([t getPlayhead], [NSNull null]);
    [t handleStreamAdProgressToTime:4.5 adDuration:15 adPosition:1 totalAds:2 adBreakDuration:30];
    XCTAssertEqualObjects([t getPlayhead], @4500);
}

#pragma mark CSAI unchanged

- (void)testCsaiLifecycleAndNoStreamTypeAttribute {
    RecordingIMATracker *t = [self csaiTracker];
    FakeAd *ad = [self adWithTitle:@"Ad A" timeOffset:0 podIndex:0];
    [t adEvent:[self event:kIMAAdEvent_STARTED ad:ad] adsManager:nil];
    [t adEvent:[self event:kIMAAdEvent_FIRST_QUARTILE ad:ad] adsManager:nil];
    [t adEvent:[self event:kIMAAdEvent_COMPLETE ad:ad] adsManager:nil];

    XCTAssertEqualObjects([t actions], (@[@"AD_REQUEST", @"AD_START", @"AD_QUARTILE", @"AD_END"]));
    XCTAssertNil([t lastRecorded].attributes[@"adStreamType"]);
}

- (void)testCsaiIgnoresAdBreakEvents {
    RecordingIMATracker *t = [self csaiTracker];
    [t adEvent:[self event:kIMAAdEvent_AD_BREAK_STARTED ad:nil] adsManager:nil];
    [t adEvent:[self event:kIMAAdEvent_AD_BREAK_ENDED ad:nil] adsManager:nil];
    XCTAssertEqual([t actions].count, 0u);
}

- (void)testCsaiAdPositionStillUsesPodIndex {
    RecordingIMATracker *t = [self csaiTracker];
    [t adEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:0 podIndex:0]] adsManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"pre");
    [t adEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:0 podIndex:2]] adsManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"mid");
    [t adEvent:[self event:kIMAAdEvent_STARTED ad:[self adWithTitle:@"a" timeOffset:0 podIndex:-1]] adsManager:nil];
    XCTAssertEqualObjects([t getAdPosition], @"post");
}

- (void)testCsaiErrorUnchanged {
    RecordingIMATracker *t = [self csaiTracker];
    FakeError *err = [FakeError alloc];
    err.fakeCode = kIMAError_VAST_LOAD_TIMEOUT;
    err.fakeMessage = @"boom";
    [t handleAdError:err];
    RecordedAction *r = [t lastRecorded];
    XCTAssertEqualObjects(r.attributes[@"errorDomain"], @"com.newrelic.video.IMA");
    XCTAssertEqualObjects(r.attributes[@"errorMessage"], @"boom");
    XCTAssertNil(r.attributes[@"adStreamType"]);
}

#pragma mark Core config

- (void)testAdConfigDaiHasDaiType {
    XCTAssertEqual([NRAdConfig ssaiIma].type, NRAdTrackerTypeSSAIIMA);
    XCTAssertEqual([NRAdConfig csai].type, NRAdTrackerTypeCSAI);
    XCTAssertEqual([NRAdConfig mediaTailor].type, NRAdTrackerTypeMediaTailor);
}

- (void)testCreateAdTrackerForDaiConfigReturnsIMATracker {
    id tracker = [NRVAVideo createAdTrackerForConfig:[NRAdConfig ssaiIma]];
    XCTAssertNotNil(tracker);
    XCTAssertTrue([tracker isKindOfClass:[NRTrackerIMA class]]);
}

- (void)testStreamHandlersAreNoOpWhenTrackerMissing {
    // No tracker is registered under this id: must not crash.
    FakeEvent *e = [self event:kIMAAdEvent_STARTED ad:nil];
    [NRVAVideo handleStreamAdEvent:@(987654) event:e streamManager:nil];
    [NRVAVideo handleStreamAdError:@(987654) error:[FakeError alloc]];
    [NRVAVideo handleStreamAdProgress:@(987654) time:1 adDuration:2 adPosition:1 totalAds:1 adBreakDuration:2];
}

@end
