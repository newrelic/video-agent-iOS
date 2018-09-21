//
//  NewRelicVideoTests.m
//  NewRelicVideoTests
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

// TODO: test PlaybackAutomat

#import "TrackerAutomat.h"
#import "BackendActions.h"
#import "ContentsTracker.h"
#import "AdsTracker.h"

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
    [actions sendError];
    
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
    [actions sendAdError];
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
    TrackerAutomat *automat = [[TrackerAutomat alloc] init];
    [self runAutomatTest:automat];
}

- (void)testTrackerAutomatorForAds {
    TrackerAutomat *automat = [[TrackerAutomat alloc] init];
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

- (void)runAutomatTest:(TrackerAutomat *)automat {
    
    XCTAssert(automat.state == TrackerStateStopped, @"State not Stopped");
    
    [automat transition:TrackerTransitionClickPlay];
    XCTAssert(automat.state == TrackerStateStarting, @"State not Starting");
    
    [automat transition:TrackerTransitionFrameShown];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionClickPause];
    XCTAssert(automat.state == TrackerStatePaused, @"State not Paused");
    
    [automat transition:TrackerTransitionClickPlay];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Paying");
    
    [automat transition:TrackerTransitionInitBuffering];
    XCTAssert(automat.state == TrackerStateBuffering, @"State not Buffering");
    
    [automat transition:TrackerTransitionClickPause];
    XCTAssert(automat.state == TrackerStateBuffering, @"State not Buffering");
    
    [automat transition:TrackerTransitionEndBuffering];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionInitDraggingSlider];
    XCTAssert(automat.state == TrackerStateSeeking, @"State not Seeking");
    
    [automat transition:TrackerTransitionClickPlay];
    XCTAssert(automat.state == TrackerStateSeeking, @"State not Seeking");
    
    [automat transition:TrackerTransitionEndDraggingSlider];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionHeartbeat];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionErrorPlaying];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionRenditionChanged];
    XCTAssert(automat.state == TrackerStatePlaying, @"State not Playing");
    
    [automat transition:TrackerTransitionVideoFinished];
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
    [tracker sendError];
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
