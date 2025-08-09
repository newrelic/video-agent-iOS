//
//  NRVALog.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVALog.h"
#import "NewRelicVideoAgent.h"

@implementation NRVALog

void NRVA_LOG(NSString *format, ...) {
    if ([[NewRelicVideoAgent sharedInstance] logging]) {
        NSString *contents;
        va_list args;
        va_start(args, format);
        contents = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];
        contents = [@"NRVideoAgent " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];
        NSLog(@"%@", contents);
    }
}

void NRVA_DEBUG_LOG(NSString *format, ...) {
    if ([[NewRelicVideoAgent sharedInstance] logging]) {
        NSString *contents;
        va_list args;
        va_start(args, format);
        contents = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];
        contents = [@"NRVideoAgent [DEBUG] " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];
        NSLog(@"%@", contents);
    }
}

void NRVA_ERROR_LOG(NSString *format, ...) {
    // Error logs are always shown, regardless of logging state
    NSString *contents;
    va_list args;
    va_start(args, format);
    contents = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];
    contents = [@"NRVideoAgent [ERROR] " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];
    NSLog(@"%@", contents);
}

+ (void)setLoggingEnabled:(BOOL)enabled {
    [[NewRelicVideoAgent sharedInstance] setLogging:enabled];
}

+ (BOOL)isLoggingEnabled {
    return [[NewRelicVideoAgent sharedInstance] logging];
}

@end
