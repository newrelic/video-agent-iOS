//
//  Stack.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Stack.h"

@interface Stack ()

@property (nonatomic) NSMutableArray *theArray;

@end

@implementation Stack

- (instancetype)init {
    if (self = [super init]) {
        self.theArray = @[].mutableCopy;
    }
    return self;
}

- (void)push:(id)item {
    [self.theArray addObject:item];
}

- (id)pop {
    id item = nil;
    if ([self.theArray count] != 0) {
        item = [self.theArray lastObject];
        [self.theArray removeLastObject];
    }
    return item;
}

- (id)peek {
    id item = nil;
    if ([self.theArray count] != 0) {
        item = [self.theArray lastObject];
    }
    return item;
}

- (NSUInteger)count {
    return self.theArray.count;
}

- (void)clear {
    [self.theArray removeAllObjects];
}

@end
