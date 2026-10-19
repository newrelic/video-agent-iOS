//
//  NRVABufferDropLoggingTests.m
//  NewRelicVideoCoreTests
//
//  Buffer-capacity logging: INFO at 85% fill, WARNING at 90%, ERROR with a running count on every drop.
//

@import XCTest;
#import "NRVAPriorityEventBuffer.h"
#import "NRVASizeEstimator.h"
#import "NRVALog.h"
#import "NRVAVideoConfiguration.h"

// Non-TV on-demand capacity is 350: 85% = 298 events, 90% = 315 events.
static const NSInteger kOndemandCapacity = 350;

@interface NRVABufferDropLoggingTests : XCTestCase
@property (nonatomic, strong) NSMutableArray<NSString *> *messages;
@property (nonatomic, strong) NSLock *lock;
@end

@implementation NRVABufferDropLoggingTests

- (void)setUp {
    self.messages = [NSMutableArray array];
    self.lock = [[NSLock alloc] init];
    [self startCapturingAtLevel:NRVALoggingLevelInfo];
}

- (void)tearDown {
    [NRVALog setBufferLogObserver:nil];
    [NRVALog setBufferLoggingEnabled:NO level:NRVALoggingLevelInfo];
}

- (void)startCapturingAtLevel:(NRVALoggingLevel)level {
    __weak typeof(self) weakSelf = self;
    [NRVALog setBufferLogObserver:^(NRVALoggingLevel l, NSString *message) {
        [weakSelf.lock lock];
        [weakSelf.messages addObject:[NSString stringWithFormat:@"%ld|%@", (long)l, message]];
        [weakSelf.lock unlock];
    }];
    [NRVALog setBufferLoggingEnabled:YES level:level];
}

- (NRVAPriorityEventBuffer *)newBuffer {
    return [[NRVAPriorityEventBuffer alloc] initWithIsTV:NO];
}

// Adds are async on the buffer's queue; getEventCount is a sync call on the same queue, so it drains them.
- (void)addEvents:(NSInteger)n to:(NRVAPriorityEventBuffer *)buffer {
    for (NSInteger i = 0; i < n; i++) {
        [buffer addEvent:@{@"actionName": @"TEST", @"i": @(i)}];
    }
    [buffer getEventCount];
}

- (NSArray<NSString *> *)messagesAtLevel:(NRVALoggingLevel)level {
    [self.lock lock];
    NSArray *all = [self.messages copy];
    [self.lock unlock];
    NSString *prefix = [NSString stringWithFormat:@"%ld|", (long)level];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", prefix];
    return [all filteredArrayUsingPredicate:p];
}

- (void)testThresholdMessagesLoggedOncePerCrossing {
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:297 to:buffer];
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 0u);

    [self addEvents:1 to:buffer];   // 298 = 85%
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 1u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 0u);

    [self addEvents:16 to:buffer];  // 314, still below 90%
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 0u);

    [self addEvents:1 to:buffer];   // 315 = 90%
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 1u);

    [self addEvents:20 to:buffer];  // 335, no repeats
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 1u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 1u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelError].count, 0u);
}

- (void)testLatchResetsAfterHarvestDrain {
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:320 to:buffer];
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 1u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 1u);

    // Drain below 85% with the harvest path, then cross again.
    while ([buffer getEventCount] > 200) {
        NSArray *batch = [buffer pollBatchByPriority:1024 * 1024 sizeEstimator:nil priority:@"ondemand"];
        XCTAssertGreaterThan(batch.count, 0u);
    }
    [self addEvents:120 to:buffer];
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 2u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 2u);
}

- (void)testEveryDropLoggedWithCumulativeCountAcrossDrains {
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:kOndemandCapacity + 3 to:buffer];

    NSArray *errors = [self messagesAtLevel:NRVALoggingLevelError];
    XCTAssertEqual(errors.count, 3u);
    XCTAssertTrue([errors[0] hasSuffix:@"Total dropped events this session: 1"], @"%@", errors[0]);
    XCTAssertTrue([errors[2] hasSuffix:@"Total dropped events this session: 3"], @"%@", errors[2]);
    XCTAssertEqual([buffer getEventCount], kOndemandCapacity, @"eviction behavior must be unchanged");

    // A harvest and a refill to overflow again must continue the count, not restart it.
    [buffer pollBatchByPriority:1024 * 1024 sizeEstimator:nil priority:@"ondemand"];
    [self addEvents:kOndemandCapacity to:buffer];
    errors = [self messagesAtLevel:NRVALoggingLevelError];
    XCTAssertGreaterThan(errors.count, 3u);
    NSString *last = errors.lastObject;
    NSString *expected = [NSString stringWithFormat:@"Total dropped events this session: %lu", (unsigned long)errors.count];
    XCTAssertTrue([last hasSuffix:expected], @"%@", last);
}

- (void)testLevelFilterAndDisabledSuppressLogs {
    [self startCapturingAtLevel:NRVALoggingLevelError];
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:kOndemandCapacity + 1 to:buffer];
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelInfo].count, 0u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelWarning].count, 0u);
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelError].count, 1u);

    [NRVALog setBufferLoggingEnabled:NO level:NRVALoggingLevelInfo];
    [self addEvents:5 to:buffer];
    XCTAssertEqual([self messagesAtLevel:NRVALoggingLevelError].count, 1u);
}

- (void)testConfigurationDefaultsAndBuilder {
    NRVAVideoConfiguration *defaults = [[[NRVAVideoConfiguration builder] withApplicationToken:@"AAtoken"] build];
    XCTAssertFalse(defaults.loggingEnabled);
    XCTAssertEqual(defaults.loggingLevel, NRVALoggingLevelInfo);

    NRVAVideoConfiguration *config = [[[[[NRVAVideoConfiguration builder] withApplicationToken:@"AAtoken"]
                                        withLoggingEnabled:YES] withLoggingLevel:NRVALoggingLevelWarning] build];
    XCTAssertTrue(config.loggingEnabled);
    XCTAssertEqual(config.loggingLevel, NRVALoggingLevelWarning);
}

@end
