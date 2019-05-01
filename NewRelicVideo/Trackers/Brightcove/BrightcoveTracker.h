//
//  BrightcoveTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContentsTracker.h"

@import BrightcovePlayerSDK;

/**
 `BrightcoveTracker` is the base class to manage the content events of a Brightcove player. It can be used directly or subclassed.
 */
@interface BrightcoveTracker : ContentsTracker <ContentsTrackerProtocol, BCOVPlaybackControllerDelegate>

/**
 Create a `BrightcoveTracker` instance using a `GCKSessionManager` instance.
 
 @param playbackController The `BCOVPlaybackController` object.
 */
- (instancetype)initWithBrightcove:(id)playbackController;

@end
