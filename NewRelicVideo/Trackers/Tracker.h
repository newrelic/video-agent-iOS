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

/**
 Reset the tracker's state.
 */
- (void)reset;

/**
 Inititialize the tracker's state.
 */
- (void)setup;

/**
 Pre-send method, called right before any `send` method is executed.
 */
- (void)preSend;

/**
 Send a `_REQUEST` action.
 */
- (void)sendRequest;

/**
 Send a `_START` action.
 */
- (void)sendStart;

/**
 Send a `_END` action.
 */
- (void)sendEnd;

/**
 Send a `_PAUSE` action.
 */
- (void)sendPause;

/**
 Send a `_RESUME` action.
 */
- (void)sendResume;

/**
 Send a `_SEEK_START` action.
 */
- (void)sendSeekStart;

/**
 Send a `_SEEK_END` action.
 */
- (void)sendSeekEnd;

/**
 Send a `_BUFFER_START` action.
 */
- (void)sendBufferStart;

/**
 Send a `_BUFFER_END` action.
 */
- (void)sendBufferEnd;

/**
 Send a `_HEARTBEAT` action.
 */
- (void)sendHeartbeat;

/**
 Send a `_RENDITION_CHANGE` action.
 */
- (void)sendRenditionChange;

/**
 Send a `_ERROR` action.
 */
- (void)sendError;

/**
 Send a `PLAYER_READY` action.
 */
- (void)sendPlayerReady;

/**
 Send a `DOWNLOAD` action.
 */
- (void)sendDownload;

/**
 Send a custom action.
 
 @param name Name of action.
 */
- (void)sendCustomAction:(NSString *)name;

/**
 Send a custom action.
 
 @param name Name of action.
 @param attr Dictionary of parameters sent along the action.
 */
- (void)sendCustomAction:(NSString *)name attr:(NSDictionary *)attr;

/**
 Set custom parameters for actions.
 
 @param opts Dictionary of parameters sent along the actions.
 */
- (void)setOptions:(NSDictionary *)opts;

/**
 Set custom single parameter for actions.
 
 @param key Name of parameter.
 @param value Value of parameter.
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value;

/**
 Set custom parameters for a specific action.
 
 @param opts Dictionary of parameters sent along the actions.
 @param action Name of action.
 */
- (void)setOptions:(NSDictionary *)opts forAction:(NSString *)action;

/**
 Set custom single parameter for a specific action.
 
 @param key Name of parameter.
 @param value Value of parameter.
 @param action Name of action
 */
- (void)setOptionKey:(NSString *)key value:(id<NSCopying>)value forAction:(NSString *)action;

/**
 Obtain the value a of a specific attribute name using a dictionary with getter.
 
 @param attr Attribute name.
 @param attributeGetters The Action mapper where attribute names and getters are stored.
 */
- (id<NSCopying>)optionValueFor:(NSString *)attr fromGetters:(NSMutableDictionary<NSString *, NSValue *> *)attributeGetters;

/**
 Start timer.
 */
- (void)startTimerEvent;

/**
 Abort timer.
 */
- (void)abortTimerEvent;

/**
 Timer handler.
 */
- (void)trackerTimeEvent;

@end
