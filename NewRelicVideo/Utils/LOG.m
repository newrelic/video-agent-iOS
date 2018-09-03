//
//  LOG.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 27/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "LOG.h"
#import "Vars.h"

@implementation LOG

void AV_LOG(NSString *format, ...) {
    if ([[Vars appNumber:@"NRVideoAgentDebug"] boolValue]) {
        NSString *contents;
        va_list args;
        va_start(args, format);
        contents = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        
        // Log the current timestamp
        NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];
        contents = [@"NewRelicVideo " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];
        
        NSLog(@"%@", contents);
    }
}

@end
