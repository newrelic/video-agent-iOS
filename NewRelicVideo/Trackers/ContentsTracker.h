//
//  ContentsTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

/**
 `ContentsTrackerProtocol` defines the getters every ContentsTracker must or should implement.
 */
@protocol ContentsTrackerProtocol <TrackerProtocol>

@optional

/**
 Get speed of video playback, normalized to 1 (normal speed).
 */
- (NSNumber *)getPlayrate;

/**
 Get whether video playback is live or not.
 */
- (NSNumber *)getIsLive;

/**
 Get whether video is autoplayed or not.
 */
- (NSNumber *)getIsAutoplayed;

/**
 Get the video preload policy.
 */
- (NSString *)getPreload;

/**
 Get whether video is in full screen or not.
 */
- (NSNumber *)getIsFullscreen;

@end

/**
 `ContentsTracker` is the base class to manage the content events of a player.
 
 @warning Should never be instantiated directly, but subclassed.
 */
@interface ContentsTracker : Tracker <TrackerProtocol>

@end
