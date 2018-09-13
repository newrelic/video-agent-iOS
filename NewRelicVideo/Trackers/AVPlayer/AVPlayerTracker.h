//
//  AVPlayerTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentsTracker.h"

@class AVPlayer;
@class AVPlayerViewController;

@interface AVPlayerTracker : ContentsTracker <ContentsTrackerProtocol>

- (instancetype)initWithAVPlayer:(AVPlayer *)player;
- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController;

- (void)setIsAutoplayed:(NSNumber *)state;

@end
