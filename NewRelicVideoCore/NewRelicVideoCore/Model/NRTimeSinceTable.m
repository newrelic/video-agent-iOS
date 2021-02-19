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

@end

@implementation NRTimeSinceTable

- (instancetype)init {
    if (self = [super init]) {
        self.timeSinceTable = @[].mutableCopy;
    }
    return self;
}

- (void)addEntryWithAction:(NSString *)action attribute:(NSString *)attribute applyTo:(NSString *)filter {
    [self addEntry:[[NRTimeSince alloc] initWithAction:action attribute:attribute applyTo:filter]];
}

- (void)addEntry:(NRTimeSince *)ts {
    [self.timeSinceTable addObject:ts];
}

- (void)applyAttributes:(NSString *)action attributes:(NSMutableDictionary *)attr {
    for (NRTimeSince *ts in self.timeSinceTable) {
        if ([ts isMatch:action]) {
            [attr setObject:[ts timeSince] forKey:[ts attributeName]];
        }
        if ([ts isAction:action]) {
            [ts now];
        }
    }
}

@end
