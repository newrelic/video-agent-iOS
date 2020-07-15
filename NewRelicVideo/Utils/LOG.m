//
//  LOG.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 27/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "LOG.h"
#import "Vars.h"
#import "NewRelicVideoAgent.h"

@implementation LOG

void AV_LOG(NSString *format, ...) {
    LOG_CODE
}

+ (void)measure:(void (^)(void))blockName name:(NSString *)name {
    NSDate *methodStart = [NSDate date];
    
    blockName();
    
    NSDate *methodFinish = [NSDate date];
    NSTimeInterval executionTime = [methodFinish timeIntervalSinceDate:methodStart];
    NSLog(@"MEASURE %@ = %f", name, executionTime);
}

@end
