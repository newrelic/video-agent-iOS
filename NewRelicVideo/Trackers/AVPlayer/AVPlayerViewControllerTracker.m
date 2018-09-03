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
@property (nonatomic) BOOL isFullScreen;

@end

@implementation AVPlayerViewControllerTracker

- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController {
    if (self = [super initWithAVPlayer:playerViewController.player]) {
        self.playerViewController = playerViewController;
    }
    return self;
}

- (void)setup {
    [super setup];
    
    [self.playerViewController addObserver:self forKeyPath:@"videoBounds"
                                   options:NSKeyValueObservingOptionNew
                                   context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSString *,id> *)change
                       context:(void *)context {
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    
    if ([keyPath isEqualToString:@"videoBounds"]) {
        AV_LOG(@"VIDEO BOUNDS CHANGE = %@", NSStringFromCGRect(self.playerViewController.videoBounds));
        AV_LOG(@"SCREEN BOUNDS = %@", NSStringFromCGRect([UIScreen mainScreen].bounds));
        
        CGRect newBounds = [change[NSKeyValueChangeNewKey] CGRectValue];
        
        if ([UIScreen mainScreen].bounds.size.height == newBounds.size.height || [UIScreen mainScreen].bounds.size.width == newBounds.size.width) {
            AV_LOG(@"FULL SCREEN");
            self.isFullScreen = YES;
        }
        else {
            AV_LOG(@"NO FULL SCREEN");
            self.isFullScreen = NO;
        }
    }
}

- (NSNumber *)getIsFullscreen {
    return @(self.isFullScreen);
}

@end
