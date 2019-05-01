//
//  NRTrackerBuilder.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2019 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 `NRTrackerBuilder` protocol defines the methos that any tracker builder needs.
 */
@protocol NRTrackerBuilder <NSObject>

@required

/**
 Starts a video tracker for the specified player.
 
 @param player The player object.
 @return whether the tracker was correctly initialised or not.
 */
+ (BOOL)startWithPlayer:(id)player;

@end
