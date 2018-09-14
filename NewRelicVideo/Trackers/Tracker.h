//
//  Tracker.h
//  New Relic Video Agent for Mobile -- iOS edition
//
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
- (NSNumber *)getIsMuted;
- (NSString *)getCdn;
- (NSNumber *)getFps;
@end

/**
 `Tracker` is the base class to manage the player events and mechanisms common to Contents and Ads.
 
 @warning Should never be instantiated directly, but subclassed.
 */

@interface Tracker : NSObject

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
- (void)sendPlayerReady;
- (void)sendDownload;
- (void)sendCustomAction:(NSString *)name;
- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr;
- (void)setOptions:(NSDictionary *)opts;
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value;
- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action;
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action;
- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSMutableDictionary<NSString *, NSValue *> *)attributeGetters;
- (void)startTimerEvent;
- (void)abortTimerEvent;
- (void)trackerTimeEvent;

@end
