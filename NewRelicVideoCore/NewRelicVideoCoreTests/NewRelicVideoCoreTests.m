//
//  NewRelicVideoCoreTests.m
//  NewRelicVideoCoreTests
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import <XCTest/XCTest.h>
#import "NRVAVideoPlayerConfiguration.h"

@interface NewRelicVideoCoreTests : XCTestCase

@end

@implementation NewRelicVideoCoreTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

#pragma mark - P0-116: NRAdConfig ad-tracker selection

- (void)testAdConfig_csai {
    NRAdConfig *c = [NRAdConfig csai];
    XCTAssertEqual(c.type, NRAdTrackerTypeCSAI);
    XCTAssertNil(c.adSegmentPrefix);
    XCTAssertNil(c.trackingUrl);
}

- (void)testAdConfig_mediaTailor_defaults {
    NRAdConfig *c = [NRAdConfig mediaTailor];
    XCTAssertEqual(c.type, NRAdTrackerTypeMediaTailor);
    XCTAssertNil(c.adSegmentPrefix);
    XCTAssertNil(c.trackingUrl);
}

- (void)testAdConfig_mediaTailor_customCDN {
    NRAdConfig *c = [NRAdConfig mediaTailorWithSegmentPrefix:@"/ads/" trackingUrl:@"https://host/track"];
    XCTAssertEqual(c.type, NRAdTrackerTypeMediaTailor);
    XCTAssertEqualObjects(c.adSegmentPrefix, @"/ads/");
    XCTAssertEqualObjects(c.trackingUrl, @"https://host/track");
}

/// Legacy adEnabled:YES must map to a CSAI config (no behavior change).
- (void)testPlayerConfig_legacyAdEnabled_mapsToCSAI {
    NRVAVideoPlayerConfiguration *cfg =
        [[NRVAVideoPlayerConfiguration alloc] initWithPlayerName:@"p" player:nil adEnabled:YES];
    XCTAssertTrue(cfg.isAdEnabled);
    XCTAssertNotNil(cfg.adConfig);
    XCTAssertEqual(cfg.adConfig.type, NRAdTrackerTypeCSAI);
}

- (void)testPlayerConfig_adConfigMediaTailor {
    NRVAVideoPlayerConfiguration *cfg =
        [[NRVAVideoPlayerConfiguration alloc] initWithPlayerName:@"p"
                                                          player:nil
                                                        adConfig:[NRAdConfig mediaTailor]
                                                customAttributes:nil];
    XCTAssertTrue(cfg.isAdEnabled);
    XCTAssertEqual(cfg.adConfig.type, NRAdTrackerTypeMediaTailor);
}

- (void)testPlayerConfig_nilAdConfig_disablesAds {
    NRVAVideoPlayerConfiguration *cfg =
        [[NRVAVideoPlayerConfiguration alloc] initWithPlayerName:@"p"
                                                          player:nil
                                                        adConfig:nil
                                                customAttributes:nil];
    XCTAssertFalse(cfg.isAdEnabled);
    XCTAssertNil(cfg.adConfig);
}

@end
