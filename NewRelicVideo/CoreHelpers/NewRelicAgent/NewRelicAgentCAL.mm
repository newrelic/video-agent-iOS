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
#import "DictionaryTrans.h"

@implementation NewRelicAgentCAL

bool recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr)
{
    // TODO: log the attr
    AV_LOG(@"sendAction name = %s", name.c_str());
    
    NSMutableDictionary *attributes = @{@"actionName": [NSString stringWithUTF8String:name.c_str()]}.mutableCopy;
    [attributes addEntriesFromDictionary:fromMapToDictionary(attr)];
    
    if ([NewRelicAgent currentSessionId]) {
        return (bool)[NewRelic recordCustomEvent:VIDEO_EVENT attributes:attributes];
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
        return (bool)NO;
    }
}

@end
