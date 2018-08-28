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

@interface BackendActions ()

@property (nonatomic) NSString *viewId;
@property (nonatomic) int viewIdIndex;

@end

@implementation BackendActions

- (instancetype)init {
    if (self = [super init]) {
        self.viewId = @"";
        self.viewIdIndex = 0;
        [self generateViewId];
    }
    return self;
}

- (void)generateViewId {
    if ([NewRelicAgent currentSessionId]) {
        self.viewId = [[NewRelicAgent currentSessionId] stringByAppendingFormat:@"-%d", self.viewIdIndex];
        self.viewIdIndex ++;
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
}

#pragma mark - Tracker Method

- (void)sendRequest {
    [self sendAction:CONTENT_REQUEST];
}

- (void)sendStart:(NSTimeInterval)timeToStart {
    timeToStart = timeToStart < 0 ? 0 : timeToStart;
    [self sendAction:CONTENT_START attr:@{@"timeSinceRequested": @(timeToStart * 1000.0f)}];
}

- (void)sendEnd {
    [self sendAction:CONTENT_END];
    [self generateViewId];
}

- (void)sendPause {
    [self sendAction:CONTENT_PAUSE];
}

- (void)sendResume {
    [self sendAction:CONTENT_RESUME];
}

- (void)sendSeekStart {
    [self sendAction:CONTENT_SEEK_START];
}

- (void)sendSeekEnd {
    [self sendAction:CONTENT_SEEK_END];
}

- (void)sendBufferStart {
    [self sendAction:CONTENT_BUFFER_START];
}

- (void)sendBufferEnd {
    [self sendAction:CONTENT_BUFFER_END];
}

- (void)sendHeartbeat {
    [self sendAction:CONTENT_HEARTBEAT];
}

- (void)sendRenditionChange {
    [self sendAction:CONTENT_RENDITION_CHANGE];
}

- (void)sendError {
    [self sendAction:CONTENT_ERROR];
}

#pragma mark - SendAction

- (void)sendAction:(NSString *)name {
    [self sendAction:name attr:nil];
}

- (void)sendAction:(NSString *)name attr:(NSDictionary *)dict {
    
    dict = dict ? dict : @{};
    NSMutableDictionary *ops = @{@"actionName": name,
                                 @"viewId": self.viewId,
                                 @"viewSession": [NewRelicAgent currentSessionId]}.mutableCopy;
    [ops addEntriesFromDictionary:dict];
    
    if ([NewRelicAgent currentSessionId]) {
        [NewRelic recordCustomEvent:VIDEO_EVENT
                         attributes:ops];
    }
    else {
        NSLog(@"⚠️ The NewRelicAgent is not initialized, you need to do it before using the NewRelicVideo. ⚠️");
    }
    
    AV_LOG(@"sendAction name = %@, attr = %@", name, ops);
}

@end
