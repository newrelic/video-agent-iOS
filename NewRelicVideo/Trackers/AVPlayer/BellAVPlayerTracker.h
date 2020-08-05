//
//  BellAVPlayerTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/08/2020.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import <NewRelicVideo/NewRelicVideo.h>

@class AVPlayer;
@class AVPlayerViewController;

@interface BellAVPlayerTracker : ContentsTracker <ContentsTrackerProtocol>

- (instancetype)initWithAVPlayer:(AVPlayer *)player;
- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController;

@end
