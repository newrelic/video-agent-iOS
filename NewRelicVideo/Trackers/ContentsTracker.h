//
//  ContentsTracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

@protocol ContentsTrackerProtocol <TrackerProtocol>
@optional
- (NSNumber *)getPlayrate;
- (NSNumber *)getIsLive;
- (NSNumber *)getIsAutoplayed;
- (NSString *)getPreload;
- (NSNumber *)getIsFullscreen;
@end

/**
 `ContentsTracker` is the base class to manage the content events of a player.
 
 @warning Should never be instantiated directly, but subclassed.
 */

@interface ContentsTracker : Tracker <TrackerProtocol>

@end
