//
//  AVPlayerViewControllerTracker.m
//  NewRelicVideo
//
//  Created by Andreu Santaren on 03/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerViewControllerTracker.h"

@import AVKit;

@interface AVPlayerViewControllerTracker ()

@property (nonatomic, weak) AVPlayerViewController *playerViewController;

@end

@implementation AVPlayerViewControllerTracker

- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController {
    if (self = [super initWithAVPlayer:playerViewController.player]) {
        self.playerViewController = playerViewController;
    }
    return self;
}

@end
