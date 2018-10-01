//
//  TimestampValue.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 28/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "TimestampValue.h"

@interface TimestampValue ()

@property (nonatomic) NSTimeInterval mainTimestamp;
@property (nonatomic) NSTimeInterval externalTimestamp;

@end

@implementation TimestampValue

+ (instancetype)build:(NSTimeInterval)timestamp {
    TimestampValue *obj = [[TimestampValue alloc] init];
    [obj setMain:timestamp];
    return obj;
}

- (instancetype)init {
    if (self = [super init]) {
        self.mainTimestamp = 0;
        self.externalTimestamp = 0;
    }
    return self;
}

- (void)setMain:(NSTimeInterval)timestamp {
    self.mainTimestamp = timestamp;
}

- (void)setExternal:(NSTimeInterval)timestamp {
    self.externalTimestamp = timestamp;
}

- (NSTimeInterval)timestamp {
    if (self.externalTimestamp > 0) {
        return self.externalTimestamp;
    }
    else {
        return self.mainTimestamp;
    }
}

- (NSTimeInterval)sinceMillis {
    if (self.timestamp > 0) {
        return 1000.0f * TIMESINCE(self.timestamp);
    }
    else {
        return 0;
    }
}

@end
