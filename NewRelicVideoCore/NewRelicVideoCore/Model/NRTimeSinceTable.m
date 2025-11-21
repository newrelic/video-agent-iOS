//
//  NRTimeSinceTable.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 16/12/2020.
//

#import "NRTimeSinceTable.h"
#import "NRTimeSince.h"

@interface NRTimeSinceTable ()

@property (nonatomic) NSMutableArray<NRTimeSince *> *timeSinceTable;
@property (nonatomic) dispatch_queue_t isolationQueue;

@end

@implementation NRTimeSinceTable

- (instancetype)init {
    if (self = [super init]) {
        self.timeSinceTable = @[].mutableCopy;
        // Create a concurrent queue for reads, barrier for writes
        self.isolationQueue = dispatch_queue_create("com.newrelic.timeSinceTable", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)dealloc {
    // No need to release the queue in ARC, but good practice to null it
    _isolationQueue = nil;
}

- (void)addEntryWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter {
    [self addEntry:[[NRTimeSince alloc] initWithAction:action attribute:attribute applyTo:filter]];
}

- (void)addEntry:(NRTimeSince *)ts {
    // Use barrier to ensure exclusive write access
    dispatch_barrier_async(self.isolationQueue, ^{
        [self.timeSinceTable addObject:ts];
    });
}

- (void)applyAttributes:(NSString *)action attributes:(NSMutableDictionary *)attr {
    // Use barrier for write access since [ts now] modifies state
    dispatch_barrier_sync(self.isolationQueue, ^{
        for (NRTimeSince *ts in self.timeSinceTable) {
            if ([ts isMatch:action]) {
                [attr setObject:[ts timeSince] forKey:[ts attributeName]];
            }
            if ([ts isAction:action]) {
                [ts now];
            }
        }
    });
}

@end
