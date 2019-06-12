//
//  NewRelicAgentCAL.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/10/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicAgentCAL.h"
#import <UIKit/UIKit.h>
#import <NewRelicAgent/NewRelic.h>
#import "EventDefs.h"
#import "DictionaryTrans.h"
#include "ValueHolder.hpp"
#include <string>
#include <map>

#pragma mark - EventHolder class

@interface EventHolder : NSObject

@property NSTimeInterval timestamp;
@property (nonatomic) NSMutableDictionary *attributes;

@end

@implementation EventHolder

- (instancetype)initWithTimestamp:(NSTimeInterval)timestamp andAttributes:(NSMutableDictionary *)attributes {
    if (self = [super init]) {
        self.timestamp = timestamp;
        self.attributes = attributes;
        [self.attributes setObject:@((long)(timestamp * 1000.0f)) forKey:@"timestamp"];
    }
    return self;
}

- (NSString *)description {
    return [@"<EventHolder>: " stringByAppendingFormat:@"Timestamp = %f , Attributes = %@", self.timestamp, self.attributes];
}

@end

#pragma mark - NewRelicxAgentCAL class

@interface NewRelicAgentCAL ()

@property (nonatomic) NSMutableArray<EventHolder *> *backgroundEvents;

@end

@implementation NewRelicAgentCAL

// NOTE: when the app is in background and playback paused, the heartbeat stopes after a while

+ (instancetype)sharedInstance {
    static NewRelicAgentCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NewRelicAgentCAL alloc] init];
        sharedInstance.backgroundEvents = @[].mutableCopy;
    });
    return sharedInstance;
}

- (void)storeBackgroundEvent:(NSMutableDictionary *)event {
    EventHolder *eh = [[EventHolder alloc] initWithTimestamp:[[NSDate date] timeIntervalSince1970] andAttributes:event];
    [self.backgroundEvents addObject:eh];
}

- (void)flushBackgroundEvents {
    for (EventHolder *eh in self.backgroundEvents) {
        [NewRelic recordCustomEvent:VIDEO_EVENT attributes:eh.attributes];
    }
    [self.backgroundEvents removeAllObjects];
}

bool recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr)
{
    AV_LOG(@"sendAction name = %s", name.c_str());
    
    NSMutableDictionary *attributes = @{@"actionName": [NSString stringWithUTF8String:name.c_str()]}.mutableCopy;
    [attributes addEntriesFromDictionary:fromMapToDictionary(attr)];
    
    //AV_LOG(@"Attr = %@", attributes);
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        [[NewRelicAgentCAL sharedInstance] storeBackgroundEvent:attributes];
        AV_LOG(@"APP IN BACKGROUND, list = %@", [NewRelicAgentCAL sharedInstance].backgroundEvents);
        return (bool)NO;
    }
    else {
        if ([NewRelicAgent currentSessionId]) {
            [[NewRelicAgentCAL sharedInstance] flushBackgroundEvents];
            return (bool)[NewRelic recordCustomEvent:VIDEO_EVENT attributes:attributes];
        }
        else {
            NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
            return (bool)NO;
        }
    }
}

std::string currentSessionId() {
    NSString *sid = [NewRelicAgent currentSessionId];
    if (sid) {
        return std::string([sid UTF8String]);
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
        return "";
    }
}

@end
