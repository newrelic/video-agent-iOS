//
//  Tracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <NewRelicAgent/NewRelic.h>
#import "Tracker.h"
#import "TimestampValue.h"
#import "DictionaryTrans.h"
#import "TrackerCore.hpp"
#import "ValueHolder.hpp"

@interface Tracker ()
{
    TrackerCore *trackerCore;
}

@property (nonatomic) NSTimer *playerStateObserverTimer;

// TODO: Time Since stuff
@property (nonatomic) TimestampValue *lastRenditionChangeTimestamp;
@property (nonatomic) TimestampValue *trackerReadyTimestamp;

@end

@implementation Tracker

- (instancetype)init {
    if (self = [super init]) {
        trackerCore = new TrackerCore();
    }
    return self;
}

- (void)dealloc {
    delete trackerCore;
}

#pragma mark - Base Tracker attributes

// TODO: Tracker class getters

- (NSString *)getViewId {
    return @"";
}

- (NSNumber *)getNumberOfVideos {
    return @0;
}

- (NSString *)getCoreVersion {
    return PRODUCT_VERSION_STR;
}

- (NSString *)getViewSession {
    return [NewRelicAgent currentSessionId];
}

- (NSNumber *)getNumberOfErrors {
    return @0;
}

#pragma mark - Public

- (TrackerState)state {
    return (TrackerState)trackerCore->state();
}

- (void)reset {
    trackerCore->reset();
}

- (void)setup {
    trackerCore->setup();
}

- (void)preSend {
    // TODO: presend does anything in TrackerCore??
    [self setOptionKey:@"timeSinceTrackerReady" value:@(self.trackerReadyTimestamp.sinceMillis)];
    [self setOptionKey:@"timeSinceLastRenditionChange" value:@(self.lastRenditionChangeTimestamp.sinceMillis) forAction:@"_RENDITION_CHANGE"];
}

- (void)sendRequest {
    trackerCore->sendRequest();
}

- (void)sendStart {
    trackerCore->sendStart();
}

- (void)sendEnd {
    trackerCore->sendEnd();
}

- (void)sendPause {
    trackerCore->sendPause();
}

- (void)sendResume {
    trackerCore->sendResume();
}

- (void)sendSeekStart {
    trackerCore->sendSeekStart();
}

- (void)sendSeekEnd {
    trackerCore->sendSeekEnd();
}

- (void)sendBufferStart {
    trackerCore->sendBufferStart();
}

- (void)sendBufferEnd {
    trackerCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    trackerCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    trackerCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    trackerCore->sendError(std::string([message UTF8String]));
}

- (void)sendPlayerReady {
    trackerCore->sendPlayerReady();
}

/*
 TODO:
 - Implement DOWNLOAD's "state" attribute. Argument to sendDownload method.
 */

- (void)sendDownload {
    trackerCore->sendDownload();
}

- (void)sendCustomAction:(NSString *)name {
    trackerCore->sendCustomAction(std::string([name UTF8String]));
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    trackerCore->sendCustomAction(std::string([name UTF8String]), fromDictionaryToMap(attr));
}

- (void)setOptions:(NSDictionary *)opts {
    trackerCore->setOptions(fromDictionaryToMap(opts));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    trackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value));
}

- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action {
    trackerCore->setOptions(fromDictionaryToMap(opts), std::string([action UTF8String]));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    trackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value), std::string([action UTF8String]));
}

#pragma mark - Attributes

- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSMutableDictionary<NSString *,NSValue *> *)attributeGetters {
    return NSNull.null;
}

#pragma mark - Timer stuff

- (void)startTimerEvent {
    // TODO
}

- (void)abortTimerEvent {
    // TODO
}

// To be overwritten
- (void)trackerTimeEvent {}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    // TODO
    if ([attr isEqualToString:@"timeSinceTrackerReady"]) {
        [self.trackerReadyTimestamp setExternal:timestamp];
    }
    else if ([attr isEqualToString:@"timeSinceLastRenditionChange"]) {
        [self.lastRenditionChangeTimestamp setExternal:timestamp];
    }
    else {
        return NO;
    }
    
    return YES;
}

@end
