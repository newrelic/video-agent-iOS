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

#define ACTION_FILTER @"CONTENT_"

@interface ContentsTracker ()
{
    ContentsTrackerCore *contentsTrackerCore;
}

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@end

@implementation ContentsTracker

- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
    if (!_contentsAttributeGetters) {
        _contentsAttributeGetters = @{
                                      @"contentId": [NSValue valueWithPointer:@selector(getVideoId)],
                                      @"contentTitle": [NSValue valueWithPointer:@selector(getTitle)],
                                      @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                                      @"contentRenditionName": [NSValue valueWithPointer:@selector(getRenditionName)],
                                      @"contentRenditionBitrate": [NSValue valueWithPointer:@selector(getRenditionBitrate)],
                                      @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                                      @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                                      @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
                                      @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                                      @"contentLanguage": [NSValue valueWithPointer:@selector(getLanguage)],
                                      @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
                                      @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMuted)],
                                      @"contentCdn": [NSValue valueWithPointer:@selector(getCdn)],
                                      @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
                                      @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
                                      @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
                                      @"contentIsAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
                                      @"contentPreload": [NSValue valueWithPointer:@selector(getPreload)],
                                      @"contentIsFullscreen": [NSValue valueWithPointer:@selector(getIsFullscreen)],
                                      }.mutableCopy;
    }
    return _contentsAttributeGetters;
}

- (void)updateContentsAttributes {
    for (NSString *key in self.contentsAttributeGetters) {
        [self updateContentsAttribute:key];
    }
}

- (void)updateContentsAttribute:(NSString *)attr {
    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.contentsAttributeGetters];
    if (val) [self setOptionKey:attr value:val forAction:ACTION_FILTER];
}

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

- (void)reset {
    contentsTrackerCore->reset();
}

#pragma mark - Senders

- (void)preSend {
    contentsTrackerCore->preSend();
    [self updateContentsAttributes];
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

- (void)sendBufferStart {
    contentsTrackerCore->sendBufferStart();
}

- (void)sendHeartbeat {
    contentsTrackerCore->sendHeartbeat();
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
