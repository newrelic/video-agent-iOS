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

#define ACTION_FILTER @"CONTENT_"

@interface ContentsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@property (nonatomic) NSTimeInterval requestTimestamp;
@property (nonatomic) NSTimeInterval heartbeatTimestamp;
@property (nonatomic) NSTimeInterval totalPlaytime;
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval startedTimestamp;
@property (nonatomic) NSTimeInterval pausedTimestamp;
@property (nonatomic) NSTimeInterval bufferBeginTimestamp;
@property (nonatomic) NSTimeInterval seekBeginTimestamp;
@property (nonatomic) NSTimeInterval lastAdTimestamp;

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

- (void)setContentsOptionKey:(NSString *)key value:(id<NSCopying>)value {
    [self setOptionKey:key value:value forAction:ACTION_FILTER];
}

- (void)updateContentsAttribute:(NSString *)attr {
    id<NSCopying> val = [self optionValueFor:attr fromGetters:self.contentsAttributeGetters];
    if (val) [self setOptionKey:attr value:val forAction:ACTION_FILTER];
}

- (void)setContentsTimeKey:(NSString *)key timestamp:(NSTimeInterval)timestamp {
    [self setContentsTimeKey:key timestamp:timestamp filter:ACTION_FILTER];
}

- (void)setContentsTimeKey:(NSString *)key timestamp:(NSTimeInterval)timestamp filter:(NSString *)filter {
    if (timestamp > 0) {
        [self setOptionKey:key value:@(1000.0f * TIMESINCE(timestamp)) forAction:filter];
    }
    else {
        [self setOptionKey:key value:@0 forAction:filter];
    }
}

#pragma mark - Init

- (void)reset {
    [super reset];
    
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
    self.playtimeSinceLastEventTimestamp = 0;
    self.startedTimestamp = 0;
    self.lastAdTimestamp = 0;
    
    [self updateContentsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

// TODO: all those timestamps are CONTENT_ specific? because we are registering them as general!!!

- (void)preSend {
    [super preSend];
    
    [self updateContentsAttributes];
    
    // Special time calculations, accumulative timestamps
    
    if (self.automat.state == TrackerStatePlaying) {
        self.totalPlaytime += TIMESINCE(self.totalPlaytimeTimestamp);
        self.totalPlaytimeTimestamp = TIMESTAMP;
    }
    [self setContentsOptionKey:@"totalPlaytime" value:@(1000.0f * self.totalPlaytime)];
    
    if (self.playtimeSinceLastEventTimestamp == 0) {
        self.playtimeSinceLastEventTimestamp = TIMESTAMP;
    }
    [self setContentsOptionKey:@"playtimeSinceLastEvent" value:@(1000.0f * TIMESINCE(self.playtimeSinceLastEventTimestamp))];
    self.playtimeSinceLastEventTimestamp = TIMESTAMP;
    
    // Regular offset timestamps, time since
    
    if (self.heartbeatTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.heartbeatTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.requestTimestamp))];
    }
    
    [self setContentsTimeKey:@"timeSinceRequested" timestamp:self.requestTimestamp];
    [self setContentsTimeKey:@"timeSinceStarted" timestamp:self.startedTimestamp];
    [self setContentsTimeKey:@"timeSincePaused" timestamp:self.pausedTimestamp filter:CONTENT_RESUME];
    [self setContentsTimeKey:@"timeSinceBufferBegin" timestamp:self.bufferBeginTimestamp filter:CONTENT_BUFFER_END];
    [self setContentsTimeKey:@"timeSinceSeekBegin" timestamp:self.seekBeginTimestamp filter:CONTENT_SEEK_END];
    [self setContentsTimeKey:@"timeSinceLastAd" timestamp:self.lastAdTimestamp];
}

- (void)sendRequest {
    self.requestTimestamp = TIMESTAMP;
    [super sendRequest];
}

- (void)sendStart {
    if (self.automat.state == TrackerStateStarting) {
        self.startedTimestamp = TIMESTAMP;
    }
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendStart];
}

- (void)sendEnd {
    [super sendEnd];
    self.totalPlaytime = 0;
    self.lastAdTimestamp = 0;
}

- (void)sendPause {
    self.pausedTimestamp = TIMESTAMP;
    [super sendPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendResume];
}

- (void)sendSeekStart {
    self.seekBeginTimestamp = TIMESTAMP;
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    self.bufferBeginTimestamp = TIMESTAMP;
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    self.heartbeatTimestamp = TIMESTAMP;
    [super sendHeartbeat];
}

- (void)sendRenditionChange {
    [super sendRenditionChange];
}

- (void)sendError:(NSString *)message {
    [super sendError:message];
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
    [super trackerTimeEvent];
}

- (void)adHappened:(NSTimeInterval)time {
    self.lastAdTimestamp = time;
}

@end
