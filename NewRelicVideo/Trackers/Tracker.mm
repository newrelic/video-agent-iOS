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

@end

@implementation Tracker

- (NSDictionary<NSString *, NSValue *> *)attributeGetters {
    return @{
             // Base Tracker
             @"viewId": [NSValue valueWithPointer:@selector(getViewId)],
             @"numberOfVideos": [NSValue valueWithPointer:@selector(getNumberOfVideos)],
             @"coreVersion": [NSValue valueWithPointer:@selector(getCoreVersion)],
             @"viewSession": [NSValue valueWithPointer:@selector(getViewSession)],
             @"numberOfErrors": [NSValue valueWithPointer:@selector(getNumberOfErrors)],
             // Implemented by tracker subclass, required
             @"trackerName": [NSValue valueWithPointer:@selector(getTrackerName)],
             @"trackerVersion": [NSValue valueWithPointer:@selector(getTrackerVersion)],
             @"playerVersion": [NSValue valueWithPointer:@selector(getPlayerVersion)],
             @"playerName": [NSValue valueWithPointer:@selector(getPlayerName)],
             @"isAd": [NSValue valueWithPointer:@selector(getIsAd)],
             };
}

- (void)updateAttributes {
    for (NSString *key in self.attributeGetters) {
        
        id value = (id)[self optionValueFor:key fromGetters:self.attributeGetters];
        
        if (value) {
            trackerCore->updateAttribute(std::string([key UTF8String]),
                                         fromNSValue(value));
        }
    }
}

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

- (NSString *)getViewId {
    return [NSString stringWithUTF8String:trackerCore->getViewId().c_str()];
}

- (NSNumber *)getNumberOfVideos {
    return @(trackerCore->getNumberOfVideos());
}

- (NSString *)getCoreVersion {
    return [NSString stringWithUTF8String:trackerCore->getCoreVersion().c_str()];
}

- (NSString *)getViewSession {
    return [NSString stringWithUTF8String:trackerCore->getViewSession().c_str()];
}

- (NSNumber *)getNumberOfErrors {
    return @(trackerCore->getNumberOfErrors());
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
//    trackerCore->preSend();
    [self updateAttributes];
}

- (void)sendRequest {
    [self preSend];
    trackerCore->sendRequest();
}

- (void)sendStart {
    [self preSend];
    trackerCore->sendStart();
}

- (void)sendEnd {
    [self preSend];
    trackerCore->sendEnd();
}

- (void)sendPause {
    [self preSend];
    trackerCore->sendPause();
}

- (void)sendResume {
    [self preSend];
    trackerCore->sendResume();
}

- (void)sendSeekStart {
    [self preSend];
    trackerCore->sendSeekStart();
}

- (void)sendSeekEnd {
    [self preSend];
    trackerCore->sendSeekEnd();
}

- (void)sendBufferStart {
    [self preSend];
    trackerCore->sendBufferStart();
}

- (void)sendBufferEnd {
    [self preSend];
    trackerCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    [self preSend];
    trackerCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    [self preSend];
    trackerCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    [self preSend];
    trackerCore->sendError(std::string([message UTF8String]));
}

- (void)sendPlayerReady {
    [self preSend];
    trackerCore->sendPlayerReady();
}

- (void)sendDownload {
    [self preSend];
    trackerCore->sendDownload();
}

- (void)sendCustomAction:(NSString *)name {
    [self preSend];
    trackerCore->sendCustomAction(std::string([name UTF8String]));
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    [self preSend];
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

- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSDictionary<NSString *,NSValue *> *)attributeGetters {
    NSValue *value = attributeGetters[attr];
    SEL selector = (SEL)[value pointerValue];
    
    if ([self respondsToSelector:selector]) {
        IMP imp = [self methodForSelector:selector];
        id<NSCopying> (*func)(id, SEL) = (id<NSCopying> (*)(id, SEL))imp;
        return func(self, selector);
    }
    else {
        return NSNull.null;
    }
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
    return (BOOL)trackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
