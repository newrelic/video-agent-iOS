//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"
#import "TrackerAutomat.h"

@interface Tracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *attributeGetters;
@property (nonatomic) TrackerAutomat *automat;

@end

@interface ContentsTracker ()

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

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
        self.trackerReadyTimestamp = self.timestamp;
        [self setupAttributeGetters];
    }
    return self;
}

- (void)setupAttributeGetters {
    [self.attributeGetters addEntriesFromDictionary:@{
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
                                                      }];
}

- (void)reset {
    [super reset];
    
    self.requestTimestamp = 0;
    self.heartbeatTimestamp = 0;
    self.totalPlaytime = 0;
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
    
    [self setOptionKey:@"timeSinceTrackerReady" value:@(1000.0f * (self.timestamp - self.trackerReadyTimestamp))];
    [self setOptionKey:@"timeSinceRequested" value:@(1000.0f * (self.timestamp - self.requestTimestamp))];
    
    if (self.heartbeatTimestamp > 0) {
        [self setOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (self.timestamp - self.heartbeatTimestamp))];
    }
    else {
        [self setOptionKey:@"timeSinceLastHeartbeat" value:@(1000.0f * (self.timestamp - self.requestTimestamp))];
    }
    
    if (self.automat.state == TrackerStatePlaying) {
        
        self.totalPlaytimeTimestamp = self.timestamp;
    }
    [self setOptionKey:@"totalPlaytime" value:@(1000.0f * self.totalPlaytime)];
}

- (void)sendRequest {
    self.requestTimestamp = self.timestamp;
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
    self.heartbeatTimestamp = self.timestamp;
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

- (void)timeEvent {
    // TODO: bitrate stuff
}

@end
