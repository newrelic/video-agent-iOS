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

@interface ContentsTracker : Tracker <TrackerProtocol>

@end
