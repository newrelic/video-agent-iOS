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
- (NSString *)getVideoId;
- (NSNumber *)getBitrate;
- (NSNumber *)getRenditionWidth;
- (NSNumber *)getRenditionHeight;
- (NSNumber *)getDuration;
- (NSNumber *)getPlayhead;
- (NSString *)getSrc;
- (NSNumber *)getPlayrate;
- (NSNumber *)getFps;
- (NSNumber *)getIsLive;
- (NSNumber *)getIsMutted;
- (NSNumber *)getIsAutoplayed;
- (void)setIsAutoplayed:(NSNumber *)state;
- (NSNumber *)getIsFullscreen;
@end

@interface ContentsTracker : Tracker <TrackerProtocol>

@end
