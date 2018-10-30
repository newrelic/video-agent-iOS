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

#define ACTION_FILTER @"CONTENT_"

@interface ContentsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

// Time Counts
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval totalPlaytime;

// Time Since
@property (nonatomic) TimestampValue *requestTimestamp;
@property (nonatomic) TimestampValue *heartbeatTimestamp;
@property (nonatomic) TimestampValue *startedTimestamp;
@property (nonatomic) TimestampValue *pausedTimestamp;
@property (nonatomic) TimestampValue *bufferBeginTimestamp;
@property (nonatomic) TimestampValue *seekBeginTimestamp;
@property (nonatomic) TimestampValue *lastAdTimestamp;

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

#pragma mark - Init

- (void)reset {
    [super reset];
    
    self.totalPlaytime = 0;
    self.playtimeSinceLastEventTimestamp = 0;
    self.totalPlaytimeTimestamp = 0;
    
    self.requestTimestamp = [TimestampValue build:0];
    self.heartbeatTimestamp = [TimestampValue build:0];
    self.startedTimestamp = [TimestampValue build:0];
    self.pausedTimestamp = [TimestampValue build:0];
    self.bufferBeginTimestamp = [TimestampValue build:0];
    self.seekBeginTimestamp = [TimestampValue build:0];
    self.lastAdTimestamp = [TimestampValue build:0];
    
    [self updateContentsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateContentsAttributes];
    
    // Special time calculations, accumulative timestamps
    
    if (self.state == TrackerStatePlaying) {
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
    
    // BUG: heartbeatTimestamp is an object!!!
    if (self.heartbeatTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(self.heartbeatTimestamp.sinceMillis)];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(self.requestTimestamp.sinceMillis)];
    }
    
    [self setOptionKey:@"timeSinceRequested" value:@(self.requestTimestamp.sinceMillis)];
    [self setOptionKey:@"timeSinceStarted" value:@(self.startedTimestamp.sinceMillis)];
    [self setOptionKey:@"timeSincePaused" value:@(self.pausedTimestamp.sinceMillis) forAction:CONTENT_RESUME];
    [self setOptionKey:@"timeSinceBufferBegin" value:@(self.bufferBeginTimestamp.sinceMillis) forAction:CONTENT_BUFFER_END];
    [self setOptionKey:@"timeSinceSeekBegin" value:@(self.seekBeginTimestamp.sinceMillis) forAction:CONTENT_SEEK_END];
    [self setOptionKey:@"timeSinceLastAd" value:@(self.lastAdTimestamp.sinceMillis)];
}

- (void)sendRequest {
    [self.requestTimestamp setMain:TIMESTAMP];
    [super sendRequest];
}

- (void)sendStart {
    if (self.state == TrackerStateStarting) {
        [self.startedTimestamp setMain:TIMESTAMP];
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
    [self.pausedTimestamp setMain:TIMESTAMP];
    [super sendPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendResume];
}

- (void)sendSeekStart {
    [self.seekBeginTimestamp setMain:TIMESTAMP];
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    [self.bufferBeginTimestamp setMain:TIMESTAMP];
    [super sendBufferStart];
}

- (void)sendBufferEnd {
    [super sendBufferEnd];
}

- (void)sendHeartbeat {
    [self.heartbeatTimestamp setMain:TIMESTAMP];
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
    [self.lastAdTimestamp setMain:time];
}

- (BOOL)setTimestamp:(NSTimeInterval)timestamp attributeName:(NSString *)attr {
    if (![super setTimestamp:timestamp attributeName:attr]) {
        if ([attr isEqualToString:@"timeSinceRequested"]) {
            [self.requestTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceStarted"]) {
            [self.startedTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSincePaused"]) {
            [self.pausedTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceBufferBegin"]) {
            [self.bufferBeginTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceSeekBegin"]) {
            [self.seekBeginTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceLastAd"]) {
            [self.lastAdTimestamp setExternal:timestamp];
        }
        else if ([attr isEqualToString:@"timeSinceLastHeartbeat"]) {
            [self.heartbeatTimestamp setExternal:timestamp];
        }
        else {
            return NO;
        }
    }

    return YES;
}

@end
