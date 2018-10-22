//
//  NewRelicAgentCAL.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicAgentCAL.h"
#import <NewRelicAgent/NewRelic.h>
#include <string>
#include <map>
#import "ValueHolder.hpp"
#import "EventDefs.h"

@implementation NewRelicAgentCAL

+ (BOOL)recordCustomEvent:(NSString* _Nonnull)eventType
               attributes:(NSDictionary* _Nullable)attributes {
    if ([NewRelicAgent currentSessionId]) {
        return [NewRelic recordCustomEvent:eventType attributes:attributes];
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
        return NO;
    }
}

int recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr)
{
    NSLog(@"-----------> recordCustomEvent = %s", name.c_str());
    
    // TODO: convert attr to NSDictionary
    
    return (int)[NewRelicAgentCAL recordCustomEvent:VIDEO_EVENT
                                         attributes:@{@"actionName": [NSString stringWithUTF8String:name.c_str()]}];
}

@end
