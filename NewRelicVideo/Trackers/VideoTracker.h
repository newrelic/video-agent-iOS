//
//  VideoTracker.h
//  NewRelicVideo
//
//  Created by Andreu Santaren on 29/08/2018.
//  Copyright © 2018 New Relic Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol VideoTrackerProtocol <NSObject>
@required
- (NSString *)getTrackerName;
- (NSString *)getTrackerVersion;
- (NSString *)getPlayerVersion;
- (NSString *)getPlayerName;
@optional
- (void)timeEvent;
- (NSNumber *)getBitrate;
- (NSNumber *)getRenditionWidth;
- (NSNumber *)getRenditionHeight;
- (NSNumber *)getDuration;
- (NSNumber *)getPlayhead;
- (NSString *)getSrc;
- (NSNumber *)getPlayrate;
- (NSNumber *)getFps;
- (NSNumber *)getIsLive;
- (NSNumber *)getIsAd;
@end

@interface VideoTracker : NSObject

- (void)reset;
- (void)setup;
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
- (void)startTimerEvent;
- (void)abortTimerEvent;

@end
