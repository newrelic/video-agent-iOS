//
//  NRVideoLog.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NRVideoLog.h"
#import "NewRelicVideoAgent.h"

@implementation NRVideoLog

void AV_LOG(NSString *format, ...) {
    if ([[NewRelicVideoAgent sharedInstance] logging]) {
        NSString *contents;
        va_list args;
        va_start(args, format);
        contents = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];
        contents = [@"NewRelicVideo " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];
        NSLog(@"%@", contents);
    }
}

@end
