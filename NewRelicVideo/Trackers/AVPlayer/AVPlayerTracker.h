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

/**
 Create a `AVPlayerTracker` instance using a `AVPlayer` instance.
 
 @param player The `AVPlayer` object.
 */
- (instancetype)initWithAVPlayer:(AVPlayer *)player;

/**
 Create a `AVPlayerTracker` instance using a `AVPlayerViewController` instance.
 
 @param playerViewController The `AVPlayerViewController` object.
 */
- (instancetype)initWithAVPlayerViewController:(AVPlayerViewController *)playerViewController;

/**
 Set the isAutoplayed state, since AVPlayer doesn't offer this property.
 
 @param state A boolean `NSNumber` to indicate whether it is autpolayed or not.
 */
- (void)setIsAutoplayed:(NSNumber *)state;

@end
