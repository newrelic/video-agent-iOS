//
//  NewRelicVideoAgent.m
//  NextVideoAgent
//
//  Created by Andreu Santaren on 11/12/2020.
//

#import "NewRelicVideoAgent.h"
#import "NRTrackerPair.h"
#import "NRTracker.h"
#import "NRVideoTracker.h"

@interface NewRelicVideoAgent ()

@property (nonatomic) NSMutableDictionary<NSNumber *, NRTrackerPair *> *trackerPairs;
@property (nonatomic) int trackerIdIndex;
@property (nonatomic) BOOL isLogging;
@property (nonatomic) NSString *uuid;

@end

@implementation NewRelicVideoAgent

+ (instancetype)sharedInstance {
    static NewRelicVideoAgent *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NewRelicVideoAgent alloc] init];
        instance.isLogging = NO;
        instance.trackerIdIndex = 0;
        instance.trackerPairs = @{}.mutableCopy;
        instance.uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    });
    return instance;
}

- (NSString *)sessionId {
    return self.uuid;
}

- (void)setLogging:(BOOL)state {
    [self setIsLogging:state];
}

- (BOOL)logging {
    return self.isLogging;
}

- (NSNumber *)startWithContentTracker:(NRTracker *)contentTracker {
    return [self startWithContentTracker:contentTracker adTracker:nil];
}

- (NSNumber *)startWithContentTracker:(nullable NRTracker *)contentTracker adTracker:(nullable NRTracker *)adTracker {
    NRTrackerPair *pair = [[NRTrackerPair alloc] initWithFirst:contentTracker second:adTracker];
    NSNumber *trackerId = @(self.trackerIdIndex++);
    [self.trackerPairs setObject:pair forKey:trackerId];
    
    if ([adTracker isKindOfClass:[NRVideoTracker class]]) {
        [[(NRVideoTracker *)adTracker state] setIsAd:YES];
    }
    
    if (contentTracker && adTracker) {
        [contentTracker setLinkedTracker:adTracker];
        [adTracker setLinkedTracker:contentTracker];
    }
    
    if (contentTracker) {
        [contentTracker trackerReady];
    }
    
    if (adTracker) {
        [adTracker trackerReady];
    }
    
    return trackerId;
}

- (void)releaseTracker:(NSNumber *)trackerId {
    if ([self contentTracker:trackerId]) {
        [[self contentTracker:trackerId] dispose];
    }
    if ([self adTracker:trackerId]) {
        [[self adTracker:trackerId] dispose];
    }
    [self.trackerPairs removeObjectForKey:trackerId];
}

- (nullable NRTracker *)contentTracker:(NSNumber *)trackerId {
    NRTrackerPair *pair = [self.trackerPairs objectForKey:trackerId];
    if ([[pair first] isEqual:[NSNull null]]) {
        return nil;
    }
    else {
        return [pair first];
    }
}

- (nullable NRTracker *)adTracker:(NSNumber *)trackerId {
    NRTrackerPair *pair = [self.trackerPairs objectForKey:trackerId];
    if ([[pair second] isEqual:[NSNull null]]) {
        return nil;
    }
    else {
        return [pair second];
    }
}

- (void)setUserId:(NSString *)userId {
    for (NSNumber *trackerId in self.trackerPairs) {
        NRTrackerPair *pair = self.trackerPairs[trackerId];
        if (pair.first) {
            [pair.first setAttribute:@"enduser.id" value:userId];
        }
        if (pair.second) {
            [pair.second setAttribute:@"enduser.id" value:userId];
        }
    }
}

@end
