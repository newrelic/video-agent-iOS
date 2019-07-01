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
#import "BackgroundEvents.h"
#include "ValueHolder.hpp"
#include <string>
#include <map>

@interface NewRelicAgentCAL ()

@property (nonatomic) NSString *uuid;

@end

@implementation NewRelicAgentCAL

// NOTE: when the app is in background and playback paused, the heartbeat stopes after a while

+ (instancetype)sharedInstance {
    static NewRelicAgentCAL *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[NewRelicAgentCAL alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActiveNotif:) name:UIApplicationDidBecomeActiveNotification object:nil];
        // Load array of events from plist
        [[BackgroundEvents sharedInstance] loadEvents];
        // And sync them (if any)
        [self uploadBackgroundEvents];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)appDidBecomeActiveNotif:(NSNotification*)notif {
    AV_LOG(@"App Did Become Active, upload background events");
    [self uploadBackgroundEvents];
}

- (void)storeBackgroundEvent:(NSMutableDictionary *)event {
    // Add event to array and update plist
    [[BackgroundEvents sharedInstance] addEvent:event];
}

- (void)uploadBackgroundEvents {
    // Sync all events
    [[BackgroundEvents sharedInstance] traverseEvents:^(NSMutableDictionary *dict) {
        AV_LOG(@"Record event that happened in background = %@", dict[@"actionName"]);
        [NewRelic recordCustomEvent:VIDEO_EVENT attributes:dict];
    }];
    // Remove events and plist
    [[BackgroundEvents sharedInstance] flushEvents];
}

- (void)generateUUID {
    self.uuid = [[NSProcessInfo processInfo] globallyUniqueString];
}

bool recordCustomEvent(std::string name, std::map<std::string, ValueHolder> attr)
{
    AV_LOG(@"sendAction name = %s", name.c_str());
    
    NSMutableDictionary *attributes = @{@"actionName": [NSString stringWithUTF8String:name.c_str()]}.mutableCopy;
    [attributes addEntriesFromDictionary:fromMapToDictionary(attr)];
    
    //AV_LOG(@"Attr = %@", attributes);
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
        [attributes setObject:@(YES) forKey:@"isBackgroundEvent"];
        [[NewRelicAgentCAL sharedInstance] storeBackgroundEvent:attributes];
        AV_LOG(@"APP IN BACKGROUND, list = %@", [BackgroundEvents sharedInstance]);
        return (bool)NO;
    }
    else {
        [attributes setObject:@(NO) forKey:@"isBackgroundEvent"];
        if ([NewRelicAgent currentSessionId]) {
            return (bool)[NewRelic recordCustomEvent:VIDEO_EVENT attributes:attributes];
        }
        else {
            NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
            return (bool)NO;
        }
    }
}

std::string currentSessionId() {
    NSString *sid = [NewRelicAgentCAL sharedInstance].uuid;
    if (sid) {
        return std::string([sid UTF8String]);
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
        return "";
    }
}

@end
