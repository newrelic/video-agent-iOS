//
//  Tracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 06/09/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TrackerProtocol <NSObject>
@required
- (NSString *)getTrackerName;
- (NSString *)getTrackerVersion;
- (NSString *)getPlayerVersion;
- (NSString *)getPlayerName;
- (NSNumber *)getIsAd;
@optional
- (void)timeEvent;
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

// TODO: Adv specific getters (attributes)

@end

@interface Tracker : NSObject

- (NSTimeInterval)timestamp;
- (void)reset;
- (void)setup;
- (void)preSend;
- (void)sendRequest;
- (void)sendStart;
- (void)sendEnd;
- (void)sendPause;
- (void)sendResume;
- (void)sendSeekStart;
- (void)sendSeekEnd;
- (void)sendBufferStart;
- (void)sendBufferEnd;
- (void)sendHeartbeat;
- (void)sendRenditionChange;
- (void)sendError;
- (void)setOptions:(NSDictionary *)opts;
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value;
- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action;
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action;

@end
