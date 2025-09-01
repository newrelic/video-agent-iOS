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

+ (NSString *)formatTimestamp {
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    // Get milliseconds
    NSTimeInterval timeInterval = [now timeIntervalSince1970];
    NSInteger milliseconds = (NSInteger)((timeInterval - floor(timeInterval)) * 1000);
    
    return [NSString stringWithFormat:@"%@.%03ld", [dateFormatter stringFromDate:now], (long)milliseconds];
}

void NRVA_DEBUG_LOG(NSString *format, ...) {
    if ([[NewRelicVideoAgent sharedInstance] logging]) {
        NSString *contents;
        va_list args;
        va_start(args, format);
        contents = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSString *timestamp = [NRVALog formatTimestamp];
        contents = [@"NRVideoAgent [DEBUG] " stringByAppendingFormat:@"(%@): %@", timestamp, contents];
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
    NSString *timestamp = [NRVALog formatTimestamp];
    contents = [@"NRVideoAgent [ERROR] " stringByAppendingFormat:@"(%@): %@", timestamp, contents];
    NSLog(@"%@", contents);
}

+ (void)setLoggingEnabled:(BOOL)enabled {
    [[NewRelicVideoAgent sharedInstance] setLogging:enabled];
}

+ (BOOL)isLoggingEnabled {
    return [[NewRelicVideoAgent sharedInstance] logging];
}

@end
