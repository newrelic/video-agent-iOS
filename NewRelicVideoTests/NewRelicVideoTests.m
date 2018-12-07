//
//  NewRelicVideoTests.m
//  NewRelicVideoTests
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ContentsTracker.h"
#import "AdsTracker.h"

#pragma mark - Support Classes

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

- (void)testContentsTracker {
    TestContentsTracker *tracker = [[TestContentsTracker alloc] init];
    [self runTrackerTest:tracker];
}

- (void)testAdsTracker {
    TestAdsTracker *tracker = [[TestAdsTracker alloc] init];
    [self runTrackerTest:tracker];
}

#pragma mark - Utils

- (void)runTrackerTest:(id<TrackerProtocol>)tracker {
    
    XCTAssert([tracker isKindOfClass:AdsTracker.class] || [tracker isKindOfClass:ContentsTracker.class], @"Invalid tracker class");
    
    [tracker reset];
    [tracker setup];
    
    XCTAssert(tracker.state == TrackerStateStopped, @"State not Stopped");
    
    [tracker setOptionKey:@"option" value:@123];
    [tracker setOptionKey:@"option" value:@123 forAction:@"TEST_ACTION"];
    
    XCTAssert([tracker setTimestamp:1000 attributeName:@"xxxxx"] == NO, @"Error setting unknown timestamp");
    XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceTrackerReady"], @"Error setting timeSinceTrackerReady");
    XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceLastRenditionChange"], @"Error setting timeSinceLastRenditionChange");
    XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceRequested"], @"Error setting timeSinceRequested");
    
    if ([tracker isKindOfClass:AdsTracker.class]) {
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceLastAdHeartbeat"], @"Error setting timeSinceLastAdHeartbeat");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceAdStarted"], @"Error setting timeSinceAdStarted");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceAdPaused"], @"Error setting timeSinceAdPaused");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceAdBufferBegin"], @"Error setting timeSinceAdBufferBegin");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceAdSeekBegin"], @"Error setting timeSinceAdSeekBegin");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceAdBreakBegin"], @"Error setting timeSinceAdBreakBegin");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceLastAdQuartile"], @"Error setting timeSinceLastAdQuartile");
    }
    else {
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceStarted"], @"Error setting timeSinceStarted");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSincePaused"], @"Error setting timeSincePaused");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceBufferBegin"], @"Error setting timeSinceBufferBegin");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceSeekBegin"], @"Error setting timeSinceSeekBegin");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceLastAd"], @"Error setting timeSinceLastAd");
        XCTAssert([tracker setTimestamp:1000 attributeName:@"timeSinceLastHeartbeat"], @"Error setting timeSinceLastHeartbeat");
    }
    
    XCTAssert(tracker.state == TrackerStateStopped, @"State not Stopped");
    
    [tracker sendRequest];
    XCTAssert(tracker.state == TrackerStateStarting, @"State not Starting");
    
    [tracker sendStart];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendPause];
    XCTAssert(tracker.state == TrackerStatePaused, @"State not Paused");
    
    [tracker sendResume];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Paying");
    
    [tracker sendBufferStart];
    XCTAssert(tracker.state == TrackerStateBuffering, @"State not Buffering");
    
    [tracker sendPause];
    XCTAssert(tracker.state == TrackerStateBuffering, @"State not Buffering");
    
    [tracker sendBufferEnd];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendSeekStart];
    XCTAssert(tracker.state == TrackerStateSeeking, @"State not Seeking");
    
    [tracker sendSeekEnd];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendHeartbeat];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendError:@"Test error message"];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendRenditionChange];
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    [tracker sendPlayerReady];
    [tracker sendDownload];
    [tracker sendHeartbeat];
    [tracker sendCustomAction:@"TEST_ACTION"];
    [tracker sendCustomAction:@"TEST_ACTION" attr:@{@"testAttr": @"testValue"}];
    
    XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    
    if ([tracker isKindOfClass:AdsTracker.class]) {
        [(AdsTracker *)tracker sendAdBreakStart];
        XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
        [(AdsTracker *)tracker sendAdClick];
        XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
        [(AdsTracker *)tracker sendAdQuartile];
        XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
        [(AdsTracker *)tracker sendAdBreakEnd];
        XCTAssert(tracker.state == TrackerStatePlaying, @"State not Playing");
    }
    
    [tracker sendEnd];
    XCTAssert(tracker.state == TrackerStateStopped, @"State not Stopped");
}

@end
