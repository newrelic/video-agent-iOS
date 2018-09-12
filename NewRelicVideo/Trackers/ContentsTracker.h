//
//  ContentsTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
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
