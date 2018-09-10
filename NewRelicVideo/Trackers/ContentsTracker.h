//
//  ContentsTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import "Tracker.h"

@class AdsTracker;

@protocol ContentsTrackerProtocol <TrackerProtocol>
@optional
- (NSString *)getVideoId;
- (NSString *)getTitle;
- (NSNumber *)getBitrate;
- (NSString *)getRenditionName;
- (NSNumber *)getRenditionBitrate;
- (NSNumber *)getRenditionWidth;
- (NSNumber *)getRenditionHeight;
- (NSNumber *)getDuration;
- (NSNumber *)getPlayhead;
- (NSString *)getLanguage;
- (NSString *)getSrc;
- (NSNumber *)getPlayrate;
- (NSNumber *)getFps;
- (NSNumber *)getIsLive;
- (NSNumber *)getIsMutted;
- (NSString *)getCdn;
- (NSNumber *)getIsAutoplayed;
- (NSString *)getPreload;
- (void)setIsAutoplayed:(NSNumber *)state;
- (NSNumber *)getIsFullscreen;
@end

@interface ContentsTracker : Tracker <TrackerProtocol>

@property (nonatomic) AdsTracker *adsTracker;

@end
