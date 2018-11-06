//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "ContentsTrackerCore.hpp"
#import "DictionaryTrans.h"
#import "ValueHolder.hpp"
#import "GettersCAL.h"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
}
@end

@implementation ContentsTracker

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        contentsTrackerCore = new ContentsTrackerCore();
        [GettersCAL registerGetter:@"trackerName" target:self sel:@selector(getTrackerName)];
        [GettersCAL registerGetter:@"trackerVersion" target:self sel:@selector(getTrackerVersion)];
        [GettersCAL registerGetter:@"playerVersion" target:self sel:@selector(getPlayerVersion)];
        [GettersCAL registerGetter:@"playerName" target:self sel:@selector(getPlayerName)];
        [GettersCAL registerGetter:@"isAd" target:self sel:@selector(getIsAd)];
    }
    return self;
}

- (void)dealloc {
    delete contentsTrackerCore;
}

- (TrackerState)state {
    return (TrackerState)contentsTrackerCore->state();
}

- (void)reset {
    contentsTrackerCore->reset();
}

- (void)setup {
    contentsTrackerCore->setup();
}

#pragma mark - Senders

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

- (void)trackerTimeEvent {
    contentsTrackerCore->trackerTimeEvent();
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    return (BOOL)contentsTrackerCore->setTimestamp((double)timestamp, std::string([attr UTF8String]));
}

@end
