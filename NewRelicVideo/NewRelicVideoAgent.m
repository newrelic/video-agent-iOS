//
//  NewRelicVideoAgent.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 22/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "NewRelicVideoAgent.h"
#import "ContentsTracker.h"
#import "AdsTracker.h"
#import "TrackerBuilder.h"
#import "NewRelicAgentCAL.h"

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
        [[NewRelicAgentCAL sharedInstance] generateUUID];
    });
    return instance;
}

/*
 TODO:
 - Prepare the agent for mutliple trackers.
 */

+ (void)startWithPlayer:(id)player usingBuilder:(Class<TrackerBuilder>)trackerBuilderClass {
    if (![trackerBuilderClass startWithPlayer:player]) {
        [[self sharedInstance] setTracker:nil];
        NSLog(@"⚠️ Not recognized player class. ⚠️");
    }
}

+ (void)startWithPlayer:(id)player {
    NSLog(@"⚠️ WARNING: startWithPlayer: is DEPRECATED, use startWithPlayer:usingBuilder: instead ⚠️");
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
