//
//  NRVABufferDropLoggingTests.m
//  NewRelicVideoCoreTests
//
//  Buffer-capacity logging: INFO at 85% fill, WARNING at 90%, ERROR with a running count on every drop.
//  Messages are read back from the process's own os_log store.
//

@import XCTest;
@import OSLog;
#import "NRVAPriorityEventBuffer.h"
#import "NRVADeadLetterEventBuffer.h"
#import "NewRelicVideoAgent.h"
#import "NRVALog.h"
#import "NRVAVideoConfiguration.h"

// Non-TV capacities: on-demand 350 (85% = 298, 90% = 315), dead letter 100 (85% = 85, 90% = 90).
static const NSInteger kOndemandCapacity = 350;
static const NSInteger kDeadLetterCapacity = 100;

// Every test that reads the log store returns early below iOS/tvOS 15, where OSLogStore is unavailable.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface NRVABufferDropLoggingTests : XCTestCase
@property (nonatomic, strong) NSDate *start;
// Messages already in the process log when the test began, so earlier tests don't leak into counts
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *baseline;
@end

@implementation NRVABufferDropLoggingTests

- (void)setUp {
    self.start = [NSDate dateWithTimeIntervalSinceNow:-1];
    [[NewRelicVideoAgent sharedInstance] setLogging:YES];
    [NRVALog setBufferLoggingLevel:NRVALoggingLevelInfo];
    self.baseline = nil;
    if (@available(iOS 15.0, tvOS 15.0, *)) {
        NSMutableDictionary *base = [NSMutableDictionary dictionary];
        for (NSString *label in @[@"ondemand event buffer", @"Dead letter"]) {
            for (NSString *tag in @[@"INFO", @"WARNING", @"ERROR"]) {
                base[[label stringByAppendingString:tag]] = @([self rawMessages:label withTag:tag].count);
            }
        }
        self.baseline = base;
    }
}

- (void)tearDown {
    [[NewRelicVideoAgent sharedInstance] setLogging:NO];
    [NRVALog setBufferLoggingLevel:NRVALoggingLevelInfo];
}

- (NRVAPriorityEventBuffer *)newBuffer {
    return [[NRVAPriorityEventBuffer alloc] initWithIsTV:NO];
}

// Adds are async on the buffer's queue; getEventCount is a sync call on the same queue, so it drains them.
- (void)addEvents:(NSInteger)n to:(id<NRVAEventBufferInterface>)buffer {
    for (NSInteger i = 0; i < n; i++) {
        [buffer addEvent:@{@"actionName": @"TEST", @"i": @(i)}];
    }
    [buffer getEventCount];
}

// Messages emitted so far by this test process, as "LEVEL|text", where LEVEL is INFO, WARNING or ERROR.
- (NSArray<NSString *> *)messagesContaining:(NSString *)label {
    NSError *error = nil;
    OSLogStore *store = [OSLogStore storeWithScope:OSLogStoreCurrentProcessIdentifier error:&error];
    XCTAssertNotNil(store, @"%@", error);
    OSLogPosition *position = [store positionWithDate:self.start];
    NSMutableArray *result = [NSMutableArray array];
    for (OSLogEntry *entry in [store entriesEnumeratorWithOptions:0 position:position predicate:nil error:&error]) {
        if (![entry isKindOfClass:[OSLogEntryLog class]]) continue;
        if (![[(OSLogEntryLog *)entry subsystem] isEqualToString:@"com.newrelic.videoagent"]) continue;
        NSString *text = entry.composedMessage;
        if ([text containsString:label]) [result addObject:text];
    }
    return result;
}

- (NSArray<NSString *> *)messages:(NSString *)label withTag:(NSString *)tag {
    NSArray *all = [self rawMessages:label withTag:tag];
    NSUInteger skip = self.baseline[[label stringByAppendingString:tag]].unsignedIntegerValue;
    return skip >= all.count ? @[] : [all subarrayWithRange:NSMakeRange(skip, all.count - skip)];
}

- (NSArray<NSString *> *)rawMessages:(NSString *)label withTag:(NSString *)tag {
    NSString *prefix = [NSString stringWithFormat:@"NRVideoAgent [%@]", tag];
    NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", prefix];
    return [[self messagesContaining:label] filteredArrayUsingPredicate:p];
}

- (void)testMainBufferThresholdsLoggedOncePerCrossing {
    if (@available(iOS 15.0, tvOS 15.0, *)) {} else { return; }
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:297 to:buffer];
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"INFO"].count, 0u);

    [self addEvents:1 to:buffer];   // 298 = 85%
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"INFO"].count, 1u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"WARNING"].count, 0u);

    [self addEvents:17 to:buffer];  // 315 = 90%
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"WARNING"].count, 1u);

    [self addEvents:20 to:buffer];  // no repeats
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"INFO"].count, 1u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"WARNING"].count, 1u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"ERROR"].count, 0u);
}

- (void)testMainBufferLatchResetsAfterHarvestDrain {
    if (@available(iOS 15.0, tvOS 15.0, *)) {} else { return; }
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:320 to:buffer];
    while ([buffer getEventCount] > 200) {
        XCTAssertGreaterThan([buffer pollBatchByPriority:1024 * 1024 sizeEstimator:nil priority:@"ondemand"].count, 0u);
    }
    [self addEvents:120 to:buffer];
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"INFO"].count, 2u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"WARNING"].count, 2u);
}

- (void)testMainBufferEveryDropLoggedWithCumulativeCountAcrossDrains {
    if (@available(iOS 15.0, tvOS 15.0, *)) {} else { return; }
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:kOndemandCapacity + 3 to:buffer];
    NSArray *errors = [self messages:@"ondemand event buffer" withTag:@"ERROR"];
    XCTAssertEqual(errors.count, 3u);
    XCTAssertTrue([errors[0] hasSuffix:@"Total dropped events this session: 1"], @"%@", errors[0]);
    XCTAssertTrue([errors[2] hasSuffix:@"Total dropped events this session: 3"], @"%@", errors[2]);
    XCTAssertEqual([buffer getEventCount], kOndemandCapacity, @"eviction behavior must be unchanged");

    [buffer pollBatchByPriority:1024 * 1024 sizeEstimator:nil priority:@"ondemand"];
    [self addEvents:kOndemandCapacity to:buffer];
    errors = [self messages:@"ondemand event buffer" withTag:@"ERROR"];
    XCTAssertGreaterThan(errors.count, 3u);
    NSString *expected = [NSString stringWithFormat:@"Total dropped events this session: %lu", (unsigned long)errors.count];
    XCTAssertTrue([errors.lastObject hasSuffix:expected], @"%@", errors.lastObject);
}

- (void)testDeadLetterBufferThresholdsAndCumulativeDrops {
    if (@available(iOS 15.0, tvOS 15.0, *)) {} else { return; }
    NRVADeadLetterEventBuffer *buffer = [[NRVADeadLetterEventBuffer alloc] initWithIsTV:NO];
    [self addEvents:84 to:buffer];
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"INFO"].count, 0u);
    [self addEvents:1 to:buffer];   // 85
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"INFO"].count, 1u);
    [self addEvents:5 to:buffer];   // 90
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"WARNING"].count, 1u);
    [self addEvents:10 to:buffer];  // 100, full but nothing dropped yet
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"ERROR"].count, 0u);

    [self addEvents:2 to:buffer];
    NSArray *errors = [self messages:@"Dead letter" withTag:@"ERROR"];
    XCTAssertEqual(errors.count, 2u);
    XCTAssertTrue([errors[1] hasSuffix:@"Total dropped dead letter events this session: 2"], @"%@", errors[1]);
    XCTAssertEqual([buffer getEventCount], kDeadLetterCapacity, @"eviction behavior must be unchanged");
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"INFO"].count, 1u);
    XCTAssertEqual([self messages:@"Dead letter" withTag:@"WARNING"].count, 1u);
}

- (void)testLevelFilterAndDebugLoggingSwitch {
    if (@available(iOS 15.0, tvOS 15.0, *)) {} else { return; }
    [NRVALog setBufferLoggingLevel:NRVALoggingLevelError];
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:kOndemandCapacity + 1 to:buffer];
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"INFO"].count, 0u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"WARNING"].count, 0u);
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"ERROR"].count, 1u);

    [[NewRelicVideoAgent sharedInstance] setLogging:NO];
    [self addEvents:5 to:buffer];
    XCTAssertEqual([self messages:@"ondemand event buffer" withTag:@"ERROR"].count, 1u);
}

- (void)testBufferEvictionUnchangedWithLoggingOff {
    [[NewRelicVideoAgent sharedInstance] setLogging:NO];
    NRVAPriorityEventBuffer *buffer = [self newBuffer];
    [self addEvents:kOndemandCapacity + 10 to:buffer];
    XCTAssertEqual([buffer getEventCount], kOndemandCapacity);
}

- (void)testDebugLoggingBuilderDefaultsAndLevel {
    NRVAVideoConfiguration *defaults = [[[NRVAVideoConfiguration builder] withApplicationToken:@"AAtoken"] build];
    XCTAssertFalse(defaults.debugLoggingEnabled);
    XCTAssertEqual(defaults.debugLoggingLevel, NRVALoggingLevelInfo);

    NRVAVideoConfiguration *plain = [[[[NRVAVideoConfiguration builder] withApplicationToken:@"AAtoken"]
                                      withDebugLogging:YES] build];
    XCTAssertTrue(plain.debugLoggingEnabled);
    XCTAssertEqual(plain.debugLoggingLevel, NRVALoggingLevelInfo);

    NRVAVideoConfiguration *leveled = [[[[NRVAVideoConfiguration builder] withApplicationToken:@"AAtoken"]
                                        withDebugLogging:YES level:NRVALoggingLevelWarning] build];
    XCTAssertTrue(leveled.debugLoggingEnabled);
    XCTAssertEqual(leveled.debugLoggingLevel, NRVALoggingLevelWarning);
}

@end
