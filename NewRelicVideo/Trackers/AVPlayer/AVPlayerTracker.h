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

/**
 `AVPlayerTracker` is the base class to manage the content events of an AVPlayer. It can be used directly or subclassed.
 */

@interface AVPlayerTracker : ContentsTracker <ContentsTrackerProtocol>

- (instancetype)initWithAVPlayer:(AVPlayer *)player;
- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController;

- (void)setIsAutoplayed:(NSNumber *)state;

@end
