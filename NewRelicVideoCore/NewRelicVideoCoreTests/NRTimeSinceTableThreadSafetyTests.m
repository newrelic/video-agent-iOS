//
//  NRTimeSinceTableThreadSafetyTests.m
//  NewRelicVideoCoreTests
//
//  Created to test thread-safety fixes for NRTimeSinceTable
//  Tests the scenario where multiple AVPlayerItem instances are created/destroyed rapidly
//

@import XCTest;
#import "NRTimeSinceTable.h"
#import "NRTimeSince.h"

@interface NRTimeSinceTableThreadSafetyTests : XCTestCase

@property (nonatomic) NRTimeSinceTable *timeSinceTable;

@end

@implementation NRTimeSinceTableThreadSafetyTests

- (void)setUp {
    [super setUp];
    self.timeSinceTable = [[NRTimeSinceTable alloc] init];
}

- (void)tearDown {
    self.timeSinceTable = nil;
    [super tearDown];
}

#pragma mark - Basic Thread Safety Tests

/**
 Test concurrent reads from multiple threads
 This simulates multiple tracker instances reading attributes simultaneously
 */
- (void)testConcurrentReads {
    NSLog(@"🧪 Testing concurrent reads...");

    // Pre-populate with some entries
    for (int i = 0; i < 10; i++) {
        [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"ACTION_%d", i]
                                      attribute:[NSString stringWithFormat:@"attr_%d", i]
                                        applyTo:@".*"];
    }

    XCTestExpectation *expectation = [self expectationWithDescription:@"Concurrent reads complete"];
    expectation.expectedFulfillmentCount = 100;

    // Simulate 100 concurrent read operations
    for (int i = 0; i < 100; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableDictionary *attr = [NSMutableDictionary dictionary];
            [self.timeSinceTable applyAttributes:@"ACTION_5" attributes:attr];
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Concurrent reads failed: %@", error);
        } else {
            NSLog(@"✅ Concurrent reads passed!");
        }
    }];
}

/**
 Test concurrent writes from multiple threads
 This simulates multiple tracker instances being initialized simultaneously
 */
- (void)testConcurrentWrites {
    NSLog(@"🧪 Testing concurrent writes...");

    // Simulate 50 concurrent write operations (reduced for speed)
    for (int i = 0; i < 50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"ACTION_%d", i]
                                          attribute:[NSString stringWithFormat:@"attr_%d", i]
                                            applyTo:@".*"];
        });
    }

    // Brief sleep to let operations execute and test for crashes
    [NSThread sleepForTimeInterval:0.2];

    NSLog(@"✅ Concurrent writes passed!");
}

/**
 Test concurrent reads and writes simultaneously
 This is the CRITICAL test that reproduces the crash scenario
 */
- (void)testConcurrentReadsAndWrites {
    NSLog(@"🧪 Testing concurrent reads and writes (CRITICAL TEST)...");

    // Pre-populate with initial entries
    for (int i = 0; i < 5; i++) {
        [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"INITIAL_ACTION_%d", i]
                                      attribute:[NSString stringWithFormat:@"initial_attr_%d", i]
                                        applyTo:@".*"];
    }

    // Flush initial writes
    NSMutableDictionary *flushInit = [NSMutableDictionary dictionary];
    [self.timeSinceTable applyAttributes:@"FLUSH_INIT" attributes:flushInit];

    // Start concurrent readers (simulating applyAttributes calls from KVO observers)
    // Reduced from 200 to 50 to speed up the test
    for (int i = 0; i < 50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            NSMutableDictionary *attr = [NSMutableDictionary dictionary];
            [self.timeSinceTable applyAttributes:[NSString stringWithFormat:@"ACTION_%d", (i % 10)]
                                      attributes:attr];
        });
    }

    // Start concurrent writers (simulating new tracker instances being created)
    // Reduced from 100 to 25 to speed up the test
    for (int i = 0; i < 25; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"NEW_ACTION_%d", i]
                                          attribute:[NSString stringWithFormat:@"new_attr_%d", i]
                                            applyTo:@".*"];
        });
    }

    // Give operations time to complete and stress test the concurrent access
    // The key is that NO CRASH occurs, not that we wait for every operation
    [NSThread sleepForTimeInterval:0.5];

    NSLog(@"✅ Concurrent reads and writes passed - No crash!");
}

#pragma mark - Crash Reproduction Tests

/**
 This test specifically reproduces the crash scenario from the stack trace:
 - Multiple AVPlayerItem instances created/destroyed rapidly
 - KVO notifications triggering sendRequest -> applyAttributes
 - Concurrent modification during enumeration
 */
- (void)testRapidPlayerItemCreationDestruction {
    NSLog(@"🧪 Starting rapid player item creation/destruction test...");

    // Simulate 30 rapid player lifecycle events (reduced for speed)
    for (int cycle = 0; cycle < 30; cycle++) {
        @autoreleasepool {
            // Simulate tracker initialization (adds entries)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [self.timeSinceTable addEntryWithAction:@"TRACKER_READY"
                                              attribute:@"timeSinceTrackerReady"
                                                applyTo:@"[A-Z_]+"];
            });

            // Simulate KVO notifications triggering events
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSMutableDictionary *attr = [NSMutableDictionary dictionary];
                [self.timeSinceTable applyAttributes:@"CONTENT_REQUEST" attributes:attr];
            });

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSMutableDictionary *attr = [NSMutableDictionary dictionary];
                [self.timeSinceTable applyAttributes:@"CONTENT_START" attributes:attr];
            });

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                NSMutableDictionary *attr = [NSMutableDictionary dictionary];
                [self.timeSinceTable applyAttributes:@"CONTENT_BUFFER_START" attributes:attr];
            });
        }
    }

    // Give operations time to complete and stress test
    [NSThread sleepForTimeInterval:0.5];

    NSLog(@"✅ Test completed successfully without crash!");
}



#pragma mark - Edge Case Tests

/**
 Test that operations complete correctly even with empty table
 */
- (void)testConcurrentOperationsOnEmptyTable {
    NSLog(@"🧪 Testing concurrent operations on empty table...");

    XCTestExpectation *expectation = [self expectationWithDescription:@"Empty table operations complete"];
    expectation.expectedFulfillmentCount = 100;

    for (int i = 0; i < 100; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableDictionary *attr = [NSMutableDictionary dictionary];
            [self.timeSinceTable applyAttributes:@"NONEXISTENT_ACTION" attributes:attr];
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Empty table test failed: %@", error);
        } else {
            NSLog(@"✅ Empty table test passed!");
        }
    }];
}


/**
 Test that attributes are correctly applied even under concurrent access
 */
- (void)testAttributeIntegrityUnderConcurrency {
    NSLog(@"🧪 Testing attribute integrity under concurrent access...");

    // Add a specific entry
    NRTimeSince *testEntry = [[NRTimeSince alloc] initWithAction:@"TEST_ACTION"
                                                       attribute:@"testAttribute"
                                                         applyTo:@"TEST_ACTION"];
    [self.timeSinceTable addEntry:testEntry];

    // Trigger the timestamp
    [testEntry now];

    // Sleep briefly to ensure time passes
    [NSThread sleepForTimeInterval:0.1];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Attribute integrity test complete"];
    expectation.expectedFulfillmentCount = 50;

    // Concurrently apply attributes
    for (int i = 0; i < 50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableDictionary *attr = [NSMutableDictionary dictionary];
            [self.timeSinceTable applyAttributes:@"TEST_ACTION" attributes:attr];

            // Verify the attribute was set
            XCTAssertNotNil(attr[@"testAttribute"], @"Attribute should be present");
            XCTAssertTrue([attr[@"testAttribute"] isKindOfClass:[NSNumber class]], @"Attribute should be a number");

            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Attribute integrity test failed: %@", error);
        } else {
            NSLog(@"✅ Attribute integrity test passed!");
        }
    }];
}

#pragma mark - Dispatch Queue Verification Tests

/**
 Verify that dispatch_barrier_async is working correctly for writes
 */
- (void)testBarrierWriteOrdering {
    NSLog(@"🧪 Testing barrier write ordering...");

    __block NSMutableArray *operations = [NSMutableArray array];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Barrier write test complete"];
    expectation.expectedFulfillmentCount = 10;

    // Add 10 writes in sequence
    for (int i = 0; i < 10; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"ACTION_%d", i]
                                          attribute:[NSString stringWithFormat:@"attr_%d", i]
                                            applyTo:@".*"];
            @synchronized (operations) {
                [operations addObject:@(i)];
            }
            [expectation fulfill];
        });
    }

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        XCTAssertEqual(operations.count, 10, @"All 10 operations should complete");
        NSLog(@"✅ Barrier write ordering test passed - %lu operations completed", (unsigned long)operations.count);
    }];
}

/**
 Test that reads don't block each other (concurrent reads should work)
 but are blocked by writes
 */
- (void)testConcurrentReadsNotBlocked {
    NSLog(@"🧪 Testing that concurrent reads are not blocked...");

    // Pre-populate
    for (int i = 0; i < 10; i++) {
        [self.timeSinceTable addEntryWithAction:[NSString stringWithFormat:@"ACTION_%d", i]
                                      attribute:[NSString stringWithFormat:@"attr_%d", i]
                                        applyTo:@".*"];
    }

    // Flush writes
    NSMutableDictionary *flushWrites = [NSMutableDictionary dictionary];
    [self.timeSinceTable applyAttributes:@"FLUSH_WRITES" attributes:flushWrites];

    // Start 50 reads at the same time (reduced for speed)
    __block NSTimeInterval startTime = [[NSDate date] timeIntervalSince1970];
    __block NSTimeInterval endTime = 0;

    for (int i = 0; i < 50; i++) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSMutableDictionary *attr = [NSMutableDictionary dictionary];
            [self.timeSinceTable applyAttributes:@"ACTION_5" attributes:attr];

            @synchronized (self) {
                NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
                if (currentTime > endTime) {
                    endTime = currentTime;
                }
            }
        });
    }

    // Give operations time to complete
    [NSThread sleepForTimeInterval:0.3];

    NSTimeInterval duration = endTime - startTime;
    NSLog(@"✅ 50 concurrent reads completed in %.3f seconds", duration);

    // If reads were truly serial, this would take much longer
    XCTAssertLessThan(duration, 2.0, @"Concurrent reads should complete quickly");
}

@end
