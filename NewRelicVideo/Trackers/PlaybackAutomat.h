//
//  PlaybackAutomat.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 21/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, TrackerState) {
    TrackerStateStopped = 0,
    TrackerStateStarting,
    TrackerStatePlaying,
    TrackerStatePaused,
    TrackerStateBuffering,
    TrackerStateSeeking
};

@class BackendActions;

@interface PlaybackAutomat : NSObject

@property (nonatomic, readonly) TrackerState state;
@property (nonatomic, readonly) BackendActions *actions;
@property (nonatomic) BOOL isAd;

- (void)sendRequest;
- (void)sendStart;
- (void)sendEnd;
- (void)sendPause;
- (void)sendResume;
- (void)sendSeekStart;
- (void)sendSeekEnd;
- (void)sendBufferStart;
- (void)sendBufferEnd;
- (void)sendHeartbeat;
- (void)sendRenditionChange;
- (void)sendError:(NSString *)message;

@end
