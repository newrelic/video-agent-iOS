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
    [tracker setOptionKey:@"option" value:@123];
    [tracker setOptionKey:@"option" value:@123 forAction:@"TEST_ACTION"];
    [tracker setTimestamp:1000 attributeName:@"timeSinceRequested"];
    [tracker setTimestamp:1000 attributeName:@"xxxx"];
    
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
    
    if ([tracker isKindOfClass:AdsTracker.class]) {
        [(AdsTracker *)tracker sendAdBreakStart];
        [(AdsTracker *)tracker sendAdClick];
        [(AdsTracker *)tracker sendAdQuartile];
        [(AdsTracker *)tracker sendAdBreakEnd];
    }
}

@end
