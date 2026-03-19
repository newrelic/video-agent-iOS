//
//  NRVAHarvestManagerQoETests.m
//  NewRelicVideoCoreTests
//
//  Unit tests for NRVAHarvestManager QoE harvest integration:
//  multiplier gate, dirty check, and pending final QoE priority.
//
//  These tests exercise collectQoeEventIfNeeded and qoeAttributesChangedFrom:to:
//  by setting the qoeEventProvider directly and calling the public/internal methods.
//

@import XCTest;
#import "NRVAHarvestManager.h"
#import "NRVAVideoConfiguration.h"
#import "NRVideoDefs.h"

// Expose private methods for testing
@interface NRVAHarvestManager (Testing)

- (NSDictionary *)collectQoeEventIfNeeded;
- (BOOL)qoeAttributesChangedFrom:(NSDictionary *)previous to:(NSDictionary *)current;

@property (nonatomic) NSInteger qoeCycleCount;
@property (nonatomic, strong) NSDictionary *pendingFinalQoe;
@property (nonatomic, strong) NSDictionary *lastSentQoEAttributes;

@end

@interface NRVAHarvestManagerQoETests : XCTestCase

@property (nonatomic) NRVAHarvestManager *harvestManager;

@end

@implementation NRVAHarvestManagerQoETests

- (void)setUp {
    [super setUp];
    NRVAVideoConfiguration *config = [[[NRVAVideoConfiguration builder]
                                        withApplicationToken:@"test-token"]
                                       build];
    self.harvestManager = [[NRVAHarvestManager alloc] initWithConfiguration:config];
}

- (void)tearDown {
    self.harvestManager = nil;
    [super tearDown];
}

#pragma mark - No Provider

- (void)testCollectReturnsNilWithNoProvider {
    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result, @"Should return nil when no provider is set");
}

#pragma mark - Multiplier Gate (Default = 1)

- (void)testFirstCycleAlwaysSendsWithMultiplierOne {
    __block int providerCallCount = 0;
    NSDictionary *qoeEvent = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        providerCallCount++;
        return qoeEvent;
    };

    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result, @"First cycle should send with multiplier=1");
    XCTAssertEqual(providerCallCount, 1);
}

- (void)testEverySecondCycleWithMultiplierTwo {
    // Use a config with multiplier=2
    NRVAVideoConfiguration *config = [[[[NRVAVideoConfiguration builder]
                                         withApplicationToken:@"test-token"]
                                        withQoeAggregateIntervalMultiplier:2]
                                       build];
    self.harvestManager = [[NRVAHarvestManager alloc] initWithConfiguration:config];

    __block int providerCallCount = 0;
    NSDictionary *event1 = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    NSDictionary *event2 = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @YES,
        KPI_TOTAL_REBUFFERING_TIME: @(100),
        KPI_REBUFFERING_RATIO: @(1.0)
    };

    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        providerCallCount++;
        return (providerCallCount <= 1) ? event1 : event2;
    };

    // Cycle 1: qualifies (first cycle)
    NSDictionary *result1 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result1, @"Cycle 1 should qualify with multiplier=2");

    // Cycle 2: does NOT qualify
    NSDictionary *result2 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result2, @"Cycle 2 should NOT qualify with multiplier=2");

    // Cycle 3: qualifies
    NSDictionary *result3 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result3, @"Cycle 3 should qualify with multiplier=2");
}

#pragma mark - Dirty Check

- (void)testFirstQoEEventAlwaysSent {
    NSDictionary *qoeEvent = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return qoeEvent;
    };

    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result, @"First QoE event should always be sent (no previous snapshot)");
}

- (void)testUnchangedKPIsAreSkipped {
    NSDictionary *qoeEvent = @{
        @"actionName": QOE_AGGREGATE,
        @"timestamp": @(1000),
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return qoeEvent;
    };

    // First call — always sent
    NSDictionary *result1 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result1);

    // Second call with same KPIs — should be skipped
    NSDictionary *result2 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result2, @"Should skip when KPI values haven't changed");
}

- (void)testChangedKPIsAreSent {
    __block int callCount = 0;
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        callCount++;
        if (callCount == 1) {
            return @{
                @"actionName": QOE_AGGREGATE,
                KPI_HAD_STARTUP_ERROR: @NO,
                KPI_HAD_PLAYBACK_ERROR: @NO,
                KPI_TOTAL_REBUFFERING_TIME: @(0),
                KPI_REBUFFERING_RATIO: @(0.0)
            };
        } else {
            return @{
                @"actionName": QOE_AGGREGATE,
                KPI_HAD_STARTUP_ERROR: @NO,
                KPI_HAD_PLAYBACK_ERROR: @YES,  // changed!
                KPI_TOTAL_REBUFFERING_TIME: @(500),  // changed!
                KPI_REBUFFERING_RATIO: @(1.5)  // changed!
            };
        }
    };

    NSDictionary *result1 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result1, @"First event should be sent");

    NSDictionary *result2 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result2, @"Should send when KPI values changed");
}

- (void)testDirtyCheckIgnoresMetadataKeys {
    // Two events with same KPIs but different timestamps — should be skipped
    __block int callCount = 0;
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        callCount++;
        return @{
            @"actionName": QOE_AGGREGATE,
            @"eventType": NR_VIDEO_EVENT,
            @"timestamp": @(callCount * 1000),  // different each time
            KPI_HAD_STARTUP_ERROR: @NO,
            KPI_HAD_PLAYBACK_ERROR: @NO,
            KPI_TOTAL_REBUFFERING_TIME: @(0),
            KPI_REBUFFERING_RATIO: @(0.0)
        };
    };

    NSDictionary *result1 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNotNil(result1, @"First event always sent");

    NSDictionary *result2 = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result2, @"Should skip — only timestamp changed, not KPIs");
}

#pragma mark - qoeAttributesChangedFrom:to: Direct Tests

- (void)testChangedFromNilAlwaysReturnsYES {
    NSDictionary *current = @{KPI_HAD_STARTUP_ERROR: @NO};
    BOOL changed = [self.harvestManager qoeAttributesChangedFrom:nil to:current];
    XCTAssertTrue(changed, @"Should always return YES when previous is nil");
}

- (void)testChangedFromEqualReturnNO {
    NSDictionary *event = @{
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    BOOL changed = [self.harvestManager qoeAttributesChangedFrom:event to:event];
    XCTAssertFalse(changed, @"Should return NO when all KPIs are equal");
}

- (void)testChangedWhenKPIAppearsReturnsYES {
    NSDictionary *prev = @{
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    NSDictionary *curr = @{
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0),
        KPI_STARTUP_TIME: @(2000)  // new KPI appeared
    };
    BOOL changed = [self.harvestManager qoeAttributesChangedFrom:prev to:curr];
    XCTAssertTrue(changed, @"Should return YES when a KPI appears in current but not previous");
}

- (void)testChangedWhenKPIDisappearsReturnsYES {
    NSDictionary *prev = @{
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0),
        KPI_STARTUP_TIME: @(2000)
    };
    NSDictionary *curr = @{
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
        // KPI_STARTUP_TIME gone
    };
    BOOL changed = [self.harvestManager qoeAttributesChangedFrom:prev to:curr];
    XCTAssertTrue(changed, @"Should return YES when a KPI disappears from current");
}

#pragma mark - Pending Final QoE

- (void)testPendingFinalQoETakesPriority {
    // Set up both a provider and a pending final QoE
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return @{@"actionName": QOE_AGGREGATE, @"source": @"provider"};
    };

    NSDictionary *finalEvent = @{
        @"actionName": QOE_AGGREGATE,
        @"source": @"final",
        KPI_TOTAL_REBUFFERING_TIME: @(0)
    };
    // Directly set pendingFinalQoe (bypassing dispatch_async for test synchronicity)
    self.harvestManager.pendingFinalQoe = finalEvent;

    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertEqualObjects(result[@"source"], @"final",
                          @"Pending final QoE should take priority over provider");
}

- (void)testPendingFinalQoEClearsProvider {
    __block int providerCalled = 0;
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        providerCalled++;
        return @{@"actionName": QOE_AGGREGATE};
    };

    NSDictionary *finalEvent = @{@"actionName": QOE_AGGREGATE, KPI_TOTAL_REBUFFERING_TIME: @(0)};
    self.harvestManager.pendingFinalQoe = finalEvent;

    // Collect final — should clear provider
    [self.harvestManager collectQoeEventIfNeeded];

    // Next collect should return nil (provider was cleared)
    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result, @"Provider should be nil after final QoE is collected");
    XCTAssertEqual(providerCalled, 0, @"Provider should never have been called");
}

- (void)testPendingFinalQoEClearsSnapshotForNextSession {
    // Build up a snapshot from first session
    NSDictionary *event = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return event;
    };
    [self.harvestManager collectQoeEventIfNeeded];  // Sets lastSentQoEAttributes

    // Now simulate CONTENT_END with final QoE
    NSDictionary *finalEvent = @{@"actionName": QOE_AGGREGATE, KPI_TOTAL_REBUFFERING_TIME: @(0)};
    self.harvestManager.pendingFinalQoe = finalEvent;
    [self.harvestManager collectQoeEventIfNeeded];  // Clears snapshot

    XCTAssertNil(self.harvestManager.lastSentQoEAttributes,
                 @"Snapshot should be cleared after final QoE for next session");
}

- (void)testPendingFinalQoEResetsCycleCount {
    // Simulate a few cycles
    NSDictionary *event = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return event;
    };
    [self.harvestManager collectQoeEventIfNeeded]; // cycle 1
    [self.harvestManager collectQoeEventIfNeeded]; // cycle 2

    // Final QoE
    NSDictionary *finalEvent = @{@"actionName": QOE_AGGREGATE, KPI_TOTAL_REBUFFERING_TIME: @(0)};
    self.harvestManager.pendingFinalQoe = finalEvent;
    [self.harvestManager collectQoeEventIfNeeded];

    XCTAssertEqual(self.harvestManager.qoeCycleCount, 0,
                   @"Cycle count should be reset after final QoE");
}

#pragma mark - Provider Returns Nil

- (void)testProviderReturningNilDoesNotSend {
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return nil;
    };

    NSDictionary *result = [self.harvestManager collectQoeEventIfNeeded];
    XCTAssertNil(result, @"Should not send when provider returns nil");
}

#pragma mark - Setting Provider Resets Cycle Count

- (void)testSettingProviderResetsCycleCount {
    NSDictionary *event = @{
        @"actionName": QOE_AGGREGATE,
        KPI_HAD_STARTUP_ERROR: @NO,
        KPI_HAD_PLAYBACK_ERROR: @NO,
        KPI_TOTAL_REBUFFERING_TIME: @(0),
        KPI_REBUFFERING_RATIO: @(0.0)
    };
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return event;
    };
    [self.harvestManager collectQoeEventIfNeeded]; // cycle 1

    // Re-set provider (simulates new session)
    self.harvestManager.qoeEventProvider = ^NSDictionary * {
        return event;
    };

    XCTAssertEqual(self.harvestManager.qoeCycleCount, 0,
                   @"Setting provider should reset cycle count");
}

@end
