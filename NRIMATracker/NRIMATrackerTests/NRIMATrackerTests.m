//
//  NRIMATrackerTests.m
//  NRIMATrackerTests
//
//  Created by Andreu Santaren on 2/3/21.
//

#import <XCTest/XCTest.h>
#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import "NRTrackerIMA.h"

#pragma mark - Test doubles

/// IMA's event/ad/pod classes cannot be instantiated (init is unavailable), and
/// `NRTrackerIMA` only reads a handful of properties, so plain objects stand in.
@interface FakePodInfo : NSObject
@property (nonatomic) NSInteger adPosition;
@property (nonatomic) NSInteger totalAds;
@property (nonatomic) NSInteger podIndex;
@end
@implementation FakePodInfo
@end

@interface FakeAd : NSObject
@property (nonatomic, strong) FakePodInfo *adPodInfo;
@property (nonatomic, copy) NSString *adTitle;
@property (nonatomic, copy) NSString *creativeID;
@property (nonatomic, copy) NSString *adId;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSInteger VASTMediaBitrate;
@property (nonatomic) NSInteger VASTMediaWidth;
@property (nonatomic) NSInteger VASTMediaHeight;
@end
@implementation FakeAd
@end

@interface FakeEvent : NSObject
@property (nonatomic) IMAAdEventType type;
@property (nonatomic, copy) NSString *typeString;
@property (nonatomic, strong) FakeAd *ad;
@end
@implementation FakeEvent
@end

/// Records the senders the tracker calls instead of sending real events.
@interface RecordingTracker : NRTrackerIMA
@property (nonatomic, strong) NSMutableArray<NSString *> *calls;
@end

@implementation RecordingTracker
- (NSMutableArray<NSString *> *)calls {
    if (!_calls) { _calls = [NSMutableArray array]; }
    return _calls;
}
// Request, start and end drive the real state, as the core does, so the quartile gate sees it.
- (void)sendRequest { [self.state goRequest]; [self.calls addObject:@"request"]; }
- (void)sendStart { [self.state goStart]; [self.calls addObject:@"start"]; }
- (void)sendEnd { [self.state goEnd]; [self.calls addObject:@"end"]; }
- (void)sendPause { [self.calls addObject:@"pause"]; }
- (void)sendResume { [self.calls addObject:@"resume"]; }
- (void)sendAdBreakStart { [self.calls addObject:@"breakStart"]; }
- (void)sendAdBreakEnd { [self.calls addObject:@"breakEnd"]; }
- (void)sendAdQuartile { [self.calls addObject:@"quartile"]; }
- (void)sendAdClick { [self.calls addObject:@"click"]; }
@end

/// Stands in for the content player tracker, whose source is the stitched stream URL.
@interface FakeContentTracker : NRVideoTracker
@property (nonatomic, copy) NSString *fakeSrc;
@end
@implementation FakeContentTracker
- (NSString *)getSrc { return self.fakeSrc ?: (NSString *)[NSNull null]; }
@end

#pragma mark - Tests

@interface NRIMATrackerTests : XCTestCase
@property (nonatomic, strong) RecordingTracker *tracker;
@end

@implementation NRIMATrackerTests

- (void)setUp {
    self.tracker = [[RecordingTracker alloc] init];
}

- (IMAAdEvent *)eventOfType:(IMAAdEventType)type adPosition:(NSInteger)position totalAds:(NSInteger)total {
    FakePodInfo *pod = [[FakePodInfo alloc] init];
    pod.adPosition = position;
    pod.totalAds = total;
    FakeAd *ad = [[FakeAd alloc] init];
    ad.adPodInfo = pod;
    FakeEvent *event = [[FakeEvent alloc] init];
    event.type = type;
    event.typeString = @"test";
    event.ad = ad;
    return (IMAAdEvent *)event;
}

- (IMAAdEvent *)eventOfType:(IMAAdEventType)type {
    return [self eventOfType:type adPosition:1 totalAds:1];
}

/// DAI ad period/break events carry no ad.
- (IMAAdEvent *)eventWithoutAdOfType:(IMAAdEventType)type {
    FakeEvent *event = [[FakeEvent alloc] init];
    event.type = type;
    event.typeString = @"test";
    return (IMAAdEvent *)event;
}

- (void)send:(IMAAdEventType)type {
    [self.tracker adEvent:[self eventOfType:type] adsManager:nil];
}

#pragma mark Client-side ads

- (void)testCSAIStartOpensBreakThenRequestsAndStarts {
    [self send:kIMAAdEvent_STARTED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart", @"request", @"start"]));
}

- (void)testCSAICompleteOfLastAdInPodClosesBreak {
    [self.tracker adEvent:[self eventOfType:kIMAAdEvent_COMPLETE adPosition:2 totalAds:2] adsManager:nil];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"end", @"breakEnd"]));
}

- (void)testCSAICompleteOfNonLastAdKeepsBreakOpen {
    [self.tracker adEvent:[self eventOfType:kIMAAdEvent_COMPLETE adPosition:1 totalAds:2] adsManager:nil];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"end"]));
}

- (void)testCSAISkippedOfLastAdClosesBreak {
    [self send:kIMAAdEvent_SKIPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"end", @"breakEnd"]));
    XCTAssertEqualObjects([self.tracker getAdSkipped], @(1));
}

- (void)testSkippedFlagIsResetByNextAd {
    [self send:kIMAAdEvent_SKIPPED];
    [self send:kIMAAdEvent_STARTED];
    XCTAssertEqualObjects([self.tracker getAdSkipped], @(0));
}

- (void)testPauseAndResumeAreForwarded {
    [self send:kIMAAdEvent_PAUSE];
    [self send:kIMAAdEvent_RESUME];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"pause", @"resume"]));
}

- (void)testQuartilesAreReported {
    [self send:kIMAAdEvent_STARTED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_FIRST_QUARTILE];
    XCTAssertEqualObjects([self.tracker getAdQuartile], @(1));
    [self send:kIMAAdEvent_MIDPOINT];
    XCTAssertEqualObjects([self.tracker getAdQuartile], @(2));
    [self send:kIMAAdEvent_THIRD_QUARTILE];
    XCTAssertEqualObjects([self.tracker getAdQuartile], @(3));
    XCTAssertEqual(self.tracker.calls.count, 3u);
}

- (void)sendAllQuartiles {
    [self send:kIMAAdEvent_FIRST_QUARTILE];
    [self send:kIMAAdEvent_MIDPOINT];
    [self send:kIMAAdEvent_THIRD_QUARTILE];
}

- (void)testCSAIQuartilesWithoutStartedAreDropped {
    [self sendAllQuartiles];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
    XCTAssertEqualObjects([self.tracker getAdQuartile], [NSNull null]);
}

- (void)testQuartileAfterCompleteIsDropped {
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_COMPLETE];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_FIRST_QUARTILE];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testNewStartedRearmsQuartiles {
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_COMPLETE];
    [self send:kIMAAdEvent_STARTED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_MIDPOINT];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"quartile"]));
}

- (void)testClickAndTapAreForwarded {
    [self send:kIMAAdEvent_STARTED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_CLICKED];
    [self send:kIMAAdEvent_TAPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"click", @"click"]));
}

- (void)testCSAIClickAndTapWithoutStartedAreDropped {
    [self send:kIMAAdEvent_CLICKED];
    [self send:kIMAAdEvent_TAPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testClickAfterCompleteIsDropped {
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_COMPLETE];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_CLICKED];
    [self send:kIMAAdEvent_TAPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testNewStartedRearmsClicks {
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_COMPLETE];
    [self send:kIMAAdEvent_STARTED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_CLICKED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"click"]));
}

- (void)testNonLifecycleEventsAreIgnored {
    [self send:kIMAAdEvent_LOADED];
    [self send:kIMAAdEvent_LOG];
    [self send:kIMAAdEvent_CUEPOINTS_CHANGED];
    XCTAssertEqual(self.tracker.calls.count, 0u);
}

#pragma mark Dynamic Ad Insertion

- (void)configureDAI {
    [self.tracker configureWithAdConfig:[NRAdConfig imaDai] player:nil];
}

- (void)testDAIStartDoesNotOpenBreakFromPodInfo {
    [self configureDAI];
    [self send:kIMAAdEvent_STARTED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"request", @"start"]));
}

- (void)testDAICompleteDoesNotCloseBreak {
    [self configureDAI];
    [self send:kIMAAdEvent_COMPLETE];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"end"]));
}

- (void)testDAIAdPeriodEventsDriveTheBreak {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_PERIOD_STARTED];
    [self send:kIMAAdEvent_AD_PERIOD_ENDED];
    // The stub records "end" even with no open ad; the real sendEnd is a no-op then.
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart", @"end", @"breakEnd"]));
}

- (void)testDAIAdBreakEventsDriveTheBreak {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_BREAK_STARTED];
    [self send:kIMAAdEvent_AD_BREAK_ENDED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart", @"end", @"breakEnd"]));
}

- (void)testDAIBreakEndClosesAnAdThatNeverCompleted {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_BREAK_STARTED];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_AD_BREAK_ENDED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart", @"request", @"start", @"end", @"breakEnd"]));
}

- (void)testDAIPeriodEndClosesAnAdThatNeverCompleted {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_PERIOD_STARTED];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_AD_PERIOD_ENDED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart", @"request", @"start", @"end", @"breakEnd"]));
}

- (void)testDAIQuartilesWithoutStartedAreDropped {
    [self configureDAI];
    [self sendAllQuartiles];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testDAIQuartilesAfterStartedAreSent {
    [self configureDAI];
    [self send:kIMAAdEvent_STARTED];
    [self sendAllQuartiles];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"request", @"start", @"quartile", @"quartile", @"quartile"]));
}

- (void)testDAIQuartileAfterBreakEndWithOpenAdIsDropped {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_BREAK_STARTED];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_AD_BREAK_ENDED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_THIRD_QUARTILE];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testDAIQuartileAfterPeriodEndWithOpenAdIsDropped {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_PERIOD_STARTED];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_AD_PERIOD_ENDED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_FIRST_QUARTILE];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testDAIClickAndTapWithoutStartedAreDropped {
    [self configureDAI];
    [self send:kIMAAdEvent_CLICKED];
    [self send:kIMAAdEvent_TAPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testDAIClickAndTapAfterStartedAreSent {
    [self configureDAI];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_CLICKED];
    [self send:kIMAAdEvent_TAPPED];
    XCTAssertEqualObjects(self.tracker.calls, (@[@"request", @"start", @"click", @"click"]));
}

- (void)testDAIClickAfterBreakEndWithOpenAdIsDropped {
    [self configureDAI];
    [self send:kIMAAdEvent_AD_BREAK_STARTED];
    [self send:kIMAAdEvent_STARTED];
    [self send:kIMAAdEvent_AD_BREAK_ENDED];
    [self.tracker.calls removeAllObjects];
    [self send:kIMAAdEvent_CLICKED];
    XCTAssertEqualObjects(self.tracker.calls, (@[]));
}

- (void)testEventsWithoutAnAdYieldNullAttributesInsteadOfNil {
    [self configureDAI];
    [self.tracker adEvent:[self eventWithoutAdOfType:kIMAAdEvent_AD_PERIOD_STARTED] adsManager:nil];
    XCTAssertEqualObjects([self.tracker getTitle], [NSNull null]);
    XCTAssertEqualObjects([self.tracker getAdCreativeId], [NSNull null]);
    XCTAssertEqualObjects([self.tracker getAdPosition], [NSNull null]);
    XCTAssertEqualObjects([self.tracker getDuration], [NSNull null]);
    XCTAssertEqualObjects(self.tracker.calls, (@[@"breakStart"]));
}

- (void)testAdWithoutTitleOrCreativeIdYieldsNull {
    [self send:kIMAAdEvent_STARTED];
    XCTAssertEqualObjects([self.tracker getTitle], [NSNull null]);
    XCTAssertEqualObjects([self.tracker getAdCreativeId], [NSNull null]);
}

- (void)testBreakEventWithoutAdKeepsTheLastAd {
    [self configureDAI];
    FakeEvent *started = (FakeEvent *)[self eventOfType:kIMAAdEvent_STARTED];
    started.ad.adTitle = @"Ad One";
    [self.tracker adEvent:(IMAAdEvent *)started adsManager:nil];
    [self.tracker adEvent:[self eventWithoutAdOfType:kIMAAdEvent_AD_PERIOD_ENDED] adsManager:nil];
    XCTAssertEqualObjects([self.tracker getTitle], @"Ad One");
}

- (void)testAdErrorWithNilMessageDoesNotCrash {
    XCTAssertNoThrow([self.tracker adError:nil code:7]);
}

- (void)testPlayheadIsNullWithoutAdsManager {
    [self configureDAI];
    [self send:kIMAAdEvent_STARTED];
    XCTAssertEqualObjects([self.tracker getPlayhead], [NSNull null]);
}

#pragma mark - Ad id

- (NSDictionary *)adStartAttributes {
    [self.tracker.state setIsAd:YES];
    return [self.tracker getAttributes:@"AD_START" attributes:nil];
}

- (void)startAdWithId:(NSString *)adId bitrate:(NSInteger)bitrate {
    FakeEvent *e = (FakeEvent *)[self eventOfType:kIMAAdEvent_STARTED];
    e.ad.adId = adId;
    e.ad.VASTMediaBitrate = bitrate;
    [self.tracker adEvent:(IMAAdEvent *)e adsManager:nil];
}

- (void)testAdIdIsTheIMAAdId {
    [self startAdWithId:@"ima-ad-1" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adId"], @"ima-ad-1");
}

- (void)testDifferentAdsHaveDifferentIds {
    [self startAdWithId:@"ima-ad-1" bitrate:0];
    NSString *first = [self adStartAttributes][@"adId"];
    [self startAdWithId:@"ima-ad-2" bitrate:0];
    XCTAssertNotEqualObjects(first, [self adStartAttributes][@"adId"]);
}

- (void)testAdIdIsNullWhenThereIsNoAd {
    XCTAssertEqualObjects([self.tracker getVideoId], [NSNull null]);
    [self.tracker.state setIsAd:YES];
    XCTAssertEqualObjects([self.tracker getAttributes:@"AD_BREAK_START" attributes:nil][@"adId"], [NSNull null]);
}

- (void)testAdIdIsNullWhenAdIdIsNilOrEmpty {
    [self startAdWithId:nil bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adId"], [NSNull null]);
    [self startAdWithId:@"" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adId"], [NSNull null]);
}

- (void)testAdIdIsTheLastAdAtBreakEnd {
    [self startAdWithId:@"ima-ad-1" bitrate:0];
    [self.tracker.state setIsAd:YES];
    XCTAssertEqualObjects([self.tracker getAttributes:@"AD_BREAK_END" attributes:nil][@"adId"], @"ima-ad-1");
}

#pragma mark - Ad source and partner

static NSString *const kStitchedURL = @"https://dai.example.com/stream/master.m3u8";

- (FakeContentTracker *)linkContentTrackerWithSrc:(NSString *)src {
    FakeContentTracker *content = [[FakeContentTracker alloc] init];
    content.fakeSrc = src;
    [self.tracker setLinkedTracker:content];
    return content;
}

- (void)testDAIAdSrcIsTheContentStreamURL {
    FakeContentTracker *content = [self linkContentTrackerWithSrc:kStitchedURL];
    [self configureDAI];
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adSrc"], kStitchedURL);
    (void)content;
}

- (void)testDAIAdSrcIsAbsentWhenContentHasNoSrc {
    [self linkContentTrackerWithSrc:nil];
    [self configureDAI];
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adSrc"], [NSNull null]);
}

- (void)testDAIAdSrcIsAbsentWithoutContentTracker {
    [self configureDAI];
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adSrc"], [NSNull null]);
}

- (void)testCSAIAdSrcIsUnchanged {
    [self linkContentTrackerWithSrc:kStitchedURL];
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adSrc"], [NSNull null]);
}

- (void)testDAIAdPartnerIsGoogleDai {
    [self configureDAI];
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adPartner"], @"google-dai");
}

- (void)testCSAIAdPartnerIsUnchanged {
    [self startAdWithId:@"a" bitrate:0];
    XCTAssertEqualObjects([self adStartAttributes][@"adPartner"], [NSNull null]);
}

- (void)testAdBitrateKeptWhenPositive {
    [self startAdWithId:@"a" bitrate:500];
    XCTAssertEqualObjects([self adStartAttributes][@"adBitrate"], @500000);
}

@end
