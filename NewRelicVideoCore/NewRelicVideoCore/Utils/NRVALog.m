//
//  NRVALog.m
//  NewRelicVideoAgent
//
//  Created by Video Agent Team.
//  Copyright © 2024 New Relic. All rights reserved.
//

#import "NRVALog.h"
#import "NewRelicVideoAgent.h"
#import <os/log.h>

static _Atomic NRVALoggingLevel sBufferLoggingLevel = NRVALoggingLevelInfo;

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

void NRVA_BUFFER_LOG(NRVALoggingLevel level, NSString *format, ...) {
    if (![[NewRelicVideoAgent sharedInstance] logging] || level < sBufferLoggingLevel) return;

    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log = os_log_create("com.newrelic.videoagent", "buffer"); });

    switch (level) {
        case NRVALoggingLevelInfo:
            os_log_with_type(log, OS_LOG_TYPE_INFO, "NRVideoAgent [INFO] %{public}@", message);
            break;
        case NRVALoggingLevelWarning:
            os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "NRVideoAgent [WARNING] %{public}@", message);
            break;
        case NRVALoggingLevelError:
            os_log_with_type(log, OS_LOG_TYPE_ERROR, "NRVideoAgent [ERROR] %{public}@", message);
            break;
    }
}

+ (void)setBufferLoggingLevel:(NRVALoggingLevel)level {
    sBufferLoggingLevel = level;
}

+ (void)setLoggingEnabled:(BOOL)enabled {
    [[NewRelicVideoAgent sharedInstance] setLogging:enabled];
}

+ (BOOL)isLoggingEnabled {
    return [[NewRelicVideoAgent sharedInstance] logging];
}

@end
