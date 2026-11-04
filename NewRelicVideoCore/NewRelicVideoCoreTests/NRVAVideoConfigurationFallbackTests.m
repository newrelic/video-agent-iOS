//
//  NRVAVideoConfigurationFallbackTests.m
//  NewRelicVideoCoreTests
//
//  Covers the base-agent config fallback added to NRVAVideoConfiguration:
//  when the caller omits an explicit applicationToken, build() falls back
//  to the base New Relic iOS agent's bundled newrelic.json (licenseKey),
//  mirroring the equivalent fallback shipped for video-core-js and
//  video-agent-android.
//

@import XCTest;
#import "NRVAVideoConfiguration.h"

@interface NRVAVideoConfiguration (ConfigFallbackTesting)
+ (NSString *)tryReadBaseAgentApplicationToken;
+ (NSString *)tryReadBaseAgentApplicationTokenAtPath:(NSString *)path;
@end

@interface NRVAVideoConfigurationFallbackTests : XCTestCase
@property (nonatomic, strong) NSString *tempFilePath;
@end

@implementation NRVAVideoConfigurationFallbackTests

- (void)tearDown {
    if (self.tempFilePath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
        self.tempFilePath = nil;
    }
    [super tearDown];
}

- (NSString *)writeTempFileWithContents:(NSString *)contents {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                       [[NSUUID UUID] UUIDString]];
    [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.tempFilePath = path;
    return path;
}

#pragma mark - tryReadBaseAgentApplicationTokenAtPath: (parsing logic)

- (void)testValidJsonReturnsLicenseKey {
    NSString *path = [self writeTempFileWithContents:
        @"{\"appId\": 211766715, \"accountId\": 1, \"trustedAccountKey\": 1, "
        @"\"licenseKey\": \"AA00000000000000000000000000000000000000-NRMA\"}"];

    NSString *token = [NRVAVideoConfiguration tryReadBaseAgentApplicationTokenAtPath:path];

    XCTAssertEqualObjects(token, @"AA00000000000000000000000000000000000000-NRMA");
}

- (void)testMalformedJsonReturnsNil {
    NSString *path = [self writeTempFileWithContents:@"{not valid json"];

    NSString *token = [NRVAVideoConfiguration tryReadBaseAgentApplicationTokenAtPath:path];

    XCTAssertNil(token);
}

- (void)testMissingLicenseKeyReturnsNil {
    NSString *path = [self writeTempFileWithContents:
        @"{\"appId\": 211766715, \"accountId\": 1, \"trustedAccountKey\": 1}"];

    NSString *token = [NRVAVideoConfiguration tryReadBaseAgentApplicationTokenAtPath:path];

    XCTAssertNil(token);
}

- (void)testEmptyLicenseKeyReturnsNil {
    NSString *path = [self writeTempFileWithContents:@"{\"licenseKey\": \"\"}"];

    NSString *token = [NRVAVideoConfiguration tryReadBaseAgentApplicationTokenAtPath:path];

    XCTAssertNil(token);
}

- (void)testJsonArrayInsteadOfObjectReturnsNil {
    NSString *path = [self writeTempFileWithContents:@"[1, 2, 3]"];

    NSString *token = [NRVAVideoConfiguration tryReadBaseAgentApplicationTokenAtPath:path];

    XCTAssertNil(token);
}

- (void)testNonExistentPathReturnsNilWithoutThrowing {
    NSString *token;
    XCTAssertNoThrow(token = [NRVAVideoConfiguration
                               tryReadBaseAgentApplicationTokenAtPath:@"/no/such/file/newrelic.json"]);
    XCTAssertNil(token);
}

#pragma mark - tryReadBaseAgentApplicationToken (real [NSBundle mainBundle] path)

- (void)testNoNewrelicJsonInMainBundleReturnsNilWithoutThrowing {
    // The CoreTests host app's bundle has no newrelic.json — same as any
    // real app that hasn't set up the base agent via this file.
    NSString *token;
    XCTAssertNoThrow(token = [NRVAVideoConfiguration tryReadBaseAgentApplicationToken]);
    XCTAssertNil(token);
}

#pragma mark - build() integration — explicit config always wins, no base agent still throws

- (void)testExplicitTokenIsUsedAndUnaffectedByFallback {
    NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
                                        withApplicationToken:@"explicit-test-token-1234567890"]
                                       build];

    XCTAssertEqualObjects(config.applicationToken, @"explicit-test-token-1234567890");
}

- (void)testBuildStillThrowsWhenNoExplicitTokenAndNoBaseAgentConfig {
    // Baseline regression: with no newrelic.json present (true in this test
    // host app) and no explicit token, behavior must be unchanged from
    // before this fallback existed — build() throws, it doesn't silently
    // succeed with a nil/empty token.
    XCTAssertThrows([[NRVAVideoConfiguration builder] build]);
}

@end
