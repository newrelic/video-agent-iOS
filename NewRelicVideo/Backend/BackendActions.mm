//
//  BackendActions.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 23/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <NewRelicAgent/NewRelic.h>
#import "BackendActions.h"
#import "BackendActionsCore.hpp"
#import "EventDefs.h"
#import "ValueHolder.hpp"
#import "DictionaryTrans.h"

@interface BackendActions ()
{
    BackendActionsCore *backendActionsCore;
}
@end

@implementation BackendActions

- (void)setGeneralOptions:(NSDictionary *)dict {
    backendActionsCore->generalOptions = fromDictionaryToMap(dict);
}

- (void)setGeneralOptionsValue:(id<NSCopying>)val key:(NSString *)key {
    backendActionsCore->generalOptions[std::string([key UTF8String])] = fromNSValue(val);
}

- (id<NSCopying>)getGeneralOptionsKey:(NSString *)key {
    return fromValueHolder(backendActionsCore->generalOptions[std::string([key UTF8String])]);
}

- (NSMutableDictionary<NSString *, NSMutableDictionary *> *)actionOptions {
    if (!_actionOptions) {
        _actionOptions = @{}.mutableCopy;
    }
    return _actionOptions;
}

// TODO: set dictionaries, convert to map and set in BackendActionsCore
/*
- (void)setActionOptions:(NSMutableDictionary<NSString *,NSMutableDictionary *> *)actionOptions {
}
 */

- (instancetype)init {
    if (self = [super init]) {
        backendActionsCore = new BackendActionsCore();
    }
    return self;
}

- (void)dealloc {
    delete backendActionsCore;
}

#pragma mark - Tracker Content Events

- (void)sendRequest {
    backendActionsCore->sendRequest();
}

- (void)sendStart {
    backendActionsCore->sendStart();
}

- (void)sendEnd {
    backendActionsCore->sendEnd();
}

- (void)sendPause {
    backendActionsCore->sendPause();
}

- (void)sendResume {
    backendActionsCore->sendResume();
}

- (void)sendSeekStart {
    backendActionsCore->sendSeekStart();
}

- (void)sendSeekEnd {
    backendActionsCore->sendSeekEnd();
}

- (void)sendBufferStart {
    backendActionsCore->sendBufferStart();
}

- (void)sendBufferEnd {
    backendActionsCore->sendBufferEnd();
}

- (void)sendHeartbeat {
    backendActionsCore->sendHeartbeat();
}

- (void)sendRenditionChange {
    backendActionsCore->sendRenditionChange();
}

- (void)sendError:(NSString *)message {
    backendActionsCore->sendError(std::string([message UTF8String]));
}

#pragma mark - Tracker Ad Events

- (void)sendAdRequest {
    backendActionsCore->sendAdRequest();
}

- (void)sendAdStart {
    backendActionsCore->sendAdStart();
}

- (void)sendAdEnd {
    backendActionsCore->sendAdEnd();
}

- (void)sendAdPause {
    backendActionsCore->sendAdPause();
}

- (void)sendAdResume {
    backendActionsCore->sendAdResume();
}

- (void)sendAdSeekStart {
    backendActionsCore->sendAdSeekStart();
}

- (void)sendAdSeekEnd {
    backendActionsCore->sendAdSeekEnd();
}

- (void)sendAdBufferStart {
    backendActionsCore->sendAdBufferStart();
}

- (void)sendAdBufferEnd {
    backendActionsCore->sendAdBufferEnd();
}

- (void)sendAdHeartbeat {
    backendActionsCore->sendAdHeartbeat();
}

- (void)sendAdRenditionChange {
    backendActionsCore->sendAdRenditionChange();
}

- (void)sendAdError:(NSString *)message {
    backendActionsCore->sendAdError(std::string([message UTF8String]));
}

- (void)sendAdBreakStart {
    backendActionsCore->sendAdBreakStart();
}

- (void)sendAdBreakEnd {
    backendActionsCore->sendAdBreakEnd();
}

- (void)sendAdQuartile {
    backendActionsCore->sendAdQuartile();
}

- (void)sendAdClick {
    backendActionsCore->sendAdClick();
}

#pragma mark - Optional Events

- (void)sendPlayerReady {
    backendActionsCore->sendPlayerReady();
}

- (void)sendDownload {
    backendActionsCore->sendDownload();
}

#pragma mark - SendAction

- (void)sendAction:(NSString *)name {
    backendActionsCore->sendAction(std::string([name UTF8String]), {});
}

- (void)sendAction:(NSString *)name attr:(NSDictionary *)dict {
    std::map<std::string, ValueHolder> result = fromDictionaryToMap(dict);
    backendActionsCore->sendAction(std::string([name UTF8String]), result);
}

@end
