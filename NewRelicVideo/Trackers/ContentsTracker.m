//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "TrackerAutomat.h"

#define ACTION_FILTER @"CONTENT_"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@interface ContentsTracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *contentsAttributeGetters;

@property (nonatomic) NSTimeInterval requestTimestamp;
@property (nonatomic) NSTimeInterval trackerReadyTimestamp;
@property (nonatomic) NSTimeInterval heartbeatTimestamp;
// TODO: implement timestamps
@property (nonatomic) NSTimeInterval totalPlaytime;
@property (nonatomic) NSTimeInterval totalPlaytimeTimestamp;

@property (nonatomic) NSTimeInterval playtimeSinceLastEventTimestamp;
@property (nonatomic) NSTimeInterval timeSinceStartedTimestamp;
@property (nonatomic) NSTimeInterval timeSincePausedTimestamp;
@property (nonatomic) NSTimeInterval timeSinceBufferBeginTimestamp;
@property (nonatomic) NSTimeInterval timeSinceSeekBeginTimestamp;

@end

@implementation ContentsTracker

- (NSMutableDictionary<NSString *,NSValue *> *)contentsAttributeGetters {
    if (!_contentsAttributeGetters) {
        _contentsAttributeGetters = @{
                                      @"contentId": [NSValue valueWithPointer:@selector(getVideoId)],
                                      @"contentBitrate": [NSValue valueWithPointer:@selector(getBitrate)],
                                      @"contentRenditionWidth": [NSValue valueWithPointer:@selector(getRenditionWidth)],
                                      @"contentRenditionHeight": [NSValue valueWithPointer:@selector(getRenditionHeight)],
                                      @"contentDuration": [NSValue valueWithPointer:@selector(getDuration)],
                                      @"contentPlayhead": [NSValue valueWithPointer:@selector(getPlayhead)],
                                      @"contentSrc": [NSValue valueWithPointer:@selector(getSrc)],
                                      @"contentPlayrate": [NSValue valueWithPointer:@selector(getPlayrate)],
                                      @"contentFps": [NSValue valueWithPointer:@selector(getFps)],
                                      @"contentIsLive": [NSValue valueWithPointer:@selector(getIsLive)],
                                      @"contentIsMuted": [NSValue valueWithPointer:@selector(getIsMutted)],
                                      @"contentIsAutoplayed": [NSValue valueWithPointer:@selector(getIsAutoplayed)],
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

- (instancetype)init {
    if (self = [super init]) {
        self.trackerReadyTimestamp = TIMESTAMP;
    }
    return self;
}

- (void)reset {
    [super reset];
    
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
    [self updateContentsAttributes];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self updateContentsAttributes];
    
    [self setContentsOptionKey:@"timeSinceTrackerReady" value:@(1000.0f * (TIMESTAMP - self.trackerReadyTimestamp))];
    [self setContentsOptionKey:@"timeSinceRequested" value:@(1000.0f * (TIMESTAMP - self.requestTimestamp))];
    
    if (self.heartbeatTimestamp > 0) {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (TIMESTAMP - self.heartbeatTimestamp))];
    }
    else {
        [self setContentsOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (TIMESTAMP - self.requestTimestamp))];
    }
    
    if (self.automat.state == TrackerStatePlaying) {
        
        self.totalPlaytimeTimestamp = TIMESTAMP;
    }
    [self setContentsOptionKey:@"totalPlaytime" value:@(1000.0f * self.totalPlaytime)];
}

- (void)sendRequest {
    self.requestTimestamp = TIMESTAMP;
    [super sendRequest];
}

- (void)sendStart {
    [super sendStart];
}

- (void)sendEnd {
    [super sendEnd];
}

- (void)sendPause {
    [super sendPause];
}

- (void)sendResume {
    [super sendResume];
}

- (void)sendSeekStart {
    [super sendSeekStart];
}

- (void)sendSeekEnd {
    [super sendSeekEnd];
}

- (void)sendBufferStart {
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

#pragma mark - Timer

- (void)trackerTimeEvent {
    // TODO: bitrate stuff
}

@end
