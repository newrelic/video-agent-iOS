//
//  MediaTailorUITests.m
//  SimplePlayerWithAdsUITests
//
//  Drives the MediaTailor Sample button + action sheet so a real end-to-end
//  playback/ad-tracking run can be captured via device logs, without needing
//  macOS Accessibility permission for OS-level UI scripting.
//

#import <XCTest/XCTest.h>

@interface MediaTailorUITests : XCTestCase
@end

@implementation MediaTailorUITests

- (void)testPlayMediaTailorSample_directImplicit_andWaitForPlayback {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    XCUIElement *button = app.buttons[@"MediaTailor Sample"];
    XCTAssertTrue([button waitForExistenceWithTimeout:10.0], @"MediaTailor Sample button did not appear");
    [button tap];

    XCUIElement *option = app.buttons[@"Direct/Implicit (CloudFront)"];
    XCTAssertTrue([option waitForExistenceWithTimeout:5.0], @"action sheet option did not appear");
    [option tap];

    // Let playback run long enough to cross multiple known ad avails
    // (0s, 26s, 52s, 74s in the test content) while logs/screenshots are
    // captured externally.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:120.0]];
}

- (void)testPlayMediaTailorSample_explicitSessionInit_andWaitForPlayback {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    XCUIElement *button = app.buttons[@"MediaTailor Sample"];
    XCTAssertTrue([button waitForExistenceWithTimeout:10.0], @"MediaTailor Sample button did not appear");
    [button tap];

    XCUIElement *option = app.buttons[@"Explicit Session-Init (CloudFront)"];
    XCTAssertTrue([option waitForExistenceWithTimeout:5.0], @"action sheet option did not appear");
    [option tap];

    // Let playback run long enough to cross multiple known ad avails
    // (0s, 26s, 52s, 74s in the test content) while logs/screenshots are
    // captured externally.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:120.0]];
}

- (void)testPlayMediaTailorSample_legacyRawEndpoint_andWaitForPlayback {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    XCUIElement *button = app.buttons[@"MediaTailor Sample"];
    XCTAssertTrue([button waitForExistenceWithTimeout:10.0], @"MediaTailor Sample button did not appear");
    [button tap];

    XCUIElement *option = app.buttons[@"Legacy (raw MediaTailor endpoint, no CDN)"];
    XCTAssertTrue([option waitForExistenceWithTimeout:5.0], @"action sheet option did not appear");
    [option tap];

    // Let playback run long enough to cross multiple known ad avails
    // (0s, 26s, 52s, 74s in the test content) while logs/screenshots are
    // captured externally.
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:120.0]];
}

@end
