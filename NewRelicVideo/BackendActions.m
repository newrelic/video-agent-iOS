//
//  BackendActions.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <NewRelicAgent/NewRelic.h>
#import "BackendActions.h"
#import "EventDefs.h"

@implementation BackendActions

#pragma mark - Tracker Method

// TODO: Resume and seek start/end events.

- (void)sendResume {
    [self sendAction:CONTENT_RESUME];
}

- (void)sendPause {
    [self sendAction:CONTENT_PAUSE];
}

- (void)sendBufferEnd {
    [self sendAction:CONTENT_BUFFER_END];
}

- (void)sendBufferStart {
    [self sendAction:CONTENT_BUFFER_START];
}

- (void)sendError {
    [self sendAction:CONTENT_ERROR];
}

- (void)sendRequest {
    [self sendAction:CONTENT_REQUEST];
}

- (void)sendStart:(NSTimeInterval)timeToStart {
    timeToStart = timeToStart < 0 ? 0 : timeToStart;
    [self sendAction:CONTENT_START attr:@{@"timeSinceRequested": @(timeToStart * 1000.0f)}];
}

- (void)sendEnd {
    [self sendAction:CONTENT_END];
}

#pragma mark - SendAction

- (void)sendAction:(NSString *)name {
    [self sendAction:name attr:nil];
}

- (void)sendAction:(NSString *)name attr:(NSDictionary *)dict {
    
    dict = dict ? dict : @{};
    
    NSLog(@"sendAction name = %@, attr = %@", name, dict);
    
    NSMutableDictionary *ops = @{@"actionName": name}.mutableCopy;
    [ops addEntriesFromDictionary:dict];
    
    if ([NewRelicAgent currentSessionId]) {
        [NewRelic recordCustomEvent:VIDEO_EVENT
                         attributes:ops];
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
}

@end
