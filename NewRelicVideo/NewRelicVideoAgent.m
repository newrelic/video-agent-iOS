//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "AVPlayerTracker.h"
#import "GCastTracker.h"
#import "ContentsTracker.h"
#import "AdsTracker.h"

#import <GoogleCast/GoogleCast.h>

@import AVKit;

@interface NewRelicVideoAgent ()

@property (nonatomic) ContentsTracker<ContentsTrackerProtocol> *tracker;
@property (nonatomic) AdsTracker<AdsTrackerProtocol> *adsTracker;

@end

@implementation NewRelicVideoAgent

+ (instancetype)sharedInstance {
    static NewRelicVideoAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NewRelicVideoAgent alloc] init];
    });
    return instance;
}

+ (void)startWithPlayer:(id)player {
    if ([player isKindOfClass:[AVPlayer class]]) {
        [self startWithTracker:[[AVPlayerTracker alloc] initWithAVPlayer:(AVPlayer *)player]];
        AV_LOG(@"Created AVPlayerTracker");
    }
    else if ([player isKindOfClass:[AVPlayerViewController class]]) {
        [self startWithTracker:[[AVPlayerTracker alloc] initWithAVPlayerViewController:(AVPlayerViewController *)player]];
        AV_LOG(@"Created AVPlayerViewControllerTracker");
    }
    else if ([player isKindOfClass:[GCKSessionManager class]]) {
        [self startWithTracker:[[GCastTracker alloc] initWithGoogleCast:(GCKSessionManager *)player]];
        AV_LOG(@"Created GCastTracker");
    }
    else  {
        [[self sharedInstance] setTracker:nil];
        NSLog(@"⚠️ Not recognized player class. ⚠️");
    }
}

+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker {
    [self startWithTracker:tracker andAds:nil];
}

+ (void)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker andAds:(AdsTracker<AdsTrackerProtocol> *)adsTracker {
    
    [[self sharedInstance] setTracker:tracker];
    
    if ([[self sharedInstance] tracker]) {
        AV_LOG(@"Tracker exist, initialize it");
        [[[self sharedInstance] tracker] reset];
        [[[self sharedInstance] tracker] setup];
    }
    else {
        AV_LOG(@"Tracker is nil!");
    }
    
    [[self sharedInstance] setAdsTracker:adsTracker];
    
    if ([[self sharedInstance] adsTracker]) {
        AV_LOG(@"Ads Tracker exist, initialize it");
        [[[self sharedInstance] adsTracker] reset];
        [[[self sharedInstance] adsTracker] setup];
    }
    else {
        AV_LOG(@"Ads Tracker is nil");
    }
}

+ (ContentsTracker<ContentsTrackerProtocol> *)trackerInstance {
    return [[self sharedInstance] tracker];
}

+ (AdsTracker<AdsTrackerProtocol> *)adsTrackerInstance {
    return [[self sharedInstance] adsTracker];
}

@end
