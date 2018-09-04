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

#pragma mark - Tracker Content Events

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

#pragma mark - Tracker Ad Events

- (void)sendAdRequest {
    [self sendAction:AD_REQUEST];
}

- (void)sendAdStart {
    [self sendAction:AD_START];
}

- (void)sendAdEnd {
    [self sendAction:AD_END];
}

- (void)sendAdPause {
    [self sendAction:AD_PAUSE];
}

- (void)sendAdResume {
    [self sendAction:AD_RESUME];
}

- (void)sendAdSeekStart {
    [self sendAction:AD_SEEK_START];
}

- (void)sendAdSeekEnd {
    [self sendAction:AD_SEEK_END];
}

- (void)sendAdBufferStart {
    [self sendAction:AD_BUFFER_START];
}

- (void)sendAdBufferEnd {
    [self sendAction:AD_BUFFER_END];
}

- (void)sendAdHeartbeat {
    [self sendAction:AD_HEARTBEAT];
}

- (void)sendAdRenditionChange {
    [self sendAction:AD_RENDITION_CHANGE];
}

- (void)sendAdError {
    [self sendAction:AD_ERROR];
}

- (void)sendAdBreakStart {
    [self sendAction:AD_BREAK_START];
}

- (void)sendAdBreakEnd {
    [self sendAction:AD_BREAK_END];
}

- (void)sendAdQuartile {
    [self sendAction:AD_QUARTILE];
}

- (void)sendAdClick {
    [self sendAction:AD_CLICK];
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
