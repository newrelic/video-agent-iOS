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

//#define ACTION_FILTER @"CONTENT_"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
}

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@end

@implementation ContentsTracker

// TODO:

//- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
//    if (!_contentsAttributeGetters) {
//        _contentsAttributeGetters = @{
//                                      @"contentId": [NSValue valueWithPointer:@selector(getVideoId)],
//                                      @"contentTitle": [NSValue valueWithPointer:@selector(getTitle)],
//                                      @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
//                                      @"contentRenditionName": [NSValue valueWithPointer:@selector(getRenditionName)],
//                                      @"contentRenditionBitrate": [NSValue valueWithPointer:@selector(getRenditionBitrate)],
//                                      @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
//                                      @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
//                                      @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
//                                      @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
//                                      @"contentLanguage": [NSValue valueWithPointer:@selector(getLanguage)],
//                                      @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
//                                      @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMuted)],
//                                      @"contentCdn": [NSValue valueWithPointer:@selector(getCdn)],
//                                      @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
//                                      @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
//                                      @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
//                                      @"contentIsAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
//                                      @"contentPreload": [NSValue valueWithPointer:@selector(getPreload)],
//                                      @"contentIsFullscreen": [NSValue valueWithPointer:@selector(getIsFullscreen)],
//                                      }.mutableCopy;
//    }
//    return _contentsAttributeGetters;
//}
//
//- (void)updateContentsAttributes {
//    for (NSString *key in self.contentsAttributeGetters) {
//        [self updateContentsAttribute:key];
//    }
//}
//
//- (void)updateContentsAttribute:(NSString *)attr {
//    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.contentsAttributeGetters];
//    if (val) [self setOptionKey:attr value:val forAction:ACTION_FILTER];
//}

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        contentsTrackerCore = new ContentsTrackerCore();
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
    // TODO
//    [self updateContentsAttributes];
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

// TODO: the protocol getters are never called because we need to manually register callbacks

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
