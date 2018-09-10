//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "AdsTracker.h"
#import "TrackerAutomat.h"
#import "EventDefs.h"

#define ACTION_FILTER @"CONTENT_"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@interface ContentsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@property (nonatomic) NSTimeInterval requestTimestamp;
@property (nonatomic) NSTimeInterval heartbeatTimestamp;
@property (nonatomic) NSTimeInterval totalPlaytime;
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;
@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval timeSinceStartedTimestamp;
@property (nonatomic) NSTimeInterval timeSincePausedTimestamp;
@property (nonatomic) NSTimeInterval timeSinceBufferBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceSeekBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceLastAdTimestamp;

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
    
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
    self.playtimeSinceLastEventTimestamp = 0;
    self.timeSinceStartedTimestamp = 0;
    self.timeSinceLastAdTimestamp = 0;
    
    [self updateContentsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateContentsAttributes];
    
    [self setContentsOptionKey:@"timeSinceRequested" value:@(1000.0f * TIMESINCE(self.requestTimestamp))];
    
    if (self.heartbeatTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.heartbeatTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * TIMESINCE(self.requestTimestamp))];
    }
    
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
    
    if (self.timeSinceStartedTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceStarted" value:@(1000.0f * TIMESINCE(self.timeSinceStartedTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceStarted" value:@0];
    }
    
    if (self.timeSincePausedTimestamp > 0) {
        [self setOptionKey:@"timeSincePaused" value:@(1000.0f * TIMESINCE(self.timeSincePausedTimestamp)) forAction:CONTENT_RESUME];
    }
    else {
        [self setOptionKey:@"timeSincePaused" value:@0 forAction:CONTENT_RESUME];
    }
    
    if (self.timeSinceBufferBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceBufferBegin" value:@(1000.0f * TIMESINCE(self.timeSinceBufferBeginTimestamp)) forAction:CONTENT_BUFFER_END];
    }
    else {
        [self setOptionKey:@"timeSinceBufferBegin" value:@0 forAction:CONTENT_BUFFER_END];
    }
    
    if (self.timeSinceSeekBeginTimestamp > 0) {
        [self setOptionKey:@"timeSinceSeekBegin" value:@(1000.0f * TIMESINCE(self.timeSinceSeekBeginTimestamp)) forAction:CONTENT_SEEK_END];
    }
    else {
        [self setOptionKey:@"timeSinceSeekBegin" value:@0 forAction:CONTENT_SEEK_END];
    }
    
    if (self.timeSinceLastAdTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastAd" value:@(1000.0f * TIMESINCE(self.timeSinceLastAdTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastAd" value:@0];
    }
    
    
}

- (void)sendRequest {
    self.requestTimestamp = TIMESTAMP;
    [super sendRequest];
}

- (void)sendStart {
    if (self.automat.state == TrackerStateStarting) {
        self.timeSinceStartedTimestamp = TIMESTAMP;
    }
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendStart];
}

- (void)sendEnd {
    [super sendEnd];
    self.totalPlaytime = 0;
    self.timeSinceLastAdTimestamp = 0;
}

- (void)sendPause {
    self.timeSincePausedTimestamp = TIMESTAMP;
    [super sendPause];
}

- (void)sendResume {
    self.totalPlaytimeTimestamp = TIMESTAMP;
    [super sendResume];
}

- (void)sendSeekStart {
    self.timeSinceSeekBeginTimestamp = TIMESTAMP;
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
    self.timeSinceBufferBeginTimestamp = TIMESTAMP;
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

- (void)sendError {
    [super sendError];
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
    self.timeSinceLastAdTimestamp = time;
}

@end
