//
//  ContentsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "ContentsTracker.h"

@interface Tracker ()

@property (nonatomic) NSMutableDictionary<NSString *, NSValue *> *attributeGetters;

@end

@interface ContentsTracker ()

@end

@implementation ContentsTracker

#pragma mark - Init

- (instancetype)init {
    if (self = [super init]) {
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

- (void)timeEvent {
    // TODO: bitrate stuff
}

@end