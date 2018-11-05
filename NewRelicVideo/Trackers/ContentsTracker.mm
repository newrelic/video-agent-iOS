//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "AdsTracker.h"
#import "PlaybackAutomat.h"
#import "EventDefs.h"
#import "Tracker_internal.h"
#import "TimestampValue.h"
#import "ContentsTrackerCore.hpp"
#import "DictionaryTrans.h"
#import "ValueHolder.hpp"
#import "GettersCAL.h"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
}

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@end

@implementation ContentsTracker

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        contentsTrackerCore = new ContentsTrackerCore();
        registerGetter(@"trackerName", self, @selector(getTrackerName));
        registerGetter(@"trackerVersion", self, @selector(getTrackerVersion));
        registerGetter(@"playerVersion", self, @selector(getPlayerVersion));
        registerGetter(@"playerName", self, @selector(getPlayerName));
        registerGetter(@"isAd", self, @selector(getIsAd));
    }
    return self;
}

- (void)dealloc {
    delete contentsTrackerCore;
}

- (TrackerState)state {
    return (TrackerState)contentsTrackerCore->state();
}

- (void)setup {
    contentsTrackerCore->setup();
}

- (void)reset {
    contentsTrackerCore->reset();
}

#pragma mark - Senders

- (void)preSend {
    contentsTrackerCore->preSend();
}

- (void)sendRequest {
    contentsTrackerCore->sendRequest();
}

- (void)sendStart {
    contentsTrackerCore->sendStart();
}

- (void)sendEnd {
    contentsTrackerCore->sendEnd();
}

- (void)sendPause {
    contentsTrackerCore->sendPause();
}

- (void)sendResume {
    contentsTrackerCore->sendResume();
}

- (void)sendSeekStart {
    contentsTrackerCore->sendSeekStart();
}

- (void)sendSeekEnd {
    contentsTrackerCore->sendSeekEnd();
}

- (void)sendBufferStart {
    contentsTrackerCore->sendBufferStart();
}

- (void)sendBufferEnd {
    contentsTrackerCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    contentsTrackerCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    contentsTrackerCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    contentsTrackerCore->sendError(std::string([message UTF8String]));
}

- (void)sendPlayerReady {
    contentsTrackerCore->sendPlayerReady();
}

- (void)sendDownload {
    contentsTrackerCore->sendDownload();
}

- (void)sendCustomAction:(NSString *)name {
    contentsTrackerCore->sendCustomAction(std::string([name UTF8String]));
}

- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr {
    contentsTrackerCore->sendCustomAction(std::string([name UTF8String]), fromDictionaryToMap(attr));
}

- (void)setOptions:(NSDictionary *)opts {
    contentsTrackerCore->setOptions(fromDictionaryToMap(opts));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value {
    contentsTrackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value));
}

- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action {
    contentsTrackerCore->setOptions(fromDictionaryToMap(opts), std::string([action UTF8String]));
}

- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action {
    contentsTrackerCore->setOption(std::string([key UTF8String]), fromNSValue((id)value), std::string([action UTF8String]));
}

#pragma mark - Getters

- (NSNumber *)getIsAd {
    return @NO;
}

- (NSString *)getPlayerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getPlayerVersion {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerName {
    OVERWRITE_STUB
    return nil;
}

- (NSString *)getTrackerVersion {
    OVERWRITE_STUB
    return nil;
}

#pragma mark - Time

- (void)startTimerEvent {
    contentsTrackerCore->startTimerEvent();
}

- (void)abortTimerEvent {
    contentsTrackerCore->abortTimerEvent();
}

// Timer event handler
- (void)trackerTimeEvent {
    contentsTrackerCore->trackerTimeEvent();
}

- (void)adHappened:(NSTimeInterval)time {
    contentsTrackerCore->adHappened(time);
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)contentsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
