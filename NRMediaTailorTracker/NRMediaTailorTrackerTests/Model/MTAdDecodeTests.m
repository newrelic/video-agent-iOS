//
//  MTAdDecodeTests.m
//  NRMediaTailorTrackerTests
//
//  Per-field tests for MTAd, MTTrackingEvent and the runtime models
//  MTAdBreak / MTAdPod. Validates Bug B2 (`creativeId` primary identity) and
//  Bug B5 (`trackingEvents[*].startTimeInSeconds` is relative to ad start).
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTAd.h>
#import <NRMediaTailorTracker/MTAvail.h>
#import <NRMediaTailorTracker/MTTrackingEvent.h>
#import <NRMediaTailorTracker/MTTrackingResponse.h>
#import <NRMediaTailorTracker/MTAdBreak.h>
#import <NRMediaTailorTracker/MTAdPod.h>
#import <NRMediaTailorTracker/MTAdErrorCode.h>

@interface MTAdDecodeTests : XCTestCase
@end

@implementation MTAdDecodeTests

- (NSDictionary *)loadFixture:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"json"];
    XCTAssertNotNil(path, @"missing fixture: %@.json", name);
    NSError *err = nil;
    NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:&err];
    XCTAssertNil(err);
    return obj;
}

#pragma mark - Bug B2: creativeId primary identity

- (void)testPrimaryKey_creativeIdWhenPresent {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    MTAd *ad = resp.avails.firstObject.ads.firstObject;
    XCTAssertEqualObjects(ad.creativeId, @"creative-A");
    XCTAssertEqualObjects([ad primaryKey], @"creative-A",
                          @"primaryKey must prefer creativeId (Bug B2)");
}

- (void)testPrimaryKey_compositeFallbackWhenCreativeIdMissing {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_missing_creativeId"]];
    MTAd *ad = resp.avails.firstObject.ads.firstObject;
    XCTAssertNil(ad.creativeId);
    XCTAssertEqualObjects([ad primaryKey], @"avail-200:ad-99",
                          @"primaryKey must fall back to availId:adId (Bug B2)");
}

- (void)testPrimaryKey_compositeIsStableAcrossAds {
    // Two ads in the same avail with no creativeId should produce distinct keys.
    NSDictionary *raw = @{
        @"availId": @"a1",
        @"startTimeInSeconds": @0.0,
        @"durationInSeconds": @10.0,
        @"ads": @[
            @{@"adId": @"x", @"startTimeInSeconds": @0.0, @"durationInSeconds": @5.0},
            @{@"adId": @"y", @"startTimeInSeconds": @5.0, @"durationInSeconds": @5.0},
        ],
    };
    MTAvail *avail = [MTAvail fromDictionary:raw];
    XCTAssertEqualObjects([avail.ads[0] primaryKey], @"a1:x");
    XCTAssertEqualObjects([avail.ads[1] primaryKey], @"a1:y");
}

#pragma mark - Bug B5: tracking event time is relative to ad start

- (void)testTrackingEvent_startTimeIsRelativeToAdStart_notManifest {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    MTAd *ad = resp.avails.firstObject.ads.firstObject;
    // Ad starts at manifest second 30 (=> 30000 ms absolute). Tracking events
    // come in as raw seconds-from-ad-start. firstQuartile is JSON 5.0 — that
    // is FIVE SECONDS INTO THE AD, not 5s into the manifest.
    XCTAssertEqualWithAccuracy(ad.startTimeMs, 30000.0, 0.001);

    MTTrackingEvent *firstQuartile = ad.trackingEvents[1];
    XCTAssertEqualObjects(firstQuartile.eventType, @"firstQuartile");
    XCTAssertEqualWithAccuracy(firstQuartile.relativeToAdStartMs, 5000.0, 0.001,
                               @"firstQuartile is 5s into the ad (Bug B5)");

    MTTrackingEvent *complete = ad.trackingEvents[3];
    XCTAssertEqualObjects(complete.eventType, @"complete");
    XCTAssertEqualWithAccuracy(complete.relativeToAdStartMs, 20000.0, 0.001);
}

- (void)testTrackingEvent_beaconUrlsArePreservedAsURLs {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    MTAd *ad = resp.avails.firstObject.ads.firstObject;
    MTTrackingEvent *impression = ad.trackingEvents.firstObject;
    XCTAssertEqual(impression.beaconUrls.count, 2u);
    XCTAssertEqualObjects(impression.beaconUrls.firstObject, [NSURL URLWithString:@"https://example.com/track/imp1"]);
}

#pragma mark - Bug A8 surface: missing avail start time

- (void)testAvail_hasStartTimeFalseWhenJSONMissing {
    NSDictionary *raw = @{
        @"availId": @"avail-x",
        @"durationInSeconds": @10.0,
        @"ads": @[],
    };
    MTAvail *avail = [MTAvail fromDictionary:raw];
    XCTAssertFalse(avail.hasStartTime, @"missing startTimeInSeconds must be detectable (Bug A8)");
    XCTAssertEqual(avail.startTimeMs, 0.0);
}

- (void)testAvail_hasStartTimeTrueWhenJSONPresent {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    XCTAssertTrue(resp.avails.firstObject.hasStartTime);
}

#pragma mark - Bumper heuristic

- (void)testIsBumper_matchesAdSystemCaseInsensitive {
    MTAd *ad = [MTAd fromDictionary:@{
        @"adId": @"x",
        @"adSystem": @"MyBuMpEr",
        @"startTimeInSeconds": @0.0,
        @"durationInSeconds": @5.0,
    } availId:@"a"];
    XCTAssertTrue(ad.isBumper);
}

- (void)testIsBumper_matchesAdTitle {
    MTAd *ad = [MTAd fromDictionary:@{
        @"adId": @"x",
        @"adTitle": @"Pre-roll Bumper #2",
        @"startTimeInSeconds": @0.0,
        @"durationInSeconds": @5.0,
    } availId:@"a"];
    XCTAssertTrue(ad.isBumper);
}

- (void)testIsBumper_matchesAdId {
    MTAd *ad = [MTAd fromDictionary:@{
        @"adId": @"bumper-001",
        @"startTimeInSeconds": @0.0,
        @"durationInSeconds": @5.0,
    } availId:@"a"];
    XCTAssertTrue(ad.isBumper);
}

- (void)testIsBumper_falseForRegularAd {
    MTAd *ad = [MTAd fromDictionary:@{
        @"adId": @"ad-001",
        @"adTitle": @"Brand Spot",
        @"adSystem": @"BrandX",
        @"startTimeInSeconds": @0.0,
        @"durationInSeconds": @5.0,
    } availId:@"a"];
    XCTAssertFalse(ad.isBumper);
}

#pragma mark - MTAdBreak / MTAdPod containment

- (void)testAdBreak_containsPositionMs_halfOpenInterval {
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"a" startTimeMs:1000 durationMs:500];
    XCTAssertTrue([brk containsPositionMs:1000]);
    XCTAssertTrue([brk containsPositionMs:1499.9]);
    XCTAssertFalse([brk containsPositionMs:1500], @"endTimeMs is exclusive");
    XCTAssertFalse([brk containsPositionMs:999.9]);
}

- (void)testAdBreak_activePodForPositionMs_returnsNilWhenEmpty {
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"a" startTimeMs:0 durationMs:1000];
    XCTAssertNil([brk activePodForPositionMs:500]);
}

- (void)testAdBreak_activePodForPositionMs_returnsMatchingPod {
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"a" startTimeMs:0 durationMs:1000];
    MTAdPod *p1 = [[MTAdPod alloc] initWithStartTimeMs:0 durationMs:500];
    MTAdPod *p2 = [[MTAdPod alloc] initWithStartTimeMs:500 durationMs:500];
    [brk.pods addObjectsFromArray:@[p1, p2]];
    XCTAssertEqualObjects([brk activePodForPositionMs:100], p1);
    XCTAssertEqualObjects([brk activePodForPositionMs:600], p2);
    XCTAssertNil([brk activePodForPositionMs:1001]);
}

- (void)testAdPod_endTimeMsDerived {
    MTAdPod *p = [[MTAdPod alloc] initWithStartTimeMs:1000 durationMs:300];
    XCTAssertEqualWithAccuracy(p.endTimeMs, 1300.0, 0.001);
}

- (void)testAdBreak_firingFlagsDefaultFalse {
    MTAdBreak *brk = [[MTAdBreak alloc] initWithAvailId:@"a" startTimeMs:0 durationMs:100];
    XCTAssertFalse(brk.hasFiredStart);
    XCTAssertFalse(brk.hasFiredEnd);
    XCTAssertFalse(brk.hasFiredAdStart);
    XCTAssertFalse(brk.hasFiredQ1);
    XCTAssertFalse(brk.hasFiredQ2);
    XCTAssertFalse(brk.hasFiredQ3);
    XCTAssertFalse(brk.isNoFill);
    XCTAssertFalse(brk.podCountMismatch);
}

#pragma mark - MTAdErrorCode wire-format

- (void)testErrorCode_wireFormatNames {
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeNoFill), @"NO_FILL");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeTokenExpired), @"TOKEN_EXPIRED");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeAdsTimeout), @"ADS_TIMEOUT");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeTrackingFetchFailed), @"TRACKING_FETCH_FAILED");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeMissingAvailStart), @"MISSING_AVAIL_START");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeManifestParseFailed), @"MANIFEST_PARSE_FAILED");
    XCTAssertEqualObjects(NSStringFromMTAdErrorCode(MTAdErrorCodeManifestTrackingMismatch), @"MANIFEST_TRACKING_MISMATCH");
}

@end
