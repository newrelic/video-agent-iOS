//
//  LOG.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 27/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LOG_CODE    if ([[Vars appNumber:@"NRVideoAgentDebug"] boolValue]) {\
                        NSString *contents;\
                        va_list args;\
                        va_start(args, format);\
                        contents = [[NSString alloc] initWithFormat:format arguments:args];\
                        va_end(args);\
                        NSTimeInterval nowEpochSeconds = [[NSDate date] timeIntervalSince1970];\
                        contents = [@"NewRelicVideo " stringByAppendingFormat:@"(%f): %@", nowEpochSeconds, contents];\
                        NSLog(@"%@", contents);\
                    }

@interface LOG : NSObject

void AV_LOG(NSString *format, ...);

@end
