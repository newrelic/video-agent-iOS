//
//  NewRelicVideoTests.m
//  NewRelicVideoTests
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "PlaybackAutomat.h"
#import "BackendActions.h"
#import "ContentsTracker.h"
#import "AdsTracker.h"
#import "Tracker_internal.h"

#pragma mark - Support Classes

@interface Tracker ()
@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *attributeGetters;
@end

@interface TestContentsTracker: ContentsTracker <ContentsTrackerProtocol>
@end

@implementation TestContentsTracker

- (NSString *)getTrackerName {
    return @"TestContentsTracker";
}

- (NSString *)getTrackerVersion {
    return @"Y.Z";
}

- (NSString *)getPlayerName {
    return @"FakePlayer";
}

- (NSString *)getPlayerVersion {
    return @"X.Y";
}

@end

@interface TestAdsTracker: AdsTracker <AdsTrackerProtocol>
@end

@implementation TestAdsTracker

- (NSString *)getTrackerName {
    return @"TestAdsTracker";
}

- (NSString *)getTrackerVersion {
    return @"Y.Z";
}

- (NSString *)getPlayerName {
    return @"FakePlayer";
}

- (NSString *)getPlayerVersion {
    return @"X.Y";
}

@end

#pragma mark - Test Class

@interface NewRelicVideoTests : XCTestCase

@end

@implementation NewRelicVideoTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBackend {
    BackendActions *actions = [[BackendActions alloc] init];
    [actions sendRequest];
    [actions sendStart];
    [actions sendEnd];
    [actions sendPause];
    [actions sendResume];
    [actions sendSeekStart];
    [actions sendSeekEnd];
    [actions sendBufferStart];
    [actions sendBufferEnd];
    [actions sendHeartbeat];
    [actions sendRenditionChange];
    [actions sendError:@"Test error message"];
    
    [actions sendAdRequest];
    [actions sendAdStart];
    [actions sendAdEnd];
    [actions sendAdPause];
    [actions sendAdResume];
    [actions sendAdSeekStart];
    [actions sendAdSeekEnd];
    [actions sendAdBufferStart];
    [actions sendAdBufferEnd];
    [actions sendAdHeartbeat];
    [actions sendAdRenditionChange];
    [actions sendAdError:@"Test error message"];
    [actions sendAdBreakStart];
    [actions sendAdBreakEnd];
    [actions sendAdQuartile];
    [actions sendAdClick];
    
    [actions sendPlayerReady];
    [actions sendDownload];
    
    [actions sendAction:@"TEST_ACTION"];
    [actions sendAction:@"TEST_ACTION" attr:@{@"testAttr": @"testValue"}];
}

- (void)testTrackerAutomator {
    PlaybackAutomat *automat = [[PlaybackAutomat alloc] init];
    [self runAutomatTest:automat];
}

- (void)testTrackerAutomatorForAds {
    PlaybackAutomat *automat = [[PlaybackAutomat alloc] init];
    automat.isAd = YES;
    [self runAutomatTest:automat];
}

- (void)testTracker {
    Tracker *tracker = [[Tracker alloc] init];
    [self runTrackerTest:tracker];
}

- (void)testContentsTracker {
    TestContentsTracker *tracker = [[TestContentsTracker alloc] init];
    [self runTrackerTest:tracker];
    NSString *trackerName = (NSString *)[tracker optionValueFor:@"trackerName" fromGetters:tracker.attributeGetters];
    XCTAssert([trackerName isEqualToString:@"TestContentsTracker"], @"TrackerName incorrect");
}

- (void)testAdsTracker {
    TestAdsTracker *tracker = [[TestAdsTracker alloc] init];
    [self runTrackerTest:tracker];
    NSString *trackerName = (NSString *)[tracker optionValueFor:@"trackerName" fromGetters:tracker.attributeGetters];
    XCTAssert([trackerName isEqualToString:@"TestAdsTracker"], @"TrackerName incorrect");
}

#pragma mark - Utils

- (void)runAutomatTest:(PlaybackAutomat *)automat {
    
    XCTAssert(automat.state == TrackerStateStopped, @"State not Stopped");
    
    [automat sendRequest];
    XCTAssert(automat.state == TrackerStateStarting, @"State not Starting");
    
    [automat sendStart];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendPause];
    XCTAssert(automat.state == TrackerStatePaused, @"State not Paused");
    
    [automat sendResume];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Paying");
    
    [automat sendBufferStart];
    XCTAssert(automat.state == TrackerStateBuffering, @"State not Buffering");
    
    [automat sendPause];
    XCTAssert(automat.state == TrackerStateBuffering, @"State not Buffering");
    
    [automat sendBufferEnd];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendSeekStart];
    XCTAssert(automat.state == TrackerStateSeeking, @"State not Seeking");
    
    [automat sendResume];
    XCTAssert(automat.state == TrackerStateSeeking, @"State not Seeking");
    
    [automat sendBufferEnd];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendHeartbeat];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendError:@"Test error message"];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendRenditionChange];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat sendEnd];
    XCTAssert(automat.state == TrackerStateStopped, @"State not Stopped");
}

- (void)runTrackerTest:(Tracker *)tracker {
    [tracker reset];
    [tracker setup];
    [tracker sendRequest];
    [tracker sendStart];
    [tracker sendEnd];
    [tracker sendPause];
    [tracker sendResume];
    [tracker sendSeekStart];
    [tracker sendSeekEnd];
    [tracker sendBufferStart];
    [tracker sendBufferEnd];
    [tracker sendHeartbeat];
    [tracker sendRenditionChange];
    [tracker sendError:@"Test error message"];
    [tracker sendPlayerReady];
    [tracker sendDownload];
    [tracker sendCustomAction:@"TEST_ACTION"];
    [tracker sendCustomAction:@"TEST_ACTION" attr:@{@"testAttr": @"testValue"}];
    [tracker setOptionKey:@"option" value:@123];
    [tracker setOptionKey:@"option" value:@123 forAction:@"TEST_ACTION"];
    [tracker setOptions:@{@"option": @123}];
    [tracker setOptions:@{@"option": @123} forAction:@"TEST_ACTION"];
}


//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
