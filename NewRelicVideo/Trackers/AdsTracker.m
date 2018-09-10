//
//  AdsTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 10/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AdsTracker.h"
#import "TrackerAutomat.h"
#import "BackendActions.h"

@interface Tracker ()

@property (nonatomic) TrackerAutomat *automat;

@end

@implementation AdsTracker

#pragma mark - Init

- (void)reset {
    [super reset];
}

- (void)setup {
    [super setup];
}

#pragma mark - Senders

- (void)preSend {
    [super preSend];
}

- (void)sendRequest {
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
    [super sendHeartbeat];
}

- (void)sendRenditionChange {
    [super sendRenditionChange];
}

- (void)sendError {
    [super sendError];
}

// Ads specific senders

- (void)sendAdBreakStart {
    [self.automat.actions sendAdBreakStart];
}

- (void)sendAdBreakEnd {
    [self.automat.actions sendAdBreakEnd];
}

- (void)sendAdQuartile {
    [self.automat.actions sendAdQuartile];
}

- (void)sendAdClick {
    [self.automat.actions sendAdClick];
}

#pragma mark - Getters

- (NSNumber *)getIsAd {
    return @YES;
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

@end
