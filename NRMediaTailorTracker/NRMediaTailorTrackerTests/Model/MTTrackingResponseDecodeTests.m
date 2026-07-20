//
//  MTTrackingResponseDecodeTests.m
//  NRMediaTailorTrackerTests
//
//  JSON-roundtrip decode tests for the top-level MTTrackingResponse model.
//  Validates Bug B1 (nextToken round-trip) and Bug A8 (avails with missing
//  start time keep `hasStartTime = NO`).
//

#import <XCTest/XCTest.h>
#import <NRMediaTailorTracker/MTTrackingResponse.h>
#import <NRMediaTailorTracker/MTAvail.h>
#import <NRMediaTailorTracker/MTAd.h>
#import <NRMediaTailorTracker/MTTrackingEvent.h>

@interface MTTrackingResponseDecodeTests : XCTestCase
@end

@implementation MTTrackingResponseDecodeTests

#pragma mark - Fixture helper

- (NSDictionary *)loadFixture:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"json"];
    XCTAssertNotNil(path, @"missing fixture: %@.json", name);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data);
    NSError *err = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
    XCTAssertNil(err, @"fixture parse error: %@", err);
    return obj;
}

- (NSData *)loadFixtureData:(NSString *)name {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *path = [bundle pathForResource:name ofType:@"json"];
    XCTAssertNotNil(path);
    return [NSData dataWithContentsOfFile:path];
}

#pragma mark - tracking_full

- (void)testDecode_full_topLevel {
    NSDictionary *dict = [self loadFixture:@"tracking_full"];
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:dict];
    XCTAssertNotNil(resp);
    XCTAssertEqual(resp.avails.count, 1u);
    XCTAssertEqual(resp.nonLinearAvails.count, 0u);
    XCTAssertNil(resp.nextToken, @"full fixture has no nextToken");
}

- (void)testDecode_full_availFields {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    MTAvail *avail = resp.avails.firstObject;
    XCTAssertEqualObjects(avail.availId, @"avail-100");
    XCTAssertEqualWithAccuracy(avail.startTimeMs, 30000.0, 0.001);
    XCTAssertEqualWithAccuracy(avail.durationMs, 45000.0, 0.001);
    XCTAssertEqualObjects(avail.availProgramDateTime, @"2026-06-22T12:30:00.000Z");
    XCTAssertTrue(avail.hasStartTime);
    XCTAssertEqual(avail.ads.count, 2u);
    XCTAssertFalse(avail.isNoFill);
}

- (void)testDecode_full_adFields {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    MTAvail *avail = resp.avails.firstObject;
    MTAd *ad = avail.ads.firstObject;
    XCTAssertEqualObjects(ad.adId, @"ad-1");
    XCTAssertEqualObjects(ad.creativeId, @"creative-A");
    XCTAssertEqualObjects(ad.adTitle, @"Sample Ad One");
    XCTAssertEqualObjects(ad.adSystem, @"BrandX");
    XCTAssertEqualObjects(ad.creativeSequence, @"1");
    XCTAssertEqualObjects(ad.vastAdId, @"vast-001");
    XCTAssertEqualObjects(ad.skipOffset, @"00:00:05");
    XCTAssertEqualObjects(ad.adProgramDateTime, @"2026-06-22T12:30:00.000Z");
    XCTAssertEqualWithAccuracy(ad.startTimeMs, 30000.0, 0.001);
    XCTAssertEqualWithAccuracy(ad.durationMs, 20000.0, 0.001);
    XCTAssertEqual(ad.trackingEvents.count, 4u);
}

#pragma mark - JSON-data path

- (void)testDecode_fromJSONData_full {
    NSError *err = nil;
    MTTrackingResponse *resp = [MTTrackingResponse fromJSONData:[self loadFixtureData:@"tracking_full"] error:&err];
    XCTAssertNil(err);
    XCTAssertNotNil(resp);
    XCTAssertEqual(resp.avails.count, 1u);
}

- (void)testDecode_fromJSONData_emptyData_returnsNil {
    NSError *err = nil;
    MTTrackingResponse *resp = [MTTrackingResponse fromJSONData:[NSData data] error:&err];
    XCTAssertNil(resp);
    XCTAssertNotNil(err);
}

#pragma mark - tracking_empty_ads — Bug A2 surface

- (void)testDecode_emptyAds_availIsNoFill {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_empty_ads"]];
    XCTAssertEqual(resp.avails.count, 1u);
    MTAvail *avail = resp.avails.firstObject;
    XCTAssertEqualObjects(avail.availId, @"avail-no-fill");
    XCTAssertEqual(avail.ads.count, 0u);
    XCTAssertTrue(avail.isNoFill, @"empty ads must be classified as no-fill (Bug A2)");
}

#pragma mark - tracking_with_nexttoken — Bug B1

- (void)testDecode_nextToken_roundTrips {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_with_nexttoken"]];
    XCTAssertEqualObjects(resp.nextToken, @"abc123", @"nextToken must be parsed (Bug B1)");
    XCTAssertEqual(resp.avails.count, 0u);
}

- (void)testDecode_missingNextToken_isNil {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_full"]];
    XCTAssertNil(resp.nextToken);
}

- (void)testDecode_emptyNextTokenString_isNil {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:@{@"nextToken": @"", @"avails": @[]}];
    XCTAssertNil(resp.nextToken, @"empty string should normalize to nil");
}

#pragma mark - tracking_live — Bug B7 surface

- (void)testDecode_live_propagatesProgramDateTime {
    MTTrackingResponse *resp = [MTTrackingResponse fromDictionary:[self loadFixture:@"tracking_live"]];
    MTAvail *avail = resp.avails.firstObject;
    XCTAssertEqualObjects(avail.availProgramDateTime, @"2026-06-22T18:00:00.000Z");
    MTAd *ad = avail.ads.firstObject;
    XCTAssertEqualObjects(ad.adProgramDateTime, @"2026-06-22T18:00:00.000Z");
}

#pragma mark - Bad input

- (void)testDecode_nonObjectInput_returnsNil {
    XCTAssertNil([MTTrackingResponse fromDictionary:(id)@"not a dict"]);
    XCTAssertNil([MTTrackingResponse fromDictionary:(id)@[@"array"]]);
}

@end
