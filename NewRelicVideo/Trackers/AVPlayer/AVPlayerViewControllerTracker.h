//
//  AVPlayerViewControllerTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 03/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "AVPlayerTracker.h"

@class AVPlayerViewController;

@interface AVPlayerViewControllerTracker : AVPlayerTracker

- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController;

@end
