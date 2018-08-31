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
@end

@implementation BackendActions

- (NSDictionary *)generalOptions {
    if (!_generalOptions) {
        _generalOptions = @{}.mutableCopy;
    }
    return _generalOptions;
}

- (NSMutableDictionary<NSString *,NSMutableDictionary *> *)actionOptions {
    if (!_actionOptions) {
        _actionOptions = @{}.mutableCopy;
    }
    return _actionOptions;
}

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

#pragma mark - Tracker Method

- (void)sendRequest {
    [self sendAction:CONTENT_REQUEST];
}

- (void)sendStart {
    [self sendAction:CONTENT_START];
}

- (void)sendEnd {
    [self sendAction:CONTENT_END];
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
    NSMutableDictionary *ops = @{@"actionName": name}.mutableCopy;
    [ops addEntriesFromDictionary:dict];
    [ops addEntriesFromDictionary:self.generalOptions];
    [ops addEntriesFromDictionary:[self.actionOptions objectForKey:name]];
    
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
