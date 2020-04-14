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

@property (nonatomic) NSMutableDictionary<NSNumber *, ContentsTracker<ContentsTrackerProtocol> *> *contentsTrackers;
@property (nonatomic) NSMutableDictionary<NSNumber *, AdsTracker<AdsTrackerProtocol> *> *adsTrackers;

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

+ (NSNumber *)startWithPlayer:(id)player usingBuilder:(Class<TrackerBuilder>)trackerBuilderClass {
    NSNumber *trackerId = [trackerBuilderClass startWithPlayer:player];
    if (trackerId == nil) {
        AV_LOG(@"⚠️ Not recognized player class. ⚠️");
    }
    return trackerId;
}

+ (NSNumber *)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker {
    return [self startWithTracker:tracker andAds:nil];
}

+ (NSNumber *)startWithTracker:(ContentsTracker<ContentsTrackerProtocol> *)tracker andAds:(AdsTracker<AdsTrackerProtocol> *)adsTracker {
    
    NSNumber *trackerId = nil;
    
    if (tracker != nil) {
        trackerId = @(tracker.hash);
    }
    else if (adsTracker != nil) {
        trackerId = @(adsTracker.hash);
    }
    else {
        return nil;
    }
    
    if (tracker != nil) {
        [[[self sharedInstance] contentsTrackers] setObject:tracker forKey:trackerId];
        AV_LOG(@"Contents Tracker exist, initialize it");
        [tracker reset];
        [tracker setup];
    }
    
    if (adsTracker != nil) {
        [[[self sharedInstance] adsTrackers] setObject:adsTracker forKey:trackerId];
        AV_LOG(@"Ads Tracker exist, initialize it");
        [adsTracker reset];
        [adsTracker setup];
    }

    return trackerId;
}

+ (ContentsTracker<ContentsTrackerProtocol> *)getContentsTracker:(NSNumber *)trackerId {
    return [[[self sharedInstance] contentsTrackers] objectForKey:trackerId];
}

+ (AdsTracker<AdsTrackerProtocol> *)getAdsTracker:(NSNumber *)trackerId {
    return [[[self sharedInstance] adsTrackers] objectForKey:trackerId];
}

+ (void)unregisterTracker:(NSNumber *)trackerId {
    ContentsTracker *ct = [[[self sharedInstance] contentsTrackers] objectForKey:trackerId];
    AdsTracker *at = [[[self sharedInstance] adsTrackers] objectForKey:trackerId];
    if (ct) {
        [ct reset];
        [ct disableHeartbeat];
    }
    if (at) {
        [at reset];
        [at disableHeartbeat];
    }
    [[[self sharedInstance] contentsTrackers] removeObjectForKey:trackerId];
    [[[self sharedInstance] adsTrackers] removeObjectForKey:trackerId];
}

- (instancetype)init {
    if (self = [super init]) {
        self.contentsTrackers = @{}.mutableCopy;
        self.adsTrackers = @{}.mutableCopy;
    }
    return self;
}

@end
