//
//  NewRelicVideoTests.m
//  NewRelicVideoTests
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TrackerAutomat.h"
#import "BackendActions.h"

@import NewRelicVideo;

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
    [self performAutomatTest:automat];
}

- (void)testTrackerAutomatorForAds {
    TrackerAutomat *automat = [[TrackerAutomat alloc] init];
    automat.isAd = YES;
    [self performAutomatTest:automat];
}

#pragma mark - Utils

- (void)performAutomatTest:(TrackerAutomat *)automat {
    
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

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
