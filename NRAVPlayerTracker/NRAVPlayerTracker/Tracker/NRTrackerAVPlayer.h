//
//  NRTrackerAVPlayer.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 05/08/2020.
//  Copyright © 2020 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <NewRelicVideoCore/NewRelicVideoCore.h>

@class AVPlayer;

/**
 `NRTrackerAVPlayer` is the base class to manage the content events of an AVPlayer. It can be used directly or subclassed.
 */
@interface NRTrackerAVPlayer : NRVideoTracker

/**
 Create a `NRTrackerAVPlayer` instance using a `AVPlayer` instance.
 
 @param player The `AVPlayer` object.
 */
- (instancetype)initWithAVPlayer:(AVPlayer *)player;

@end
